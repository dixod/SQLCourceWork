\set ON_ERROR_STOP on

\if :{?snapshot_date}
\else
SELECT CURRENT_DATE AS snapshot_date \gset
\endif

BEGIN;

CREATE TEMP TABLE stg_params ON COMMIT DROP AS
SELECT :'snapshot_date'::DATE AS snapshot_date,
       to_char(:'snapshot_date'::DATE, 'YYYYMMDD')::INTEGER AS date_key;

DO $$
BEGIN
    IF (SELECT snapshot_date FROM stg_params) < (SELECT MAX(full_date) FROM olap.dim_date) THEN
        RAISE EXCEPTION 'Use the latest snapshot date or a later date';
    END IF;
END;
$$;

INSERT INTO olap.dim_date (date_key, full_date, year_number, quarter_number, month_number)
SELECT date_key, snapshot_date,
       EXTRACT(YEAR FROM snapshot_date),
       EXTRACT(QUARTER FROM snapshot_date),
       EXTRACT(MONTH FROM snapshot_date)
FROM stg_params
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO olap.dim_country (country_name)
SELECT country_name FROM source_oltp.countries ORDER BY country_name
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO olap.dim_data_quality (data_quality_code, quality_name)
SELECT data_quality_code, quality_name FROM source_oltp.data_quality_levels
ON CONFLICT (data_quality_code) DO UPDATE
SET quality_name = EXCLUDED.quality_name
WHERE olap.dim_data_quality.quality_name IS DISTINCT FROM EXCLUDED.quality_name;

INSERT INTO olap.dim_cost_category (category_name)
SELECT category_name FROM source_oltp.cost_categories ORDER BY category_name
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO olap.dim_cost_item (item_code, item_name, unit, category_key)
SELECT i.item_code, i.item_name, i.unit, d.category_key
FROM source_oltp.cost_items i
JOIN source_oltp.cost_categories c ON c.category_id = i.category_id
JOIN olap.dim_cost_category d ON d.category_name = c.category_name
ORDER BY i.item_code
ON CONFLICT (item_code) DO UPDATE
SET item_name = EXCLUDED.item_name, unit = EXCLUDED.unit, category_key = EXCLUDED.category_key
WHERE (olap.dim_cost_item.item_name, olap.dim_cost_item.unit, olap.dim_cost_item.category_key)
    IS DISTINCT FROM (EXCLUDED.item_name, EXCLUDED.unit, EXCLUDED.category_key);

CREATE TEMP TABLE stg_source_values ON COMMIT DROP AS
SELECT v.city_id, i.item_code, i.unit, v.cost_value
FROM source_oltp.city_cost_values v
JOIN source_oltp.cost_items i ON i.item_id = v.item_id;

CREATE TEMP TABLE stg_metrics ON COMMIT DROP AS
WITH prices AS (
    SELECT c.city_id, c.city_name, country.country_key, quality.data_quality_key,
           c.data_quality_code,
           MAX(v.cost_value) FILTER (WHERE v.item_code = 'x54') AS avg_salary,
           COALESCE(
               MAX(v.cost_value) FILTER (WHERE v.item_code = 'x49'),
               MAX(v.cost_value) FILTER (WHERE v.item_code = 'x48')
           ) AS rent_cost,
           CASE WHEN COUNT(v.cost_value) FILTER (
               WHERE v.item_code IN ('x9', 'x10', 'x11', 'x12', 'x13', 'x14', 'x16', 'x20')
           ) = 8 THEN SUM(
               v.cost_value * CASE v.item_code
                   WHEN 'x9' THEN 8 WHEN 'x10' THEN 8
                   WHEN 'x11' THEN 2 WHEN 'x12' THEN 2
                   WHEN 'x13' THEN 1 WHEN 'x14' THEN 4
                   WHEN 'x16' THEN 4 WHEN 'x20' THEN 4
               END
           ) END AS food_cost,
           MAX(v.cost_value) FILTER (WHERE v.item_code = 'x29') AS transport_cost,
           MAX(v.cost_value) FILTER (WHERE v.item_code = 'x36') AS utilities_cost,
           MAX(v.cost_value) FILTER (WHERE v.item_code = 'x38') AS internet_cost
    FROM source_oltp.cities c
    JOIN source_oltp.countries co ON co.country_id = c.country_id
    JOIN olap.dim_country country ON country.country_name = co.country_name
    JOIN olap.dim_data_quality quality ON quality.data_quality_code = c.data_quality_code
    LEFT JOIN stg_source_values v ON v.city_id = c.city_id AND v.unit = 'USD'
    GROUP BY c.city_id, c.city_name, country.country_key,
             quality.data_quality_key, c.data_quality_code
), budgets AS (
    SELECT *,
           rent_cost + food_cost + transport_cost + utilities_cost + internet_cost
               AS monthly_cost_proxy
    FROM prices
), scores AS (
    SELECT *, ROUND(avg_salary / NULLIF(monthly_cost_proxy, 0), 4) AS affordability_score
    FROM budgets
)
SELECT *,
       CASE WHEN affordability_score IS NULL THEN 'unknown'
            WHEN affordability_score >= 2.5 THEN 'high_affordability'
            WHEN affordability_score >= 1.5 THEN 'medium_affordability'
            ELSE 'low_affordability' END AS affordability_tier,
       CASE WHEN avg_salary IS NULL THEN 'unknown'
            WHEN avg_salary >= 3000 THEN 'high_salary'
            WHEN avg_salary >= 1500 THEN 'medium_salary'
            ELSE 'low_salary' END AS salary_tier,
       CASE WHEN rent_cost IS NULL THEN 'unknown'
            WHEN rent_cost >= 1500 THEN 'high_rent'
            WHEN rent_cost >= 700 THEN 'medium_rent'
            ELSE 'low_rent' END AS rent_tier
