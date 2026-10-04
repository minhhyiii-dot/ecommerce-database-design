-- Canonical seven-table coursework schema. Run on an empty MySQL 8 database.
SET NAMES utf8mb4;

CREATE TABLE customers (
    customer_id int AUTO_INCREMENT PRIMARY KEY,
    full_name varchar(100) NOT null,
    email varchar(100) UNIQUE not null,
    signup_date date not null,
    date_of_birth date not null,
    city varchar(100) not null,
    status ENUM('active', 'inactive', 'banned') NOT null DEFAULT 'active'
);

CREATE TABLE categories (
    category_id int AUTO_INCREMENT PRIMARY KEY,
    category_name varchar(100) not null
);

CREATE TABLE products (
    product_id int AUTO_INCREMENT PRIMARY KEY,
    product_name varchar(100) UNIQUE not null,
    category_id int not null,
    stock_quantity int,
    price decimal(10,2) not null,
    cost decimal(10,2) not null,
    created_at datetime not null DEFAULT CURRENT_TIMESTAMP,
    is_active boolean not null DEFAULT true,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE orders (
    order_id int AUTO_INCREMENT PRIMARY KEY, 
    customer_id int NOT null,
    order_date datetime not null,
    status ENUM('pending', 'paid', 'shipped', 'delivered', 'completed', 'cancelled', 'refunded') not null,
    shipping_address varchar(100) not null,
    shipping_fee decimal(10,2) not null,
    total_amount decimal(10,2) not null,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id int AUTO_INCREMENT PRIMARY KEY,
    order_id int not null,
    product_id int not null,
    quantity int not null,
    unit_price decimal(10,2) not null,
    FOREIGN KEY  (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE payments (
    payment_id int AUTO_INCREMENT PRIMARY KEY,
    order_id int not null,
    payment_method varchar(100) not null,
    payment_status ENUM('pending', 'completed', 'failed') not null,
    paid_amount decimal(10,2) not null,
    payment_date datetime not null,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE reviews (
    review_id int AUTO_INCREMENT PRIMARY KEY,
    product_id int not null,
    customer_id int not null,
    rating DECIMAL(2,1) NOT NULL,
    review_date datetime NOT null,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
