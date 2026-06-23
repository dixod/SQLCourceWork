SELECT
    co.country_name AS country,
    ci.city_name AS city,
    ccv.cost_value AS average_monthly_net_salary
FROM oltp.city_cost_values ccv
JOIN oltp.cities ci
    ON ci.city_id = ccv.city_id
JOIN oltp.countries co
    ON co.country_id = ci.country_id
JOIN oltp.cost_items it
    ON it.item_id = ccv.item_id
WHERE it.item_code = 'x54'
ORDER BY
    ccv.cost_value DESC,
    co.country_name,
    ci.city_name
LIMIT 20;

SELECT
    co.country_name AS country,
    cc.category_name AS cost_category,
    ROUND(AVG(ccv.cost_value), 2) AS average_cost_value,
    COUNT(*) AS number_of_cost_values
FROM oltp.city_cost_values ccv
JOIN oltp.cities ci
    ON ci.city_id = ccv.city_id
JOIN oltp.countries co
    ON co.country_id = ci.country_id
JOIN oltp.cost_items it
    ON it.item_id = ccv.item_id
JOIN oltp.cost_categories cc
    ON cc.category_id = it.category_id
GROUP BY
    co.country_name,
    cc.category_name
ORDER BY
    co.country_name,
    cc.category_name;

SELECT
    co.country_name AS country,
    ci.city_name AS city,
    COUNT(*) AS favorite_count
FROM oltp.user_favorite_cities ufc
JOIN oltp.cities ci
    ON ci.city_id = ufc.city_id
JOIN oltp.countries co
    ON co.country_id = ci.country_id
GROUP BY
    co.country_name,
    ci.city_name
ORDER BY
    favorite_count DESC,
    co.country_name,
    ci.city_name
LIMIT 20;

SELECT
    co.country_name AS country,
    dql.data_quality_code AS data_quality_code,
    dql.quality_name AS data_quality_name,
    COUNT(*) AS city_count
FROM oltp.cities ci
JOIN oltp.countries co
    ON co.country_id = ci.country_id
JOIN oltp.data_quality_levels dql
    ON dql.data_quality_code = ci.data_quality_code
GROUP BY
    co.country_name,
    dql.data_quality_code,
    dql.quality_name
ORDER BY
    city_count DESC,
    co.country_name,
    dql.data_quality_code;
