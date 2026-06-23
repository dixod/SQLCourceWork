BEGIN;

CREATE TEMP TABLE stg_etl_params ON COMMIT DROP AS
SELECT
    DATE '2026-01-01' AS snapshot_date,
    20260101 AS date_key;

CREATE TEMP TABLE stg_olap_city_metrics ON COMMIT DROP AS
WITH base_metrics AS (
    SELECT
        ci.city_name,
        co.country_name,
        ci.data_quality_code,
        COALESCE(MAX(ccv.cost_value) FILTER (WHERE it.item_code = 'x54'), 0) AS avg_salary,
        COALESCE(
            MAX(ccv.cost_value) FILTER (WHERE it.item_code = 'x49'),
            MAX(ccv.cost_value) FILTER (WHERE it.item_code = 'x48'),
            0
        ) AS rent_proxy,
        COALESCE(SUM(ccv.cost_value) FILTER (WHERE cc.category_name = 'Restaurants'), 0) AS restaurants_cost_total,
        COALESCE(SUM(ccv.cost_value) FILTER (WHERE cc.category_name = 'Groceries'), 0) AS groceries_cost_total,
        COALESCE(SUM(ccv.cost_value) FILTER (
            WHERE cc.category_name = 'Transportation'
              AND it.item_code NOT IN ('x34', 'x35')
        ), 0) AS transport_cost_total,
        COALESCE(SUM(ccv.cost_value) FILTER (
            WHERE cc.category_name = 'Housing'
              AND it.item_code IN ('x48', 'x49', 'x50', 'x51')
        ), 0) AS housing_cost_total
    FROM oltp.cities ci
    JOIN oltp.countries co ON co.country_id = ci.country_id
    LEFT JOIN oltp.city_cost_values ccv ON ccv.city_id = ci.city_id
    LEFT JOIN oltp.cost_items it ON it.item_id = ccv.item_id
    LEFT JOIN oltp.cost_categories cc ON cc.category_id = it.category_id
    GROUP BY ci.city_name, co.country_name, ci.data_quality_code
),
calculated_metrics AS (
    SELECT
        city_name,
        country_name,
        data_quality_code,
        avg_salary::NUMERIC(16, 4) AS avg_salary,
        rent_proxy::NUMERIC(16, 4) AS rent_proxy,
        restaurants_cost_total::NUMERIC(16, 4) AS restaurants_cost_total,
        groceries_cost_total::NUMERIC(16, 4) AS groceries_cost_total,
        transport_cost_total::NUMERIC(16, 4) AS transport_cost_total,
        housing_cost_total::NUMERIC(16, 4) AS housing_cost_total,
        (
            rent_proxy
            + groceries_cost_total * 4
            + transport_cost_total
            + restaurants_cost_total * 4
        )::NUMERIC(16, 4) AS monthly_cost_proxy
    FROM base_metrics
)
SELECT
    city_name,
    country_name,
    data_quality_code,
    avg_salary,
    rent_proxy,
    restaurants_cost_total,
    groceries_cost_total,
    transport_cost_total,
    housing_cost_total,
    monthly_cost_proxy,
    COALESCE(ROUND(avg_salary / NULLIF(monthly_cost_proxy, 0), 4), 0)::NUMERIC(10, 4) AS affordability_score,
    CASE
        WHEN monthly_cost_proxy = 0 THEN 'unknown'
        WHEN avg_salary / NULLIF(monthly_cost_proxy, 0) >= 2.5 THEN 'high_affordability'
        WHEN avg_salary / NULLIF(monthly_cost_proxy, 0) >= 1.5 THEN 'medium_affordability'
        ELSE 'low_affordability'
    END AS affordability_tier,
    CASE
        WHEN avg_salary = 0 THEN 'unknown'
        WHEN avg_salary >= 3000 THEN 'high_salary'
        WHEN avg_salary >= 1500 THEN 'medium_salary'
        ELSE 'low_salary'
    END AS salary_tier,
    CASE
        WHEN rent_proxy = 0 THEN 'unknown'
        WHEN rent_proxy >= 1500 THEN 'high_rent'
        WHEN rent_proxy >= 700 THEN 'medium_rent'
        ELSE 'low_rent'
    END AS rent_tier
