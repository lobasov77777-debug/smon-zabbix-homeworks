USE sakila;

-- 1. Магазины с более чем 300 покупателями и их управляющие.
WITH counts AS (
    SELECT store_id, COUNT(*) AS customer_count
    FROM customer
    GROUP BY store_id
)
SELECT st.store_id, s.last_name, s.first_name, c.city, n.customer_count
FROM counts AS n
JOIN store AS st ON st.store_id = n.store_id
JOIN staff AS s ON s.staff_id = st.manager_staff_id
JOIN address AS a ON a.address_id = st.address_id
JOIN city AS c ON c.city_id = a.city_id
WHERE n.customer_count > 300;

-- 2. Фильмы длиннее средней продолжительности.
SELECT COUNT(*) AS films_above_average
FROM film
WHERE length > (SELECT AVG(length) FROM film);

-- 3. Месяц с максимальными платежами и число аренд по дате выдачи.
WITH monthly_payments AS (
    SELECT DATE_FORMAT(payment_date, '%Y-%m') AS month, SUM(amount) AS total
    FROM payment
    GROUP BY DATE_FORMAT(payment_date, '%Y-%m')
),
monthly_rentals AS (
    SELECT DATE_FORMAT(rental_date, '%Y-%m') AS month, COUNT(*) AS rental_count
    FROM rental
    GROUP BY DATE_FORMAT(rental_date, '%Y-%m')
)
SELECT p.month, p.total, COALESCE(r.rental_count, 0) AS rental_count
FROM monthly_payments AS p
LEFT JOIN monthly_rentals AS r USING (month)
ORDER BY p.total DESC, p.month
LIMIT 1;

-- 4*. Продажи по продавцам. Продажа — одна запись о платеже.
SELECT s.staff_id, s.last_name, s.first_name,
       COUNT(p.payment_id) AS sales_count,
       CASE WHEN COUNT(p.payment_id) > 8000 THEN 'Да' ELSE 'Нет' END AS `Премия`
FROM staff AS s
LEFT JOIN payment AS p ON p.staff_id = s.staff_id
GROUP BY s.staff_id, s.last_name, s.first_name
ORDER BY s.staff_id;

-- 5*. Фильмы без единой аренды, включая фильмы без экземпляров.
SELECT f.film_id, f.title
FROM film AS f
WHERE NOT EXISTS (
    SELECT 1
    FROM inventory AS i
    JOIN rental AS r ON r.inventory_id = i.inventory_id
    WHERE i.film_id = f.film_id
)
ORDER BY f.title, f.film_id;
