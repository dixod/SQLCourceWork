CREATE OR REPLACE VIEW olap.vw_city_affordability AS
SELECT
    dc.country_name,
    dcs.city_name,
    ddq.data_quality_code,
    dcs.affordability_tier,
    dcs.salary_tier,
    dcs.rent_tier,
    fas.avg_salary,
    fas.monthly_cost_proxy,
    fas.affordability_score,
    fas.restaurants_cost_total,
    fas.groceries_cost_total,
    fas.transport_cost_total,
    fas.housing_cost_total
FROM olap.fact_affordability_snapshot fas
JOIN olap.dim_city_scd dcs
    ON dcs.city_key = fas.city_key
JOIN olap.dim_country dc
    ON dc.country_key = dcs.country_key
JOIN olap.dim_data_quality ddq
    ON ddq.data_quality_key = dcs.data_quality_key
WHERE dcs.is_current = TRUE;


CREATE OR REPLACE VIEW olap.vw_city_cost_by_category AS
SELECT
    dc.country_name,
    dcs.city_name,
    dcc.category_name,
    dci.item_name,
    dci.unit,
    fcc.cost_value,
    dd.full_date
FROM olap.fact_city_cost fcc
JOIN olap.dim_city_scd dcs
    ON dcs.city_key = fcc.city_key
JOIN olap.dim_country dc
    ON dc.country_key = dcs.country_key
JOIN olap.dim_cost_item dci
    ON dci.item_key = fcc.item_key
JOIN olap.dim_cost_category dcc
    ON dcc.category_key = dci.category_key
JOIN olap.dim_date dd
    ON dd.date_key = fcc.date_key
WHERE dcs.is_current = TRUE;


CREATE OR REPLACE VIEW olap.vw_city_lifestyle_tags AS
SELECT
    dc.country_name,
    dcs.city_name,
    dlt.tag_name,
    dlt.tag_description,
    fas.affordability_score,
    fas.avg_salary,
    fas.monthly_cost_proxy
FROM olap.bridge_city_lifestyle_tag bclt
JOIN olap.dim_city_scd dcs
    ON dcs.city_key = bclt.city_key
JOIN olap.dim_country dc
    ON dc.country_key = dcs.country_key
JOIN olap.dim_lifestyle_tag dlt
    ON dlt.lifestyle_tag_key = bclt.lifestyle_tag_key
JOIN olap.fact_affordability_snapshot fas
    ON fas.city_key = dcs.city_key
WHERE dcs.is_current = TRUE;