FROM calculated_metrics;

INSERT INTO olap.dim_date (
    date_key,
    full_date,
    year_number,
    quarter_number,
    month_number
)
SELECT
    date_key,
    snapshot_date,
    EXTRACT(YEAR FROM snapshot_date)::INTEGER,
    EXTRACT(QUARTER FROM snapshot_date)::INTEGER,
    EXTRACT(MONTH FROM snapshot_date)::INTEGER
FROM stg_etl_params
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO olap.dim_country (country_name)
SELECT DISTINCT country_name
FROM oltp.countries
WHERE country_name IS NOT NULL
  AND country_name <> ''
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO olap.dim_data_quality (
    data_quality_code,
    quality_name
)
SELECT DISTINCT
    data_quality_code,
    quality_name
FROM oltp.data_quality_levels
ON CONFLICT (data_quality_code) DO NOTHING;

INSERT INTO olap.dim_cost_category (category_name)
SELECT DISTINCT category_name
FROM oltp.cost_categories
WHERE category_name IS NOT NULL
  AND category_name <> ''
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO olap.dim_cost_item (
    item_code,
    item_name,
    unit,
    category_key
)
SELECT DISTINCT
    oi.item_code,
    oi.item_name,
    oi.unit,
    dcc.category_key
FROM oltp.cost_items oi
JOIN oltp.cost_categories oc ON oc.category_id = oi.category_id
JOIN olap.dim_cost_category dcc ON dcc.category_name = oc.category_name
ON CONFLICT (item_code) DO NOTHING;

UPDATE olap.dim_city_scd d
SET
    valid_to = p.snapshot_date - 1,
    is_current = FALSE
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_data_quality ddq ON ddq.data_quality_code = s.data_quality_code
CROSS JOIN stg_etl_params p
WHERE d.city_name = s.city_name
  AND d.country_key = dc.country_key
  AND d.is_current = TRUE
  AND d.valid_from < p.snapshot_date
  AND (
      d.data_quality_key <> ddq.data_quality_key
      OR d.affordability_tier <> s.affordability_tier
      OR d.salary_tier <> s.salary_tier
      OR d.rent_tier <> s.rent_tier
  );

INSERT INTO olap.dim_city_scd (
    city_name,
    country_key,
    data_quality_key,
    affordability_tier,
    salary_tier,
    rent_tier,
    valid_from,
    valid_to,
    is_current
)
SELECT
    s.city_name,
    dc.country_key,
    ddq.data_quality_key,
    s.affordability_tier,
    s.salary_tier,
    s.rent_tier,
    p.snapshot_date,
    NULL,
    TRUE
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_data_quality ddq ON ddq.data_quality_code = s.data_quality_code
CROSS JOIN stg_etl_params p
WHERE NOT EXISTS (
    SELECT 1
    FROM olap.dim_city_scd existing
    WHERE existing.city_name = s.city_name
      AND existing.country_key = dc.country_key
      AND existing.is_current = TRUE
)
ON CONFLICT (city_name, country_key, valid_from) DO NOTHING;

INSERT INTO olap.dim_lifestyle_tag (
    tag_name,
    tag_description
)
VALUES
    ('budget_friendly', 'City has a good salary to cost ratio.'),
    ('high_salary', 'City has high average salary.'),
    ('expensive_housing', 'City has expensive housing.'),
    ('family_oriented', 'City has good data quality and acceptable affordability.'),
    ('premium_city', 'City has high salary and expensive housing.')
ON CONFLICT (tag_name) DO NOTHING;

INSERT INTO olap.bridge_city_lifestyle_tag (
    city_key,
    lifestyle_tag_key
)
SELECT dcs.city_key, dlt.lifestyle_tag_key
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_city_scd dcs ON dcs.city_name = s.city_name AND dcs.country_key = dc.country_key AND dcs.is_current = TRUE
JOIN olap.dim_lifestyle_tag dlt ON dlt.tag_name = 'budget_friendly'
WHERE s.affordability_score >= 1.5
ON CONFLICT (city_key, lifestyle_tag_key) DO NOTHING;

