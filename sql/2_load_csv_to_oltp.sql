BEGIN;

CREATE TEMP TABLE stg_countries (
    country_name TEXT
) ON COMMIT DROP;

CREATE TEMP TABLE stg_cities (
    city_name TEXT,
    country_name TEXT,
    data_quality_code SMALLINT
) ON COMMIT DROP;

CREATE TEMP TABLE stg_cost_items (
    item_code TEXT,
    item_name TEXT,
    unit TEXT,
    category_name TEXT
) ON COMMIT DROP;

CREATE TEMP TABLE stg_city_cost_values (
    city_name TEXT,
    country_name TEXT,
    item_code TEXT,
    cost_value NUMERIC(16, 4)
) ON COMMIT DROP;

CREATE TEMP TABLE stg_user_favorite_cities (
    user_email TEXT,
    user_name TEXT,
    city_name TEXT,
    country_name TEXT,
    created_at TIMESTAMP
) ON COMMIT DROP;

\copy stg_countries(country_name) FROM 'data/countries.csv' WITH (FORMAT csv, HEADER true)
\copy stg_cities(city_name, country_name, data_quality_code) FROM 'data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy stg_cost_items(item_code, item_name, unit, category_name) FROM 'data/cost_items.csv' WITH (FORMAT csv, HEADER true)
\copy stg_city_cost_values(city_name, country_name, item_code, cost_value) FROM 'data/city_cost_values.csv' WITH (FORMAT csv, HEADER true)
\copy stg_user_favorite_cities(user_email, user_name, city_name, country_name, created_at) FROM 'data/user_favorite_cities.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO oltp.data_quality_levels (
    data_quality_code,
    quality_name,
    description
)
VALUES
    (0, 'Low quality', 'The city has lower data quality in the source dataset.'),
    (1, 'High quality', 'The city has higher data quality in the source dataset.')
ON CONFLICT (data_quality_code) DO NOTHING;

INSERT INTO oltp.countries (
    country_name
)
SELECT DISTINCT
    country_name
FROM stg_countries
WHERE country_name IS NOT NULL
  AND country_name <> ''
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO oltp.cost_categories (
    category_name
)
SELECT DISTINCT
    category_name
FROM stg_cost_items
WHERE category_name IS NOT NULL
  AND category_name <> ''
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO oltp.cities (
    city_name,
    country_id,
    data_quality_code
)
SELECT DISTINCT
    sc.city_name,
    c.country_id,
    sc.data_quality_code
FROM stg_cities sc
JOIN oltp.countries c
    ON c.country_name = sc.country_name
JOIN oltp.data_quality_levels dql
    ON dql.data_quality_code = sc.data_quality_code
WHERE sc.city_name IS NOT NULL
  AND sc.city_name <> ''
  AND sc.country_name IS NOT NULL
  AND sc.country_name <> ''
ON CONFLICT (city_name, country_id) DO NOTHING;

INSERT INTO oltp.cost_items (
    item_code,
    item_name,
    unit,
    category_id
)
SELECT DISTINCT
    sci.item_code,
    sci.item_name,
    sci.unit,
    cc.category_id
FROM stg_cost_items sci
JOIN oltp.cost_categories cc
    ON cc.category_name = sci.category_name
WHERE sci.item_code IS NOT NULL
  AND sci.item_code <> ''
  AND sci.item_name IS NOT NULL
  AND sci.item_name <> ''
  AND sci.unit IS NOT NULL
  AND sci.unit <> ''
ON CONFLICT (item_code) DO NOTHING;

INSERT INTO oltp.city_cost_values (
    city_id,
    item_id,
    cost_value
)
SELECT DISTINCT
    ci.city_id,
    it.item_id,
    scv.cost_value
FROM stg_city_cost_values scv
JOIN oltp.countries co
    ON co.country_name = scv.country_name
JOIN oltp.cities ci
    ON ci.city_name = scv.city_name
   AND ci.country_id = co.country_id
JOIN oltp.cost_items it
    ON it.item_code = scv.item_code
WHERE scv.cost_value IS NOT NULL
  AND scv.cost_value >= 0
ON CONFLICT (city_id, item_id) DO NOTHING;

INSERT INTO oltp.app_users (
    user_email,
    user_name,
    created_at
)
SELECT
    user_email,
    MIN(user_name) AS user_name,
    MIN(created_at) AS created_at
FROM stg_user_favorite_cities
WHERE user_email IS NOT NULL
  AND user_email <> ''
  AND user_name IS NOT NULL
  AND user_name <> ''
GROUP BY user_email
ON CONFLICT (user_email) DO NOTHING;

INSERT INTO oltp.user_favorite_cities (
    user_id,
    city_id,
    created_at
)
SELECT DISTINCT
    u.user_id,
    ci.city_id,
    s.created_at
FROM stg_user_favorite_cities s
JOIN oltp.app_users u
    ON u.user_email = s.user_email
JOIN oltp.countries co
    ON co.country_name = s.country_name
JOIN oltp.cities ci
    ON ci.city_name = s.city_name
   AND ci.country_id = co.country_id
WHERE s.created_at IS NOT NULL
ON CONFLICT (user_id, city_id) DO NOTHING;

COMMIT;
