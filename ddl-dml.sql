-- В MySQL под администратором. Замените <пароль> перед выполнением.
CREATE USER 'sys_temp'@'localhost' IDENTIFIED BY '<пароль>';

SELECT user, host, plugin
FROM mysql.user
ORDER BY user;

GRANT ALL PRIVILEGES ON *.* TO 'sys_temp'@'localhost';
SHOW GRANTS FOR 'sys_temp'@'localhost';

-- Переподключение в консоли: mysql -u sys_temp -p
-- SOURCE — команда клиента mysql. Сначала схема, затем данные.
SOURCE sakila-schema.sql
SOURCE sakila-data.sql
SELECT CURRENT_USER();
SHOW FULL TABLES FROM sakila;

SELECT TABLE_NAME,
       GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ', ') AS primary_key
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'sakila'
  AND CONSTRAINT_NAME = 'PRIMARY'
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- Снова под администратором. Частичный отзыв ограничивает глобальные права в Sakila.
SET GLOBAL partial_revokes = ON;
REVOKE INSERT, UPDATE, DELETE ON sakila.* FROM 'sys_temp'@'localhost';
SHOW GRANTS FOR 'sys_temp'@'localhost';

-- Проверка от sys_temp. SELECT выполняется, DELETE возвращает ошибку прав.
SELECT COUNT(*) FROM sakila.actor;
DELETE FROM sakila.actor WHERE FALSE;
