\set ON_ERROR_STOP on

SELECT full_date, country_name, city_name,
       avg_salary, monthly_cost_proxy, affordability_score
FROM olap.vw_city_affordability
WHERE date_key = (SELECT MAX(date_key) FROM olap.dim_date)
  AND affordability_score IS NOT NULL
ORDER BY affordability_score DESC, country_name, city_name
LIMIT 20;

SELECT country_name,
       COUNT(*) AS city_count,
       COUNT(affordability_score) AS cities_with_complete_data,
       ROUND(AVG(affordability_score), 4) AS average_affordability,
       ROUND(AVG(avg_salary), 2) AS average_salary
FROM olap.vw_city_affordability
WHERE date_key = (SELECT MAX(date_key) FROM olap.dim_date)
GROUP BY country_name
ORDER BY average_affordability DESC NULLS LAST, country_name;

SELECT full_date, country_name,
       COUNT(*) AS city_count,
       COUNT(affordability_score) AS cities_with_complete_data,
       ROUND(AVG(affordability_score), 4) AS average_affordability
FROM olap.vw_city_affordability
GROUP BY full_date, country_name
ORDER BY full_date, country_name;

SELECT tag_name, COUNT(DISTINCT city_id) AS city_count,
       ROUND(AVG(affordability_score), 4) AS average_affordability
FROM olap.vw_city_lifestyle_tags
WHERE date_key = (SELECT MAX(date_key) FROM olap.dim_date)
GROUP BY tag_name
ORDER BY city_count DESC, tag_name;
