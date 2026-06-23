CREATE SCHEMA IF NOT EXISTS olap;

CREATE TABLE IF NOT EXISTS olap.dim_country (
    country_key BIGSERIAL PRIMARY KEY,
    country_name VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS olap.dim_data_quality (
    data_quality_key BIGSERIAL PRIMARY KEY,
    data_quality_code SMALLINT NOT NULL UNIQUE,
    quality_name VARCHAR(50) NOT NULL UNIQUE,
    CHECK (data_quality_code IN (0, 1))
);

CREATE TABLE IF NOT EXISTS olap.dim_cost_category (
    category_key BIGSERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS olap.dim_cost_item (
    item_key BIGSERIAL PRIMARY KEY,
    item_code VARCHAR(10) NOT NULL UNIQUE,
    item_name VARCHAR(300) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    category_key BIGINT NOT NULL REFERENCES olap.dim_cost_category(category_key),
    UNIQUE (item_name, category_key)
);

CREATE TABLE IF NOT EXISTS olap.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year_number INTEGER NOT NULL,
    quarter_number INTEGER NOT NULL,
    month_number INTEGER NOT NULL,
    CHECK (quarter_number BETWEEN 1 AND 4),
    CHECK (month_number BETWEEN 1 AND 12)
);

CREATE TABLE IF NOT EXISTS olap.dim_city_scd (
    city_key BIGSERIAL PRIMARY KEY,
    city_name VARCHAR(150) NOT NULL,
    country_key BIGINT NOT NULL REFERENCES olap.dim_country(country_key),
    data_quality_key BIGINT NOT NULL REFERENCES olap.dim_data_quality(data_quality_key),
    affordability_tier VARCHAR(50) NOT NULL,
    salary_tier VARCHAR(50) NOT NULL,
    rent_tier VARCHAR(50) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (valid_to IS NULL OR valid_to >= valid_from),
    UNIQUE (city_name, country_key, valid_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_city_scd_current_city
ON olap.dim_city_scd (city_name, country_key)
WHERE is_current = TRUE;

CREATE TABLE IF NOT EXISTS olap.dim_lifestyle_tag (
    lifestyle_tag_key BIGSERIAL PRIMARY KEY,
    tag_name VARCHAR(100) NOT NULL UNIQUE,
    tag_description VARCHAR(300) NOT NULL
);

CREATE TABLE IF NOT EXISTS olap.bridge_city_lifestyle_tag (
    city_key BIGINT NOT NULL REFERENCES olap.dim_city_scd(city_key),
    lifestyle_tag_key BIGINT NOT NULL REFERENCES olap.dim_lifestyle_tag(lifestyle_tag_key),
    PRIMARY KEY (city_key, lifestyle_tag_key)
);

CREATE TABLE IF NOT EXISTS olap.fact_city_cost (
    fact_city_cost_key BIGSERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES olap.dim_date(date_key),
    city_key BIGINT NOT NULL REFERENCES olap.dim_city_scd(city_key),
    item_key BIGINT NOT NULL REFERENCES olap.dim_cost_item(item_key),
    cost_value NUMERIC(16, 4) NOT NULL,
    CHECK (cost_value >= 0),
    UNIQUE (date_key, city_key, item_key)
);

CREATE TABLE IF NOT EXISTS olap.fact_affordability_snapshot (
    fact_affordability_snapshot_key BIGSERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES olap.dim_date(date_key),
    city_key BIGINT NOT NULL REFERENCES olap.dim_city_scd(city_key),
    avg_salary NUMERIC(16, 4) NOT NULL,
    monthly_cost_proxy NUMERIC(16, 4) NOT NULL,
    affordability_score NUMERIC(10, 4) NOT NULL,
    restaurants_cost_total NUMERIC(16, 4) NOT NULL,
    groceries_cost_total NUMERIC(16, 4) NOT NULL,
    transport_cost_total NUMERIC(16, 4) NOT NULL,
    housing_cost_total NUMERIC(16, 4) NOT NULL,
    CHECK (avg_salary >= 0),
    CHECK (monthly_cost_proxy >= 0),
    CHECK (affordability_score >= 0),
    CHECK (restaurants_cost_total >= 0),
    CHECK (groceries_cost_total >= 0),
    CHECK (transport_cost_total >= 0),
    CHECK (housing_cost_total >= 0),
    UNIQUE (date_key, city_key)
);

CREATE INDEX IF NOT EXISTS ix_dim_city_scd_country_key
ON olap.dim_city_scd(country_key);

CREATE INDEX IF NOT EXISTS ix_dim_city_scd_data_quality_key
ON olap.dim_city_scd(data_quality_key);

CREATE INDEX IF NOT EXISTS ix_dim_cost_item_category_key
ON olap.dim_cost_item(category_key);

CREATE INDEX IF NOT EXISTS ix_bridge_city_lifestyle_tag_city_key
ON olap.bridge_city_lifestyle_tag(city_key);

CREATE INDEX IF NOT EXISTS ix_bridge_city_lifestyle_tag_lifestyle_tag_key
ON olap.bridge_city_lifestyle_tag(lifestyle_tag_key);

CREATE INDEX IF NOT EXISTS ix_fact_city_cost_date_key
ON olap.fact_city_cost(date_key);

CREATE INDEX IF NOT EXISTS ix_fact_city_cost_city_key
ON olap.fact_city_cost(city_key);

CREATE INDEX IF NOT EXISTS ix_fact_city_cost_item_key
ON olap.fact_city_cost(item_key);

CREATE INDEX IF NOT EXISTS ix_fact_affordability_snapshot_date_key
ON olap.fact_affordability_snapshot(date_key);

CREATE INDEX IF NOT EXISTS ix_fact_affordability_snapshot_city_key
ON olap.fact_affordability_snapshot(city_key);
