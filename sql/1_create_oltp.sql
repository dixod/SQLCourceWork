CREATE SCHEMA IF NOT EXISTS oltp;

CREATE TABLE IF NOT EXISTS oltp.countries (
    country_id BIGSERIAL PRIMARY KEY,
    country_name VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS oltp.data_quality_levels (
    data_quality_code SMALLINT PRIMARY KEY,
    quality_name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(250) NOT NULL,
    CHECK (data_quality_code IN (0, 1))
);

CREATE TABLE IF NOT EXISTS oltp.cost_categories (
    category_id BIGSERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS oltp.cities (
    city_id BIGSERIAL PRIMARY KEY,
    city_name VARCHAR(150) NOT NULL,
    country_id BIGINT NOT NULL REFERENCES oltp.countries(country_id),
    data_quality_code SMALLINT NOT NULL
        REFERENCES oltp.data_quality_levels(data_quality_code),
    UNIQUE (city_name, country_id)
);

CREATE TABLE IF NOT EXISTS oltp.cost_items (
    item_id BIGSERIAL PRIMARY KEY,
    item_code VARCHAR(10) NOT NULL UNIQUE,
    item_name VARCHAR(300) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    category_id BIGINT NOT NULL REFERENCES oltp.cost_categories(category_id)
);

CREATE TABLE IF NOT EXISTS oltp.city_cost_values (
    city_cost_value_id BIGSERIAL PRIMARY KEY,
    city_id BIGINT NOT NULL REFERENCES oltp.cities(city_id),
    item_id BIGINT NOT NULL REFERENCES oltp.cost_items(item_id),
    cost_value NUMERIC(16, 4) NOT NULL,
    UNIQUE (city_id, item_id),
    CHECK (cost_value >= 0)
);

CREATE TABLE IF NOT EXISTS oltp.app_users (
    user_id BIGSERIAL PRIMARY KEY,
    user_email VARCHAR(320) NOT NULL UNIQUE,
    user_name VARCHAR(150) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS oltp.user_favorite_cities (
    user_id BIGINT NOT NULL REFERENCES oltp.app_users(user_id),
    city_id BIGINT NOT NULL REFERENCES oltp.cities(city_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, city_id)
);
