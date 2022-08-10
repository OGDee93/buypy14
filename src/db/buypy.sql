/*
	DDL for the BuyPy Online Store

	(C) Ana Mendes & Diogo Ferreira, 2022
*/

DELIMITER //

DROP DATABASE IF EXISTS BuyPy
//

CREATE DATABASE IF NOT EXISTS BuyPy
//

USE BuyPy

DROP TABLE IF EXISTS 'Client'
//

CREATE TABLE 'Client'(
	ID 			INT PRIMARY KEY AUTO_INCREMENT,
	firstname	VARCHAR(250) NOT NULL,
	surname		VARCHAR(250) NOT NULL,
	email		VARCHAR(250) NOT NULL UNIQUE,
				-- CHECK(email RLIKE BINARY "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?: [a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
	'password'	CHAR(64) NOT NULL, 
	address		 VARCHAR(100) NOT NULL,
	zip_code	 SMALLINT UNSIGNED NOT NULL,
	city		 VARCHAR(30) NOT NULL,
	country		 VARCHAR(30) NOT NULL DEFAULT 'Portugal',
	last_login	 TIMESTAMP NOT NULL DEFAULT(NOW()),
	phone_number VARCHAR(15) NOT NULL CHECK(phone_number RLIKE '^[0-9]{6,}$'),
	birthdate	 DATE NOT NULL,
	is_active	 BOOLEAN DEFAULT TRUE

CONSTRAINT EmailChk CHECK(email RLIKE "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
    -- CONSTRAINT EmailChk CHECK(email RLIKE "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"),

	-- Exemplos de CONSTRAINTs para a password mas que não podem aqui ficar por causa
    -- do hashing da pwd que é feito no trigger
    
    -- CONSTRAINT PasswdChk CHECK(`password` RLIKE "(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!$#?%]).{6,}")
    -- CONSTRAINT PasswdChk CHECK(
    --         LENGTH(`password`) >= 6
    --     AND `password` RLIKE '[a-z]'
    --     AND `password` RLIKE '[A-Z]'
    --     AND `password` RLIKE '[0-9]'
    --     AND `password` RLIKE '[!$#?%]'
    -- )
)//

/*TRIGGER 
 > Associado a uma tabela que faz uma acção antes ou depois de qualquer coisa.
*/

DROP TRIGGER IF EXISTS BeforeNewClient
//
CREATE TRIGGER BeforeNewClient BEFORE INSERT ON `Client`
FOR EACH ROW
BEGIN
    CALL ValidateClient(NEW.phone_number, NEW.country, NEW.`password`);
END//

DROP TRIGGER IF EXISTS BeforeUpdatingClient
//
CREATE TRIGGER BeforeUpdatingClient BEFORE UPDATE ON `Client`
FOR EACH ROW
BEGIN
    CALL ValidateClient(NEW.phone_number, NEW.country, NEW.`password`);
END//

DROP PROCEDURE IF EXISTS ValidateClient
//
CREATE PROCEDURE ValidateClient(
    IN phone_number   VARCHAR(15),
    IN country        VARCHAR(30),
    INOUT `password`  CHAR(64)
)
BEGIN
    DECLARE INVALID_PHONE_NUMBER CONDITION FOR SQLSTATE '45000';
    DECLARE INVALID_PASSWORD CONDITION FOR SQLSTATE '45001';
    
    IF country = 'Portugal' AND LEFT(phone_number, 3) <> '351' THEN
        SIGNAL INVALID_PHONE_NUMBER
            SET MESSAGE_TEXT = 'Invalid phone number for Portugal';
    END IF;

    -- We have to this, and not with CHECK CONSTRAINT because
    -- by that time, the password is already hashed (see below)
    -- The password can only be hashed here, in this trigger.
    IF `password` NOT RLIKE "(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!$#?%]).{6,}" THEN
        SIGNAL INVALID_PASSWORD
            SET MESSAGE_TEXT = 'Invalid password';
    END IF;

    SET `password` := SHA2(`password`, 256);

END//

DROP TABLE IF EXISTS 'Order'
//

CREATE TABLE 'Order'(
	ID 							INT PRIMARY KEY AUTO_INCREMENT,
	date_time					DATETIME NOT NULL DEFAULT(NOW()),
	delivery_method				ENUM('regular', 'urgent') DEFAULT 'regular',
	status						ENUM('open', 'processing', 'pending', 'closed', 'cancelled') DEFAULT 'open',
	payment_card_number			BIGINT NOT NULL,
	payment_card_name			VARCHAR(20) NOT NULL,
	payment_card_expiration		DATE NOT NULL,
	client_id					INT NOT NULL,

	--CONSTRAINT ExpirationDate CHECK(payment_card_expiration >= CURDATE()),
	FOREIGN KEY ClientFK (client_id) REFERENCES 'Client'(id)


)//

DROP TRIGGER IF EXISTS ValidateOrder
//

CREATE TRIGGER ValidadeteOrder BEFORE INSERT ON 'Order'
FOR EACH ROW
BEGIN
	DECLARE INVALID_EXPIRATION_DATE CONDITION FOR SQLSTATE '450020';
	IF NEW.payment_card_expiration < CURDATE() THEN
			SIGNAL INVALID_EXPIRATION_DATE
				SET MESSAGE_TEXT = 'Invalid date card expiration';
	END IF;
END//


DROP TABLE IF EXISTS Order_Item
//

CREATE TABLE Order_Item(
	ID 					INT PRIMARY KEY AUTO_INCREMENT,
	order_id 			INT NOT NULL,
	product_id			INT NOT NULL,
	quantity			INT NOT NULL,
	price 				DECIMAL(3,2) NOT NULL,
	vat_amount			DECIMAL(3,2) NOT NULL,

	CONSTRAINT Qta CHECK(quantity > 0),
	CONSTRAINT pricePositive CHECK(price > 0),
	CONSTRAINT VatAmountPositive CHECK(vat_amount > 0),

	FOREIGN KEY ProductFK (product_id) REFERENCES Product(ID),
	FOREIGN KEY OrderFK (order_id) REFERENCES Order(ID)
)//


DROP TABLE IF EXISTS Product
//

CREATE TABLE Product(
	ID 				CHAR(10) PRIMARY KEY,
	quantity		INT NOT NULL UNSIGNED,
	price 			DECIMAL(10,2) NOT NULL,
	vat				DECIMAL(4,2) NOT NULL,
					# Falta %
	score			TINYINT,
	product_image	VARCHAR(1000) COMMENT 'URL for the image',
	active			BOOL NOT NULL DEFAULT TRUE,
	reason			VARCHAR(500)

	CONSTRAINT pricePositive CHECK(price > 0),
	CONSTRAINT VatPercentage CHECK(vat BETWEEN 0 AND 101),
	CONSTRAINT scoreNumber CHECK(score BETWEEN 1 AND 6)
)//


DROP TABLE IF EXISTS Book
//

CREATE TABLE Book(
	product_id 			CHAR(10) PRIMARY KEY,
	isbn13				VARCHAR(20) NOT NULL UNIQUE,
	title 				VARCHAR(50) NOT NULL,
	genre				VARCHAR(50) NOT NULL,
	publisher			VARCHAR(100) NOT NULL,
	publication_date	DATE NOT NULL,

	FOREIGN KEY ProductFK (product_id) REFERENCES Product(ID),
		ON UPDATE CASCADE ON DELETE CASCADE

	CONSTRAINT ISBN13Chk CHECK(isbn13 RLIKE '^[0-9\-]+$')
)//


DROP FUNCTION IF EXISTS ValidISBN13
//

CREATE FUNCTION ValidISBN13(isbn13 VARCHAR(20))
RETURNS BOOL
DETERMINISTIC
BEGIN
	DECLARE i TINYINT UNSIGNED DEFAULT 1;
    DECLARE s SMALLINT UNSIGNED DEFAULT 0;

    SET isbn13 = REPLACE(isbn13, '-', '');
    -- SET isbn13 = REPLACE(isbn13, ' ', '');
    -- SET isbn13 = REPLACE(isbn13, '_', '');

    IF isbn13 NOT RLIKE '^[0-9]{13}$' THEN    
    	RETURN FALSE;
    END IF;

    WHILE i < 14 DO
        SET s = s + SUBSTRING(isbn13, i, 1) * IF(i % 2 = 1, 1, 3);
        SET i = i + 1;
    END WHILE;

    RETURN s % 10 = 0;
END//

/*
CREATE PROCEDURE ValidateISBN13(IN isbn13 VARCHAR(20))
BEGIN
    DECLARE INVALID_ISBN13 CONDITION FOR SQLSTATE '45023';    
    DECLARE i TINYINT UNSIGNED DEFAULT 1;
    DECLARE s SMALLINT UNSIGNED DEFAULT 0;

    SET isbn13 = REPLACE(isbn13, '-', '');
    -- SET isbn13 = REPLACE(isbn13, ' ', '');
    -- SET isbn13 = REPLACE(isbn13, '_', '');

    IF isbn13 NOT RLIKE '^[0-9]{13}$' THEN    
        SIGNAL INVALID_ISBN13 
           SET MESSAGE_TEXT = 'Invalid ISBN-13';
    END IF;

    WHILE i < 14 DO
        SET s = s + SUBSTRING(isbn13, i, 1) * IF(i % 2 = 1, 1, 3);
        SET i = i + 1;
    END WHILE;

    IF s % 10 <> 0 THEN
        SIGNAL INVALID_ISBN13 
           SET MESSAGE_TEXT = 'Invalid ISBN-13';
    END IF; 
END//
*/

DROP TABLE IF EXISTS BookAuthor
//

CREATE TABLE BookAuthor(
	ID 					INT PRIMARY KEY AUTO_INCREMENT,
	product_id 			INT NOT NULL,
	author_id			INT NOT NULL,

	FOREIGN KEY ProductFK (product_id) REFERENCES Product(ID),
	FOREIGN KEY AuthorFK (product_id) REFERENCES Author(ID)
)//


DROP TABLE IF EXISTS Author
//

CREATE TABLE Author(
	ID 				INT PRIMARY KEY AUTO_INCREMENT,
	name 			VARCHAR(100),
	fullname		VARCHAR(100),
	birthdate		DATE NOT NULL

)//

# TRIGGER 

DROP TABLE IF EXISTS Eletronic
//

CREATE TABLE Eletronic(
	product_id 		INT NOT NULL,
	serial_num		INT NOT NULL UNIQUE,
	brand 			VARCHAR(20) NOT NULL,
	model			VARCHAR(20) NOT NULL,
	spec_tec		LONGTEXT,
	'type'			VARCHAR(10) NOT NULL,

	FOREIGN KEY productFK (product_id) REFERENCES Product(ID)
)//

DROP TABLE IF EXISTS Recommendation
//

CREATE TABLE Recommendation(
	ID 			INT PRIMARY KEY AUTO_INCREMENT,
	product_id 	INT NOT NULL,
	client_id	INT NOT NULL,
	reason		VARCHAR(500),
	start_date 	DATE,

	FOREIGN KEY ProductFK (product_id) REFERENCES Product(ID),
	FOREIGN KEY ClientFK (client_id) REFERENCES 'Client'(ID)
)//

# TRIGGER validar que a data não seja inferior que a data actual
DROP TRIGGER IF EXISTS startDateChck
//

CREATE TRIGGER startDateChck BEFORE INSERT ON Recommendation
FOR EACH ROW
BEGIN
	DECLARE INVALID_CURRENT_DATE CONDITION FOR SQLSTATE '450020';
	IF NEW.start_date < CURDATE() THEN
		SIGNAL INVALID_CURRENT_DATE
			SET MESSAGE_TEXT = 'Invalid date for recommendation';
	END IF;
END//

/* 
SET @pwd := 'abc'

SELECT LENGTH(@pwd) > 6 
	   AND @pwd RLIKE BINARY '^[a-z]+$'
	   AND @pwd RLIKE BINARY '^[A-Z]+$'
	   AND @pwd RLIKE BINARY '^[0-9]+$'

	^ = inicio
	
	ON DELETE CASCADE ON UPDATE CASCADE > Actualizar ou apagar registo de dados
*/


























