CREATE SCHEMA IF NOT EXISTS olist;

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'olist';

-- 1. Customer dimension
CREATE TABLE olist.dim_customer (
    customer_unique_id VARCHAR(50) PRIMARY KEY
);


-- 2. Product dimension
CREATE TABLE olist.dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name TEXT,
    product_category_name_english TEXT,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(10,2),
    product_length_cm NUMERIC(10,2),
    product_height_cm NUMERIC(10,2),
    product_width_cm NUMERIC(10,2)
);


-- 3. Seller dimension
CREATE TABLE olist.dim_seller (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city TEXT,
    seller_state VARCHAR(2)
);


-- 4. Date dimension
CREATE TABLE olist.dim_date (
    date DATE PRIMARY KEY,
    year INTEGER,
    month_number INTEGER,
    month_name VARCHAR(20),
    quarter INTEGER,
    day INTEGER,
    day_of_week VARCHAR(20),
    day_of_week_number INTEGER
);


-- 1. Orders fact table
CREATE TABLE olist.fact_orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city TEXT,
    customer_state VARCHAR(2),
    order_count INTEGER,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);


-- 2. Order items fact table
CREATE TABLE olist.fact_order_items (
    order_id VARCHAR(50),
    order_item_id INTEGER,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    customer_unique_id VARCHAR(50),
    item_count INTEGER,

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id)
        REFERENCES olist.fact_orders(order_id),

    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id)
        REFERENCES olist.dim_product(product_id),

    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES olist.dim_seller(seller_id),

    CONSTRAINT fk_items_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);


-- 3. Payments fact table
CREATE TABLE olist.fact_payments (
    order_id VARCHAR(50),
    payment_sequential INTEGER,
    payment_type VARCHAR(30),
    payment_installments INTEGER,
    payment_value NUMERIC(12,2),
    customer_unique_id VARCHAR(50),

    PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES olist.fact_orders(order_id),

    CONSTRAINT fk_payments_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);


-- 4. Reviews fact table
CREATE TABLE olist.fact_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    customer_unique_id VARCHAR(50),
    review_count INTEGER,

    PRIMARY KEY (review_id, order_id),

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES olist.fact_orders(order_id),

    CONSTRAINT fk_reviews_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);

--------------creating a dim_date_staging -------------------
CREATE TABLE olist.dim_date_staging (
    date_text TEXT,
    year INTEGER,
    month_number INTEGER,
    month_name VARCHAR(20),
    quarter INTEGER,
    day INTEGER,
    day_of_week VARCHAR(20),
    day_of_week_number INTEGER
);

INSERT INTO olist.dim_date (
    date,
    year,
    month_number,
    month_name,
    quarter,
    day,
    day_of_week,
    day_of_week_number
)
SELECT
    TO_DATE(date_text, 'DD-MM-YYYY'),
    year,
    month_number,
    month_name,
    quarter,
    day,
    day_of_week,
    day_of_week_number
FROM olist.dim_date_staging;

select * from olist.dim_date;

DROP TABLE olist.dim_date_staging;

----------------- creating fact_order_staging ----------------------
CREATE TABLE olist.fact_orders_staging (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix VARCHAR(10),
    customer_city TEXT,
    customer_state VARCHAR(2),
    order_count INTEGER
);

INSERT INTO olist.fact_orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_count
)
SELECT
    order_id,
    customer_id,
    order_status,

    CASE
        WHEN NULLIF(TRIM(order_purchase_timestamp), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_purchase_timestamp, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE
        WHEN NULLIF(TRIM(order_approved_at), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_approved_at, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE
        WHEN NULLIF(TRIM(order_delivered_carrier_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_delivered_carrier_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE
        WHEN NULLIF(TRIM(order_delivered_customer_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_delivered_customer_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE
        WHEN NULLIF(TRIM(order_estimated_delivery_date), '') IS NULL THEN NULL
        ELSE TO_DATE(order_estimated_delivery_date, 'DD-MM-YYYY')::TIMESTAMP
    END,

    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_count

FROM olist.fact_orders_staging;

-------------------------------------------------------------
CREATE TABLE olist.fact_order_items_staging (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    customer_unique_id TEXT,
    item_count INTEGER
);

CREATE TABLE olist.fact_reviews_staging (
    review_id TEXT,
    order_id TEXT,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT,
    customer_unique_id TEXT,
    review_count INTEGER
);

-------------
INSERT INTO olist.fact_order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    customer_unique_id,
    item_count
)
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    CASE
        WHEN NULLIF(TRIM(shipping_limit_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(shipping_limit_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,
    price,
    freight_value,
    customer_unique_id,
    item_count
FROM olist.fact_order_items_staging;


-------------------------
INSERT INTO olist.fact_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    customer_unique_id,
    review_count
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    CASE
        WHEN NULLIF(TRIM(review_creation_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(review_creation_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,
    CASE
        WHEN NULLIF(TRIM(review_answer_timestamp), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(review_answer_timestamp, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,
    customer_unique_id,
    review_count
FROM olist.fact_reviews_staging;

---------------------
DROP TABLE IF EXISTS olist.fact_orders_staging;
DROP TABLE IF EXISTS olist.fact_order_items_staging;
DROP TABLE IF EXISTS olist.fact_reviews_staging;