FROM scores;

UPDATE olap.dim_city_scd d
SET valid_to = p.snapshot_date - 1, is_current = FALSE
FROM stg_metrics s CROSS JOIN stg_params p
WHERE d.city_id = s.city_id AND d.is_current AND d.valid_from < p.snapshot_date
  AND (d.city_name, d.country_key, d.data_quality_key,
       d.affordability_tier, d.salary_tier, d.rent_tier)
      IS DISTINCT FROM
      (s.city_name, s.country_key, s.data_quality_key,
       s.affordability_tier, s.salary_tier, s.rent_tier);

UPDATE olap.dim_city_scd d
SET city_name = s.city_name, country_key = s.country_key,
    data_quality_key = s.data_quality_key, affordability_tier = s.affordability_tier,
    salary_tier = s.salary_tier, rent_tier = s.rent_tier
FROM stg_metrics s CROSS JOIN stg_params p
WHERE d.city_id = s.city_id AND d.is_current AND d.valid_from = p.snapshot_date
  AND (d.city_name, d.country_key, d.data_quality_key,
       d.affordability_tier, d.salary_tier, d.rent_tier)
      IS DISTINCT FROM
      (s.city_name, s.country_key, s.data_quality_key,
       s.affordability_tier, s.salary_tier, s.rent_tier);

INSERT INTO olap.dim_city_scd (
    city_id, city_name, country_key, data_quality_key,
    affordability_tier, salary_tier, rent_tier, valid_from
)
SELECT s.city_id, s.city_name, s.country_key, s.data_quality_key,
       s.affordability_tier, s.salary_tier, s.rent_tier, p.snapshot_date
FROM stg_metrics s CROSS JOIN stg_params p
WHERE NOT EXISTS (
    SELECT 1 FROM olap.dim_city_scd d WHERE d.city_id = s.city_id AND d.is_current
)
ORDER BY s.city_id;

UPDATE olap.dim_city_scd d
SET valid_to = GREATEST(d.valid_from, p.snapshot_date - 1), is_current = FALSE
FROM stg_params p
WHERE d.is_current
  AND NOT EXISTS (SELECT 1 FROM stg_metrics s WHERE s.city_id = d.city_id);

CREATE TEMP TABLE stg_cost_facts ON COMMIT DROP AS
SELECT p.date_key, c.city_key, i.item_key, v.cost_value
FROM stg_source_values v
JOIN olap.dim_city_scd c ON c.city_id = v.city_id AND c.is_current
JOIN olap.dim_cost_item i ON i.item_code = v.item_code
CROSS JOIN stg_params p;

INSERT INTO olap.fact_city_cost (date_key, city_key, item_key, cost_value)
SELECT date_key, city_key, item_key, cost_value FROM stg_cost_facts
ON CONFLICT (date_key, city_key, item_key) DO UPDATE
SET cost_value = EXCLUDED.cost_value
WHERE olap.fact_city_cost.cost_value IS DISTINCT FROM EXCLUDED.cost_value;

DELETE FROM olap.fact_city_cost f
USING stg_params p
WHERE f.date_key = p.date_key
  AND NOT EXISTS (
      SELECT 1 FROM stg_cost_facts s WHERE s.city_key = f.city_key AND s.item_key = f.item_key
  );

