CREATE DATABASE library;
USE library;
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(160) NOT NULL,
    CONSTRAINT users_odd CHECK (MOD(user_id, 2) = 1)
);
INSERT INTO users VALUES (101, 'Ivan Petrov', 'ivan@example.test');
