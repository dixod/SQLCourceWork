SELECT
    country_name AS country,
    city_name AS city,
    affordability_score,
    avg_salary,
    monthly_cost_proxy,
    affordability_tier
FROM olap.vw_city_affordability
ORDER BY
    affordability_score DESC,
    country_name,
    city_name
LIMIT 20;

SELECT
    country_name AS country,
    ROUND(AVG(affordability_score), 4) AS average_affordability_score,
    ROUND(AVG(avg_salary), 2) AS average_salary,
    COUNT(*) AS number_of_cities
FROM olap.vw_city_affordability
GROUP BY
    country_name
ORDER BY
    average_affordability_score DESC,
    average_salary DESC,
    country_name;

SELECT
    country_name AS country,
    category_name AS cost_category,
    ROUND(AVG(cost_value), 2) AS average_cost_value,
    COUNT(*) AS number_of_rows
FROM olap.vw_city_cost_by_category
GROUP BY
    country_name,
    category_name
ORDER BY
    country_name,
    category_name;

SELECT
    tag_name,
    COUNT(*) AS number_of_cities,
    ROUND(AVG(affordability_score), 4) AS average_affordability_score,
    ROUND(AVG(avg_salary), 2) AS average_salary
FROM olap.vw_city_lifestyle_tags
GROUP BY
    tag_name
ORDER BY
    number_of_cities DESC,
    tag_name;
