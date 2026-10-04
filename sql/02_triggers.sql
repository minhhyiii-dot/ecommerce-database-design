-- Install after importing synthetic seed data.
-- Coursework scope: inserts and deletes only; updates and cancellations are not synchronized.

DELIMITER //

CREATE TRIGGER after_order_item_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;
END //

CREATE TRIGGER after_order_item_insert_total
AFTER INSERT ON order_items
FOR EACH ROW
FOLLOWS after_order_item_insert
BEGIN
    UPDATE orders
    SET total_amount = shipping_fee + (
        SELECT COALESCE(SUM(quantity * unit_price), 0)
        FROM order_items
        WHERE order_id = NEW.order_id
    )
    WHERE order_id = NEW.order_id;
END //

CREATE TRIGGER after_order_item_delete
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock_quantity = stock_quantity + OLD.quantity
    WHERE product_id = OLD.product_id;

    UPDATE orders
    SET total_amount = shipping_fee + (
        SELECT COALESCE(SUM(quantity * unit_price), 0)
        FROM order_items
        WHERE order_id = OLD.order_id
    )
    WHERE order_id = OLD.order_id;
END //

DELIMITER ;
