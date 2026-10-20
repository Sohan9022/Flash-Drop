-- ============================================================================
-- FlashDrop: Sample Seed Data
-- ============================================================================

USE flash_drop_db;

-- Clear previous test data in proper order
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE order_logs;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
TRUNCATE TABLE cart_reservations;
TRUNCATE TABLE products;
TRUNCATE TABLE drops;
TRUNCATE TABLE warehouses;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 1. USERS
-- ----------------------------------------------------------------------------
INSERT INTO users (user_id, first_name, last_name, email, password_hash, phone_number) VALUES
(1, 'Alex', 'Chen', 'alex.chen@example.com', '$2b$12$e80yV7Y9uLgJ4c3h5wX7ue1948x7a79a1f28b', '+1-555-0101'),
(2, 'Sarah', 'Connor', 'sarah.c@example.com', '$2b$12$m19pX8Z0vKhK5d4i6yY8vf2059y8b80b2g39c', '+1-555-0102'),
(3, 'Marcus', 'Vance', 'marcus.v@example.com', '$2b$12$k28qW9A1wLiL6e5j7zZ9wg3160z9c91c3h40d', '+1-555-0103'),
(4, 'Elena', 'Rostova', 'elena.r@example.com', '$2b$12$j37rV0B2xMjM7f6k8aA0xh4271a0d02d4i51e', '+1-555-0104'),
(5, 'Liam', 'Smith', 'liam.s@example.com', '$2b$12$i46sU1C3yNkN8g7l9bB1yi5382b1e13e5j62f', '+1-555-0105');

-- ----------------------------------------------------------------------------
-- 2. WAREHOUSES
-- ----------------------------------------------------------------------------
INSERT INTO warehouses (warehouse_id, warehouse_name, city, state, country, postal_code) VALUES
(1, 'Metro Fulfillment Hub East', 'Secaucus', 'NJ', 'USA', '07094'),
(2, 'West Coast High-Velocity DC', 'Reno', 'NV', 'USA', '89502');

-- ----------------------------------------------------------------------------
-- 3. DROPS
-- Drop 1: ACTIVE NOW (Happening right now, items can be bought)
-- Drop 2: LOCKED (Scheduled for future, locked until start time)
-- ----------------------------------------------------------------------------
INSERT INTO drops (drop_id, title, description, drop_start_time, drop_end_time, status) VALUES
(1, 'Midnight Cyberpunk Sneaker Drop', 'Ultra-exclusive 50-pair limited release cyber-sneakers.', 
    DATE_SUB(NOW(), INTERVAL 10 MINUTE), 
    DATE_ADD(NOW(), INTERVAL 2 HOUR), 
    'ACTIVE'),
(2, 'Chrono Titanium Timepiece Drop', 'Titanium skeleton automatic watch. 10 pieces worldwide.', 
    DATE_ADD(NOW(), INTERVAL 1 HOUR), 
    DATE_ADD(NOW(), INTERVAL 3 HOUR), 
    'LOCKED');

-- ----------------------------------------------------------------------------
-- 4. PRODUCTS
-- Notice small stock counts (5 and 10) to clearly test flash-drop sellouts!
-- ----------------------------------------------------------------------------
INSERT INTO products (product_id, drop_id, warehouse_id, sku, name, description, price, total_stock, available_stock) VALUES
(1, 1, 1, 'SNKR-CYBER-001', 'Cyberpunk Runner X9', 'Neon glow accented lightweight responsive runners.', 220.00, 5, 5),
(2, 1, 1, 'SNKR-NEO-002', 'Neo-Tokyo Street High-Top', 'Reflective matte black high-top street edition.', 280.00, 10, 10),
(3, 2, 2, 'WATCH-CHRONO-99', 'Chronos Skeleton Watch #01', 'Custom CNC machined titanium skeleton watch.', 1250.00, 2, 2),
(4, 1, 2, 'HOODIE-SPEC-003', 'Holographic Oversized Hoodie', 'Heavyweight fleece with holographic cyber print.', 110.00, 20, 20);
