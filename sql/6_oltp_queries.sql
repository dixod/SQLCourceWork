\set ON_ERROR_STOP on

SELECT co.country_name, c.city_name, v.cost_value AS monthly_salary_usd
FROM oltp.city_cost_values v
JOIN oltp.cities c ON c.city_id = v.city_id
JOIN oltp.countries co ON co.country_id = c.country_id
JOIN oltp.cost_items i ON i.item_id = v.item_id
WHERE i.item_code = 'x54'
ORDER BY v.cost_value DESC, co.country_name, c.city_name
LIMIT 20;

SELECT co.country_name, i.item_code, i.item_name, i.unit,
       ROUND(AVG(v.cost_value), 2) AS average_value,
       COUNT(*) AS cities_with_value
FROM oltp.city_cost_values v
JOIN oltp.cities c ON c.city_id = v.city_id
JOIN oltp.countries co ON co.country_id = c.country_id
JOIN oltp.cost_items i ON i.item_id = v.item_id
GROUP BY co.country_name, i.item_code, i.item_name, i.unit
ORDER BY co.country_name, i.item_code;

SELECT co.country_name, c.city_name, COUNT(*) AS favorite_count
FROM oltp.user_favorite_cities f
JOIN oltp.cities c ON c.city_id = f.city_id
JOIN oltp.countries co ON co.country_id = c.country_id
GROUP BY co.country_name, c.city_name
ORDER BY favorite_count DESC, co.country_name, c.city_name
LIMIT 20;

SELECT co.country_name, q.quality_name, COUNT(*) AS city_count
FROM oltp.cities c
JOIN oltp.countries co ON co.country_id = c.country_id
JOIN oltp.data_quality_levels q ON q.data_quality_code = c.data_quality_code
GROUP BY co.country_name, q.quality_name
ORDER BY co.country_name, q.quality_name;
