/*
    DDL for the BuyPy Online Store.
    (c) Ana Mendes e Diogo Ferreira
*/

DELIMITER //

DROP DATABASE IF NOT EXISTS BuyPy
//
CREATE DATABASE BuyPy
//

USE BuyPy
//

DROP TABLE IF EXISTS 'Client'
//
CREATE TABLE 'Client' (
	id  INT PRIMARY KEY AUTO_INCRMENT,
    firstname VARCHAR(250) NOT NULL,
    surname VARCHAR(250) NOT NULL,
    email VARCHAR(50) NOT NULL UNIQUE
            CHECK(email RLIKE "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"),
    'password' VARBINARY NOT NULL 
            CHECK(
                    LENGHT('PASSWORD') >= 6
                AND 'password' RLIKE '[a-z]' 
                AND 'password' RLIKE '[A-Z]'
                AND 'password' RLIKE '[0-9]'  
                -- falta considerar simbolos: '#', '$', '?', '%' ou '!' 
            ),
    address VARCHAR(100) NOT NULL,
    zip_code SMALLINT NOT NULL,
    city VARCHAR(30) NOT NULL,
    country VARCHAR(30) NOT NULL DEFAULT 'Portugal',
    phone_number VARCHAR(15) NOT NULL CHECK(phone_number RLIKE '^[0-9]{6,}$'),
    last_login TIMESTAMP NOT NULL DEFAULT NOW(),
    birthdate DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
)//

-- ver https://www.mysqltutorial.org/mysql-triggers/mysql-after-delete-trigger/
DROP TRIGGER IF EXISTS BeforeNewClient
//
CREATE TRIGGER BeforeNewClient BEFORE INSERT ON 'Client' 
FOR EACH ROW
BEGIN
    DECLARE INVALID_PHONE_NUMBER CONDITION FOR SQLSTATE '45000';
    IF NEW-country = 'Portugal' AND LEFT(NEW.phone_number, 3) <> '351' THEN
        SIGNAL FOR SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Invalid phone number for Portugal';
    END IF;
    SET NEW.'password' := SHA2(NEW.'password', 256);
END//


DROP TABLE IF EXISTS 'Order'
//
CREATE TABLE 'Order'(
    id INT PRIMARY KEY AUTO_INCRMENT,
    date_time DATETIME NOT NULL DEFAULT (NOW()),
    delivery_method ENUM('regular', 'urgent') DEFAULT 'regular',
    status ENUM('open', 'processing', 'closed', 'cancelled')
                    DEFAULT 'open',
    payment_card_number BIGINT NOT NULL,
    payment_card_name VARCHAR(20) NOT NULL,
    payment_card_expiration DATE NOT NULL,
    client_id INT NOT NULL,

    FOREIGN KEY CientFK (client_id) REFERENCES 'Client'(id)
)//





