CREATE TEMP TABLE stg_snapshots ON COMMIT DROP AS
SELECT p.date_key, c.city_key, s.avg_salary, s.rent_cost, s.food_cost,
       s.transport_cost, s.utilities_cost, s.internet_cost,
       s.monthly_cost_proxy, s.affordability_score
FROM stg_metrics s
JOIN olap.dim_city_scd c ON c.city_id = s.city_id AND c.is_current
CROSS JOIN stg_params p;

INSERT INTO olap.fact_affordability_snapshot AS target (
    date_key, city_key, avg_salary, rent_cost, food_cost,
    transport_cost, utilities_cost, internet_cost, monthly_cost_proxy, affordability_score
)
SELECT date_key, city_key, avg_salary, rent_cost, food_cost,
       transport_cost, utilities_cost, internet_cost, monthly_cost_proxy, affordability_score
FROM stg_snapshots
ON CONFLICT (date_key, city_key) DO UPDATE
SET avg_salary = EXCLUDED.avg_salary, rent_cost = EXCLUDED.rent_cost,
    food_cost = EXCLUDED.food_cost, transport_cost = EXCLUDED.transport_cost,
    utilities_cost = EXCLUDED.utilities_cost, internet_cost = EXCLUDED.internet_cost,
    monthly_cost_proxy = EXCLUDED.monthly_cost_proxy,
    affordability_score = EXCLUDED.affordability_score
WHERE (target.avg_salary, target.rent_cost, target.food_cost, target.transport_cost,
       target.utilities_cost, target.internet_cost, target.monthly_cost_proxy,
       target.affordability_score)
      IS DISTINCT FROM
      (EXCLUDED.avg_salary, EXCLUDED.rent_cost, EXCLUDED.food_cost, EXCLUDED.transport_cost,
       EXCLUDED.utilities_cost, EXCLUDED.internet_cost, EXCLUDED.monthly_cost_proxy,
       EXCLUDED.affordability_score);

DELETE FROM olap.fact_affordability_snapshot f
USING stg_params p
WHERE f.date_key = p.date_key
  AND NOT EXISTS (SELECT 1 FROM stg_snapshots s WHERE s.city_key = f.city_key);

INSERT INTO olap.dim_lifestyle_tag (tag_name, tag_description)
VALUES ('budget_friendly', 'Salary covers at least 1.5 monthly baskets'),
       ('high_salary', 'Average monthly salary is at least 3000 USD'),
       ('expensive_housing', 'Monthly rent is at least 1500 USD'),
       ('reliable_data', 'The source marks city data as high quality'),
       ('premium_city', 'Salary is at least 3000 USD and rent is at least 1500 USD')
ON CONFLICT (tag_name) DO UPDATE
SET tag_description = EXCLUDED.tag_description
WHERE olap.dim_lifestyle_tag.tag_description IS DISTINCT FROM EXCLUDED.tag_description;

CREATE TEMP TABLE stg_tags ON COMMIT DROP AS
SELECT p.date_key, c.city_key, t.lifestyle_tag_key
FROM stg_metrics s
JOIN olap.dim_city_scd c ON c.city_id = s.city_id AND c.is_current
CROSS JOIN olap.dim_lifestyle_tag t
CROSS JOIN stg_params p
WHERE (t.tag_name = 'budget_friendly' AND s.affordability_score >= 1.5)
   OR (t.tag_name = 'high_salary' AND s.avg_salary >= 3000)
   OR (t.tag_name = 'expensive_housing' AND s.rent_cost >= 1500)
   OR (t.tag_name = 'reliable_data' AND s.data_quality_code = 1)
   OR (t.tag_name = 'premium_city' AND s.avg_salary >= 3000 AND s.rent_cost >= 1500);

INSERT INTO olap.bridge_city_lifestyle_tag (date_key, city_key, lifestyle_tag_key)
SELECT date_key, city_key, lifestyle_tag_key FROM stg_tags
ON CONFLICT (date_key, city_key, lifestyle_tag_key) DO NOTHING;

DELETE FROM olap.bridge_city_lifestyle_tag b
USING stg_params p
WHERE b.date_key = p.date_key
  AND NOT EXISTS (
      SELECT 1 FROM stg_tags s
      WHERE s.city_key = b.city_key AND s.lifestyle_tag_key = b.lifestyle_tag_key
  );

COMMIT;
