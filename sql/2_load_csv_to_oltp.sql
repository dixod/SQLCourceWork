\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE stg_countries (
    country_name TEXT PRIMARY KEY CHECK (btrim(country_name) <> '')
) ON COMMIT DROP;

CREATE TEMP TABLE stg_cities (
    city_name TEXT NOT NULL CHECK (btrim(city_name) <> ''),
    country_name TEXT NOT NULL REFERENCES stg_countries(country_name),
    data_quality_code SMALLINT NOT NULL CHECK (data_quality_code IN (0, 1)),
    PRIMARY KEY (city_name, country_name)
) ON COMMIT DROP;

CREATE TEMP TABLE stg_cost_items (
    item_code TEXT PRIMARY KEY CHECK (btrim(item_code) <> ''),
    item_name TEXT NOT NULL CHECK (btrim(item_name) <> ''),
    unit TEXT NOT NULL CHECK (unit IN ('USD', '%')),
    category_name TEXT NOT NULL CHECK (btrim(category_name) <> '')
) ON COMMIT DROP;

CREATE TEMP TABLE stg_city_cost_values (
    city_name TEXT NOT NULL,
    country_name TEXT NOT NULL,
    item_code TEXT NOT NULL REFERENCES stg_cost_items(item_code),
    cost_value NUMERIC(16, 4) NOT NULL CHECK (cost_value >= 0 AND cost_value <> 'NaN'),
    PRIMARY KEY (city_name, country_name, item_code),
    FOREIGN KEY (city_name, country_name) REFERENCES stg_cities(city_name, country_name)
) ON COMMIT DROP;

CREATE TEMP TABLE stg_user_favorite_cities (
    user_email TEXT NOT NULL CHECK (btrim(user_email) <> ''),
    user_name TEXT NOT NULL CHECK (btrim(user_name) <> ''),
    city_name TEXT NOT NULL,
    country_name TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    PRIMARY KEY (user_email, city_name, country_name),
    FOREIGN KEY (city_name, country_name) REFERENCES stg_cities(city_name, country_name)
) ON COMMIT DROP;

\copy stg_countries FROM 'data/countries.csv' WITH (FORMAT csv, HEADER true)
\copy stg_cities FROM 'data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy stg_cost_items FROM 'data/cost_items.csv' WITH (FORMAT csv, HEADER true)
\copy stg_city_cost_values FROM 'data/city_cost_values.csv' WITH (FORMAT csv, HEADER true)
\copy stg_user_favorite_cities FROM 'data/user_favorite_cities.csv' WITH (FORMAT csv, HEADER true)

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM stg_countries)
       OR NOT EXISTS (SELECT 1 FROM stg_cities)
       OR NOT EXISTS (SELECT 1 FROM stg_cost_items) THEN
        RAISE EXCEPTION 'Countries, cities and cost items must not be empty';
    END IF;
    IF EXISTS (
        SELECT user_email FROM stg_user_favorite_cities
        GROUP BY user_email HAVING COUNT(DISTINCT user_name) > 1
    ) THEN
        RAISE EXCEPTION 'One user email has different user names';
    END IF;
END;
$$;

INSERT INTO oltp.data_quality_levels (data_quality_code, quality_name, description)
VALUES (0, 'Low quality', 'Lower source data quality'),
       (1, 'High quality', 'Higher source data quality')
ON CONFLICT (data_quality_code) DO UPDATE
SET quality_name = EXCLUDED.quality_name, description = EXCLUDED.description
WHERE (oltp.data_quality_levels.quality_name, oltp.data_quality_levels.description)
    IS DISTINCT FROM (EXCLUDED.quality_name, EXCLUDED.description);

INSERT INTO oltp.countries (country_name)
SELECT country_name FROM stg_countries ORDER BY country_name
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO oltp.cost_categories (category_name)
SELECT DISTINCT category_name FROM stg_cost_items ORDER BY category_name
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO oltp.cities (city_name, country_id, data_quality_code)
SELECT s.city_name, c.country_id, s.data_quality_code
FROM stg_cities s
JOIN oltp.countries c ON c.country_name = s.country_name
ORDER BY s.country_name, s.city_name
ON CONFLICT (city_name, country_id) DO UPDATE
SET data_quality_code = EXCLUDED.data_quality_code
WHERE oltp.cities.data_quality_code IS DISTINCT FROM EXCLUDED.data_quality_code;

