-- ============================================================================
-- FlashDrop: MySQL Scheduled Events (Time-Based Automation)
-- ============================================================================

USE flash_drop_db;

-- Ensure MySQL Event Scheduler is running
SET GLOBAL event_scheduler = ON;

-- ----------------------------------------------------------------------------
-- EVENT 1: evt_unlock_flash_drops
-- Runs every 10 seconds.
-- Automatically activates drops whose start time has arrived,
-- and concludes drops whose end time has passed.
-- ----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_unlock_flash_drops;

DELIMITER $$

CREATE EVENT evt_unlock_flash_drops
ON SCHEDULE EVERY 10 SECOND
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    -- 1. Unlock drops that should now be active
    UPDATE drops
       SET status = 'ACTIVE'
     WHERE status = 'LOCKED'
       AND NOW() >= drop_start_time
       AND NOW() < drop_end_time;

    -- 2. Conclude drops that have reached their end time
    UPDATE drops
       SET status = 'ENDED'
     WHERE status = 'ACTIVE'
       AND NOW() >= drop_end_time;
END$$

DELIMITER ;


-- ----------------------------------------------------------------------------
-- EVENT 2: evt_sweep_expired_carts
-- Runs every 30 seconds.
-- Reclaims unpurchased items from abandoned carts (held > 5 minutes)
-- and returns the stock back to the active inventory pool.
-- ----------------------------------------------------------------------------
DROP EVENT IF EXISTS evt_sweep_expired_carts;

DELIMITER $$

CREATE EVENT evt_sweep_expired_carts
ON SCHEDULE EVERY 30 SECOND
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DECLARE v_swept INT;
    CALL sp_sweep_expired_reservations(v_swept);
END$$

DELIMITER ;
