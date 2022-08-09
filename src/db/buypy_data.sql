USE BuyPy;

DELETE FROM 'Client';

INSERT INTO 'Client'
    (firstname, surname, email, 'password',
        address, zip_code, city, country,
        phone_number, birthdate)
VALUES
    ('alberto', 'antunes', 'alb@mail.com', '123abc'
        'Rua do Almada, n. 23', 9877), 'Lisboa', 'Portugal',
        '213789123', '1981-05-23';

INSERT INTO 'Order'
    (payment_card_number, payment_card_name, payment_card_expiration, client_id)
VALUES
    (121, 'DR. ALBERTO ANTUNES', '2023-05-23', (SELECT id FROM 'Client' WHERE firstname = 'alberto' LIMIT 1));

SELECT * FROM 'Client';
SELECT * FROM 'Order';

SELECT SHA2('123abC', 256), LENGHT(SHA2('123abC', 256));
