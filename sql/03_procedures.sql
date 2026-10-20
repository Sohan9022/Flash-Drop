-- ============================================================================
-- FlashDrop: Stored Procedures & Concurrency Control (ACID Engine)
-- ============================================================================

USE flash_drop_db;

DELIMITER $$

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_reserve_product
-- Concurrency Strategy: Pessimistic Row-Level Locking (SELECT ... FOR UPDATE)
-- Prevents race conditions when 1,000 users compete for 5 items.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reserve_product$$

CREATE PROCEDURE sp_reserve_product(
    IN  p_user_id        INT,
    IN  p_product_id     INT,
    IN  p_quantity       INT,
    OUT p_reservation_id INT,
    OUT p_status         VARCHAR(50),
    OUT p_message        VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_drop_status   VARCHAR(20);
    DECLARE v_drop_id       INT;
    
    -- Error handling: Rollback on any SQL exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_status = 'ERROR';
        SET p_message = 'Internal database error during reservation. Transaction rolled back.';
    END;

    -- Handle empty query results without throwing MySQL Error 1329 (02000)
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_current_stock = NULL;

    -- Validate quantity
    IF p_quantity <= 0 THEN
        SET p_reservation_id = NULL;
        SET p_status = 'INVALID_QUANTITY';
        SET p_message = 'Reservation quantity must be greater than zero.';
        LEAVE proc_label;
    END IF;

    -- Start Atomic Transaction
    START TRANSACTION;

    -- 1. Check if Drop is ACTIVE and lock product row
    SELECT p.available_stock, p.drop_id, d.status
      INTO v_current_stock, v_drop_id, v_drop_status
      FROM products p
      INNER JOIN drops d ON p.drop_id = d.drop_id
     WHERE p.product_id = p_product_id
       FOR UPDATE; -- PESSIMISTIC LOCK: Serializes concurrent attempts on this exact product

    -- Case A: Product not found
    IF v_current_stock IS NULL THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_status = 'PRODUCT_NOT_FOUND';
        SET p_message = 'Requested product does not exist.';
        LEAVE proc_label;
    END IF;

    -- Case B: Drop is not active yet (Locked or Ended)
    IF v_drop_status <> 'ACTIVE' THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_status = 'DROP_NOT_ACTIVE';
        SET p_message = CONCAT('Cannot purchase yet. Drop status is currently: ', v_drop_status);
        LEAVE proc_label;
    END IF;

    -- Case C: Insufficient Stock
    IF v_current_stock < p_quantity THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_status = 'OUT_OF_STOCK';
        SET p_message = CONCAT('Sold out! Remaining units: ', v_current_stock);
        LEAVE proc_label;
    END IF;

    -- Case D: Stock is Available -> Reserve for 5 minutes (TTL)
    -- Deduct live available stock
    UPDATE products
       SET available_stock = available_stock - p_quantity
     WHERE product_id = p_product_id;

    -- Insert reservation record (held for 5 minutes)
    INSERT INTO cart_reservations (user_id, product_id, quantity, status, reserved_at, expires_at)
    VALUES (p_user_id, p_product_id, p_quantity, 'HELD', NOW(), DATE_ADD(NOW(), INTERVAL 5 MINUTE));

    SET p_reservation_id = LAST_INSERT_ID();
    SET p_status = 'SUCCESS';
    SET p_message = 'Stock reserved successfully for 5 minutes. Proceed to checkout.';

    COMMIT;
END proc_label$$


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_complete_checkout
-- Converts a held reservation into a confirmed permanent Order.
-- Ensures strict ACID atomicity: order creation, order items, and status update.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_complete_checkout$$

CREATE PROCEDURE sp_complete_checkout(
    IN  p_user_id        INT,
    IN  p_reservation_id INT,
    OUT p_order_id       INT,
    OUT p_status         VARCHAR(50),
    OUT p_message        VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_res_user_id   INT;
    DECLARE v_product_id    INT;
    DECLARE v_quantity      INT;
    DECLARE v_res_status    VARCHAR(20);
    DECLARE v_expires_at    DATETIME;
    DECLARE v_unit_price    DECIMAL(10, 2);
    DECLARE v_total_price   DECIMAL(10, 2);

    -- Rollback on error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_status = 'ERROR';
        SET p_message = 'Checkout failed. Transaction rolled back.';
    END;

    -- Handle empty query results without throwing MySQL Error 1329 (02000)
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_res_user_id = NULL;

    START TRANSACTION;

    -- 1. Lock and inspect reservation
    SELECT r.user_id, r.product_id, r.quantity, r.status, r.expires_at, p.price
      INTO v_res_user_id, v_product_id, v_quantity, v_res_status, v_expires_at, v_unit_price
      FROM cart_reservations r
      INNER JOIN products p ON r.product_id = p.product_id
     WHERE r.reservation_id = p_reservation_id
       FOR UPDATE;

    -- Validation checks
    IF v_res_user_id IS NULL THEN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_status = 'RESERVATION_NOT_FOUND';
        SET p_message = 'Reservation does not exist.';
        LEAVE proc_label;
    END IF;

    IF v_res_user_id <> p_user_id THEN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_status = 'UNAUTHORIZED';
        SET p_message = 'This reservation belongs to a different user.';
        LEAVE proc_label;
    END IF;

    IF v_res_status <> 'HELD' THEN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_status = 'INVALID_STATUS';
        SET p_message = CONCAT('Reservation is already: ', v_res_status);
        LEAVE proc_label;
    END IF;

    IF v_expires_at < NOW() THEN
        -- Reservation expired before checkout!
        UPDATE cart_reservations SET status = 'EXPIRED' WHERE reservation_id = p_reservation_id;
        UPDATE products SET available_stock = available_stock + v_quantity WHERE product_id = v_product_id;
        COMMIT;
        SET p_order_id = NULL;
        SET p_status = 'EXPIRED';
        SET p_message = 'Your 5-minute reservation expired. Items returned to inventory.';
        LEAVE proc_label;
    END IF;

    -- Calculate total
    SET v_total_price = v_quantity * v_unit_price;

    -- 2. Create Order
    INSERT INTO orders (user_id, total_amount, status, order_date)
    VALUES (p_user_id, v_total_price, 'COMPLETED', NOW());
    
    SET p_order_id = LAST_INSERT_ID();

    -- 3. Create Order Line Items
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (p_order_id, v_product_id, v_quantity, v_unit_price);

    -- 4. Mark reservation as checked out
    UPDATE cart_reservations
       SET status = 'CHECKED_OUT'
     WHERE reservation_id = p_reservation_id;

    SET p_status = 'SUCCESS';
    SET p_message = 'Order placed successfully!';

    COMMIT;
END proc_label$$


-- ----------------------------------------------------------------------------
-- PROCEDURE 3: sp_sweep_expired_reservations
-- Reclaims inventory from expired cart reservations back to available_stock.
-- Called by the background Scheduled Event.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_sweep_expired_reservations$$

CREATE PROCEDURE sp_sweep_expired_reservations(OUT p_swept_count INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_res_id INT;
    DECLARE v_prod_id INT;
    DECLARE v_qty INT;

    -- Rollback on error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_swept_count = 0;
    END;

    -- Cursor to iterate over all expired holds with deterministic ordering
    DECLARE cur_expired CURSOR FOR
        SELECT reservation_id, product_id, quantity
          FROM cart_reservations
         WHERE status = 'HELD' AND expires_at < NOW()
         ORDER BY product_id ASC, reservation_id ASC
           FOR UPDATE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SET p_swept_count = 0;

    START TRANSACTION;

    OPEN cur_expired;

    read_loop: LOOP
        FETCH cur_expired INTO v_res_id, v_prod_id, v_qty;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Return reserved stock to product pool
        UPDATE products
           SET available_stock = available_stock + v_qty
         WHERE product_id = v_prod_id;

        -- Update reservation status
        UPDATE cart_reservations
           SET status = 'EXPIRED'
         WHERE reservation_id = v_res_id;

        SET p_swept_count = p_swept_count + 1;
    END LOOP;

    CLOSE cur_expired;

    COMMIT;
END$$

DELIMITER ;