INSERT INTO olap.bridge_city_lifestyle_tag (
    city_key,
    lifestyle_tag_key
)
SELECT dcs.city_key, dlt.lifestyle_tag_key
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_city_scd dcs ON dcs.city_name = s.city_name AND dcs.country_key = dc.country_key AND dcs.is_current = TRUE
JOIN olap.dim_lifestyle_tag dlt ON dlt.tag_name = 'high_salary'
WHERE s.avg_salary >= 3000
ON CONFLICT (city_key, lifestyle_tag_key) DO NOTHING;

INSERT INTO olap.bridge_city_lifestyle_tag (
    city_key,
    lifestyle_tag_key
)
SELECT dcs.city_key, dlt.lifestyle_tag_key
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_city_scd dcs ON dcs.city_name = s.city_name AND dcs.country_key = dc.country_key AND dcs.is_current = TRUE
JOIN olap.dim_lifestyle_tag dlt ON dlt.tag_name = 'expensive_housing'
WHERE s.rent_proxy >= 1500
ON CONFLICT (city_key, lifestyle_tag_key) DO NOTHING;

INSERT INTO olap.bridge_city_lifestyle_tag (
    city_key,
    lifestyle_tag_key
)
SELECT dcs.city_key, dlt.lifestyle_tag_key
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_city_scd dcs ON dcs.city_name = s.city_name AND dcs.country_key = dc.country_key AND dcs.is_current = TRUE
JOIN olap.dim_lifestyle_tag dlt ON dlt.tag_name = 'family_oriented'
WHERE s.data_quality_code = 1
  AND s.affordability_score >= 1.2
ON CONFLICT (city_key, lifestyle_tag_key) DO NOTHING;

INSERT INTO olap.bridge_city_lifestyle_tag (
    city_key,
    lifestyle_tag_key
)
SELECT dcs.city_key, dlt.lifestyle_tag_key
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_city_scd dcs ON dcs.city_name = s.city_name AND dcs.country_key = dc.country_key AND dcs.is_current = TRUE
JOIN olap.dim_lifestyle_tag dlt ON dlt.tag_name = 'premium_city'
WHERE s.avg_salary >= 3000
  AND s.rent_proxy >= 1500
ON CONFLICT (city_key, lifestyle_tag_key) DO NOTHING;

INSERT INTO olap.fact_city_cost (
    date_key,
    city_key,
    item_key,
    cost_value
)
SELECT
    p.date_key,
    dcs.city_key,
    dci.item_key,
    ccv.cost_value
FROM oltp.city_cost_values ccv
JOIN oltp.cities ci ON ci.city_id = ccv.city_id
JOIN oltp.countries co ON co.country_id = ci.country_id
JOIN oltp.cost_items oi ON oi.item_id = ccv.item_id
JOIN olap.dim_country dc ON dc.country_name = co.country_name
JOIN olap.dim_city_scd dcs ON dcs.city_name = ci.city_name AND dcs.country_key = dc.country_key AND dcs.is_current = TRUE
JOIN olap.dim_cost_item dci ON dci.item_code = oi.item_code
CROSS JOIN stg_etl_params p
WHERE ccv.cost_value IS NOT NULL
  AND ccv.cost_value >= 0
ON CONFLICT (date_key, city_key, item_key) DO NOTHING;

INSERT INTO olap.fact_affordability_snapshot (
    date_key,
    city_key,
    avg_salary,
    monthly_cost_proxy,
    affordability_score,
    restaurants_cost_total,
    groceries_cost_total,
    transport_cost_total,
    housing_cost_total
)
SELECT
    p.date_key,
    dcs.city_key,
    s.avg_salary,
    s.monthly_cost_proxy,
    s.affordability_score,
    s.restaurants_cost_total,
    s.groceries_cost_total,
    s.transport_cost_total,
    s.housing_cost_total
FROM stg_olap_city_metrics s
JOIN olap.dim_country dc ON dc.country_name = s.country_name
JOIN olap.dim_city_scd dcs ON dcs.city_name = s.city_name AND dcs.country_key = dc.country_key AND dcs.is_current = TRUE
CROSS JOIN stg_etl_params p
ON CONFLICT (date_key, city_key) DO NOTHING;

COMMIT;
