-- ============================================================================
-- FlashDrop: Database Triggers (Active Automation & Audit)
-- ============================================================================

USE flash_drop_db;

DELIMITER $$

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_prevent_oversell
-- BEFORE UPDATE on products
-- Defensive Invariant: Aborts any update if available_stock would become negative.
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_prevent_oversell$$

CREATE TRIGGER trg_prevent_oversell
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    IF NEW.available_stock < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: available_stock cannot be negative.';
    END IF;

    IF NEW.available_stock > NEW.total_stock THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: available_stock cannot exceed total_stock.';
    END IF;
END$$


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_order_audit_trail
-- AFTER INSERT on orders
-- Automated Compliance: Instantly writes immutable record to order_logs.
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_order_audit_trail$$

CREATE TRIGGER trg_order_audit_trail
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO order_logs (order_id, user_id, action, details, logged_at)
    VALUES (
        NEW.order_id,
        NEW.user_id,
        'ORDER_CREATED',
        CONCAT('New order created with total amount: $', NEW.total_amount, ' and status: ', NEW.status),
        NOW()
    );
END$$


-- ----------------------------------------------------------------------------
-- TRIGGER 3: trg_order_status_update_log
-- AFTER UPDATE on orders
-- Tracks order status lifecycle (e.g. COMPLETED -> REFUNDED)
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_order_status_update_log$$

CREATE TRIGGER trg_order_status_update_log
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO order_logs (order_id, user_id, action, details, logged_at)
        VALUES (
            NEW.order_id,
            NEW.user_id,
            'STATUS_CHANGE',
            CONCAT('Order status updated from ', OLD.status, ' to ', NEW.status),
            NOW()
        );
    END IF;
END$$

DELIMITER ;