INSERT INTO oltp.cost_items (item_code, item_name, unit, category_id)
SELECT s.item_code, s.item_name, s.unit, c.category_id
FROM stg_cost_items s
JOIN oltp.cost_categories c ON c.category_name = s.category_name
ORDER BY s.item_code
ON CONFLICT (item_code) DO UPDATE
SET item_name = EXCLUDED.item_name, unit = EXCLUDED.unit, category_id = EXCLUDED.category_id
WHERE (oltp.cost_items.item_name, oltp.cost_items.unit, oltp.cost_items.category_id)
    IS DISTINCT FROM (EXCLUDED.item_name, EXCLUDED.unit, EXCLUDED.category_id);

CREATE TEMP TABLE stg_values ON COMMIT DROP AS
SELECT c.city_id, i.item_id, s.cost_value
FROM stg_city_cost_values s
JOIN oltp.countries co ON co.country_name = s.country_name
JOIN oltp.cities c ON c.country_id = co.country_id AND c.city_name = s.city_name
JOIN oltp.cost_items i ON i.item_code = s.item_code;

INSERT INTO oltp.city_cost_values (city_id, item_id, cost_value)
SELECT city_id, item_id, cost_value FROM stg_values
ON CONFLICT (city_id, item_id) DO UPDATE
SET cost_value = EXCLUDED.cost_value
WHERE oltp.city_cost_values.cost_value IS DISTINCT FROM EXCLUDED.cost_value;

INSERT INTO oltp.app_users (user_email, user_name, created_at)
SELECT user_email, MIN(user_name), MIN(created_at)
FROM stg_user_favorite_cities GROUP BY user_email ORDER BY user_email
ON CONFLICT (user_email) DO UPDATE
SET user_name = EXCLUDED.user_name
WHERE oltp.app_users.user_name IS DISTINCT FROM EXCLUDED.user_name;

CREATE TEMP TABLE stg_favorites ON COMMIT DROP AS
SELECT u.user_id, c.city_id, s.created_at
FROM stg_user_favorite_cities s
JOIN oltp.app_users u ON u.user_email = s.user_email
JOIN oltp.countries co ON co.country_name = s.country_name
JOIN oltp.cities c ON c.country_id = co.country_id AND c.city_name = s.city_name;

INSERT INTO oltp.user_favorite_cities (user_id, city_id, created_at)
SELECT user_id, city_id, created_at FROM stg_favorites
ON CONFLICT (user_id, city_id) DO UPDATE
SET created_at = EXCLUDED.created_at
WHERE oltp.user_favorite_cities.created_at IS DISTINCT FROM EXCLUDED.created_at;

DELETE FROM oltp.city_cost_values v
WHERE NOT EXISTS (
    SELECT 1 FROM stg_values s WHERE s.city_id = v.city_id AND s.item_id = v.item_id
);

DELETE FROM oltp.user_favorite_cities f
WHERE NOT EXISTS (
    SELECT 1 FROM stg_favorites s WHERE s.user_id = f.user_id AND s.city_id = f.city_id
);

DELETE FROM oltp.cities c
USING oltp.countries co
WHERE c.country_id = co.country_id
  AND NOT EXISTS (
      SELECT 1 FROM stg_cities s
      WHERE s.city_name = c.city_name AND s.country_name = co.country_name
  );

DELETE FROM oltp.cost_items i
WHERE NOT EXISTS (SELECT 1 FROM stg_cost_items s WHERE s.item_code = i.item_code);

DELETE FROM oltp.app_users u
WHERE NOT EXISTS (SELECT 1 FROM stg_user_favorite_cities s WHERE s.user_email = u.user_email);

DELETE FROM oltp.cost_categories c
WHERE NOT EXISTS (SELECT 1 FROM stg_cost_items s WHERE s.category_name = c.category_name);

DELETE FROM oltp.countries c
WHERE NOT EXISTS (SELECT 1 FROM stg_countries s WHERE s.country_name = c.country_name);

COMMIT;
