\set ON_ERROR_STOP on

CREATE OR REPLACE VIEW olap.vw_city_affordability AS
SELECT f.date_key, d.full_date, c.city_key, c.city_id,
       country.country_name, c.city_name, q.data_quality_code,
       c.affordability_tier, c.salary_tier, c.rent_tier,
       f.avg_salary, f.rent_cost, f.food_cost, f.transport_cost,
       f.utilities_cost, f.internet_cost,
       f.monthly_cost_proxy, f.affordability_score
FROM olap.fact_affordability_snapshot f
JOIN olap.dim_date d ON d.date_key = f.date_key
JOIN olap.dim_city_scd c ON c.city_key = f.city_key
JOIN olap.dim_country country ON country.country_key = c.country_key
JOIN olap.dim_data_quality q ON q.data_quality_key = c.data_quality_key;

CREATE OR REPLACE VIEW olap.vw_city_cost_by_category AS
SELECT f.date_key, d.full_date, c.city_key, c.city_id,
       country.country_name, c.city_name,
       category.category_name, i.item_key, i.item_code, i.item_name, i.unit,
       f.cost_value
FROM olap.fact_city_cost f
JOIN olap.dim_date d ON d.date_key = f.date_key
JOIN olap.dim_city_scd c ON c.city_key = f.city_key
JOIN olap.dim_country country ON country.country_key = c.country_key
JOIN olap.dim_cost_item i ON i.item_key = f.item_key
JOIN olap.dim_cost_category category ON category.category_key = i.category_key;

CREATE OR REPLACE VIEW olap.vw_city_lifestyle_tags AS
SELECT b.date_key, d.full_date, c.city_key, c.city_id,
       country.country_name, c.city_name, t.tag_name, t.tag_description,
       f.avg_salary, f.monthly_cost_proxy, f.affordability_score
FROM olap.bridge_city_lifestyle_tag b
JOIN olap.dim_date d ON d.date_key = b.date_key
JOIN olap.dim_city_scd c ON c.city_key = b.city_key
JOIN olap.dim_country country ON country.country_key = c.country_key
JOIN olap.dim_lifestyle_tag t ON t.lifestyle_tag_key = b.lifestyle_tag_key
JOIN olap.fact_affordability_snapshot f
    ON f.city_key = b.city_key AND f.date_key = b.date_key;
