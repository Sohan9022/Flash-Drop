-- ============================================================================
-- FlashDrop: Database Views & Performance Indexes
-- ============================================================================

USE flash_drop_db;

-- ----------------------------------------------------------------------------
-- VIEW 1: v_trending_products
-- Shows real-time sales metrics, velocity, and remaining inventory.
-- Used for the homepage live trending leaderboard.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_trending_products AS
SELECT 
    p.product_id,
    p.name AS product_name,
    p.sku,
    p.price,
    d.title AS drop_title,
    d.status AS drop_status,
    p.total_stock,
    p.available_stock,
    (p.total_stock - p.available_stock) AS units_committed_or_sold,
    ROUND(((p.total_stock - p.available_stock) / p.total_stock) * 100, 1) AS percent_claimed,
    COALESCE(SUM(CASE WHEN o.status = 'COMPLETED' THEN oi.quantity ELSE 0 END), 0) AS units_fully_purchased,
    COALESCE(SUM(CASE WHEN o.status = 'COMPLETED' THEN oi.subtotal ELSE 0.00 END), 0.00) AS total_revenue_generated
FROM products p
JOIN drops d ON p.drop_id = d.drop_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
GROUP BY 
    p.product_id, p.name, p.sku, p.price, d.title, d.status, p.total_stock, p.available_stock
ORDER BY units_committed_or_sold DESC;


-- ----------------------------------------------------------------------------
-- VIEW 2: v_user_order_history
-- Secure view for user dashboards: masks passwords, shows itemized purchases.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_user_order_history AS
SELECT 
    o.order_id,
    o.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS customer_name,
    u.email AS customer_email,
    o.total_amount,
    o.status AS order_status,
    o.order_date,
    COUNT(oi.order_item_id) AS total_distinct_items,
    SUM(oi.quantity) AS total_units_bought
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY 
    o.order_id, o.user_id, u.first_name, u.last_name, u.email, o.total_amount, o.status, o.order_date
ORDER BY o.order_date DESC;


-- ----------------------------------------------------------------------------
-- VIEW 3: v_inventory_monitor
-- Operational health view for warehouse managers.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_inventory_monitor AS
SELECT 
    w.warehouse_name,
    w.city,
    w.state,
    p.product_id,
    p.name AS product_name,
    p.total_stock,
    p.available_stock,
    COUNT(CASE WHEN r.status = 'HELD' THEN 1 END) AS active_cart_holds,
    COALESCE(SUM(CASE WHEN r.status = 'HELD' THEN r.quantity ELSE 0 END), 0) AS units_currently_reserved
FROM warehouses w
JOIN products p ON w.warehouse_id = p.warehouse_id
LEFT JOIN cart_reservations r ON p.product_id = r.product_id
GROUP BY 
    w.warehouse_name, w.city, w.state, p.product_id, p.name, p.total_stock, p.available_stock;


-- ----------------------------------------------------------------------------
-- PERFORMANCE INDEXES (High Concurrency Optimizations)
-- ----------------------------------------------------------------------------
-- Optimizes queries filtering by drop status and inventory availability
CREATE INDEX idx_products_drop_avail ON products(drop_id, available_stock);

-- Optimizes order lookup for specific users ordered by date
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date DESC);
