CREATE DATABASE library;
USE library;
CREATE TABLE stores (
    store_id BIGINT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    city VARCHAR(120) NOT NULL
);
CREATE TABLE books_retail (
    book_id BIGINT PRIMARY KEY,
    store_id BIGINT NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    stock INT NOT NULL CHECK (stock >= 0),
    FOREIGN KEY (store_id) REFERENCES stores (store_id)
);
INSERT INTO stores VALUES (41, 'Central Books', 'Moscow');
INSERT INTO books_retail VALUES (501, 41, 990.00, 12);
