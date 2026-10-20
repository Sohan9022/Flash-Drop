-- ============================================================================
-- FlashDrop: High-Concurrency Product Release Engine
-- Database Schema & Table Definitions (3NF Normalization)
-- Target DBMS: MySQL 8.0+
-- ============================================================================

CREATE DATABASE IF NOT EXISTS flash_drop_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE flash_drop_db;

-- ----------------------------------------------------------------------------
-- Drop existing tables in reverse dependency order for clean recreation
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS order_logs;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS cart_reservations;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS drops;
DROP TABLE IF EXISTS warehouses;
DROP TABLE IF EXISTS users;

-- ============================================================================
-- 1. USERS TABLE
-- Normalization: 1NF compliant (atomic names, single email, no repeating groups)
-- ============================================================================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_email (email)
) ENGINE=InnoDB;

-- ============================================================================
-- 2. WAREHOUSES TABLE
-- Normalization: 3NF compliant (separates warehouse location from product details,
-- removing transitive dependencies).
-- ============================================================================
CREATE TABLE warehouses (
    warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL DEFAULT 'USA',
    postal_code VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================================
-- 3. DROPS TABLE
-- Represents scheduled drop events (e.g. "Midnight Sneaker Drop").
-- Products are locked until drop_start_time.
-- ============================================================================
CREATE TABLE drops (
    drop_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    drop_start_time DATETIME NOT NULL,
    drop_end_time DATETIME NOT NULL,
    status ENUM('LOCKED', 'ACTIVE', 'ENDED') NOT NULL DEFAULT 'LOCKED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_drop_timeline CHECK (drop_end_time > drop_start_time),
    INDEX idx_drop_status_time (status, drop_start_time)
) ENGINE=InnoDB;

-- ============================================================================
-- 4. PRODUCTS TABLE
-- Normalization: 2NF & 3NF.
-- Stores product specifications, total stock, and real-time available stock.
-- Strict CHECK constraint: available_stock can NEVER be negative!
-- ============================================================================
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    drop_id INT NOT NULL,
    warehouse_id INT NOT NULL,
    sku VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    total_stock INT NOT NULL,
    available_stock INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_products_drop FOREIGN KEY (drop_id) 
        REFERENCES drops (drop_id) ON DELETE RESTRICT,
    CONSTRAINT fk_products_warehouse FOREIGN KEY (warehouse_id) 
        REFERENCES warehouses (warehouse_id) ON DELETE RESTRICT,
    CONSTRAINT chk_total_stock_positive CHECK (total_stock >= 0),
    CONSTRAINT chk_available_stock_bounds CHECK (available_stock >= 0 AND available_stock <= total_stock),
    INDEX idx_product_drop (drop_id),
    INDEX idx_product_sku (sku)
) ENGINE=InnoDB;

-- ============================================================================
-- 5. CART_RESERVATIONS TABLE
-- Critical for Flash Drops: When a user adds an item to cart, stock is held
-- for a TTL (e.g. 5 minutes). If user doesn't checkout, sweeper event restores stock.
-- ============================================================================
CREATE TABLE cart_reservations (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    status ENUM('HELD', 'CHECKED_OUT', 'EXPIRED', 'CANCELLED') NOT NULL DEFAULT 'HELD',
    reserved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    CONSTRAINT fk_reservations_user FOREIGN KEY (user_id) 
        REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_reservations_product FOREIGN KEY (product_id) 
        REFERENCES products (product_id) ON DELETE RESTRICT,
    CONSTRAINT chk_reservation_quantity CHECK (quantity > 0),
    INDEX idx_reservation_sweeper (status, expires_at),
    INDEX idx_user_active_hold (user_id, status)
) ENGINE=InnoDB;

-- ============================================================================
-- 6. ORDERS TABLE
-- Records successful checkouts.
-- ============================================================================
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED') NOT NULL DEFAULT 'COMPLETED',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) 
        REFERENCES users (user_id) ON DELETE RESTRICT,
    INDEX idx_order_user (user_id),
    INDEX idx_order_date (order_date)
) ENGINE=InnoDB;

-- ============================================================================
-- 7. ORDER_ITEMS TABLE
-- 1NF Normalization: Resolves 1-to-many relationship between orders and products.
-- Stores item snapshot price at time of purchase.
-- ============================================================================
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) 
        REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) 
        REFERENCES products (product_id) ON DELETE RESTRICT,
    CONSTRAINT chk_item_quantity CHECK (quantity > 0)
) ENGINE=InnoDB;

-- ============================================================================
-- 8. ORDER_LOGS (AUDIT TRAIL)
-- Automatically populated by database trigger on order events.
-- Provides immutable security audit trail.
-- ============================================================================
CREATE TABLE order_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    user_id INT NOT NULL,
    action VARCHAR(50) NOT NULL,
    details TEXT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_logs_order FOREIGN KEY (order_id) 
        REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_logs_user FOREIGN KEY (user_id) 
        REFERENCES users (user_id) ON DELETE CASCADE,
    INDEX idx_log_order (order_id),
    INDEX idx_log_time (logged_at)
) ENGINE=InnoDB;
