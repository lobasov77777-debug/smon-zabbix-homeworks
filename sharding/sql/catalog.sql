CREATE DATABASE library;
USE library;
CREATE TABLE books_catalog (
    book_id BIGINT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    author VARCHAR(120) NOT NULL
);
INSERT INTO books_catalog VALUES (501, 'Databases', 'A. Example');
