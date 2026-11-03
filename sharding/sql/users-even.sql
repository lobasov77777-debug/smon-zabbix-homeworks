CREATE DATABASE library;
USE library;
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(160) NOT NULL,
    CONSTRAINT users_even CHECK (MOD(user_id, 2) = 0)
);
INSERT INTO users VALUES (102, 'Anna Petrova', 'anna@example.test');
