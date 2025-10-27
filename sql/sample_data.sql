-- ==========================================
-- Sample Data Population
-- ==========================================
-- This script populates the database with
-- sample data for testing and development

-- Set search path
SET search_path TO app, public;

-- ==========================================
-- INSERT SAMPLE USERS
-- ==========================================

INSERT INTO app.users (username, email, password_hash, first_name, last_name, is_verified)
VALUES
    ('johndoe', 'john.doe@example.com', crypt('password123', gen_salt('bf')), 'John', 'Doe', true),
    ('janesmith', 'jane.smith@example.com', crypt('password123', gen_salt('bf')), 'Jane', 'Smith', true),
    ('bobwilson', 'bob.wilson@example.com', crypt('password123', gen_salt('bf')), 'Bob', 'Wilson', true),
    ('alicejones', 'alice.jones@example.com', crypt('password123', gen_salt('bf')), 'Alice', 'Jones', true),
    ('charliebrn', 'charlie.brown@example.com', crypt('password123', gen_salt('bf')), 'Charlie', 'Brown', false)
ON CONFLICT (username) DO NOTHING;

-- ==========================================
-- INSERT SAMPLE PRODUCTS
-- ==========================================

INSERT INTO app.products (name, description, sku, price, cost, stock_quantity, category)
VALUES
    ('Laptop Pro 15"', 'High-performance laptop with 15" display', 'LAPTOP-PRO-15', 1299.99, 899.99, 25, 'Electronics'),
    ('Wireless Mouse', 'Ergonomic wireless mouse with USB receiver', 'MOUSE-WIRELESS-01', 29.99, 12.50, 150, 'Accessories'),
    ('Mechanical Keyboard', 'RGB backlit mechanical keyboard', 'KEYBOARD-MECH-RGB', 89.99, 45.00, 75, 'Accessories'),
    ('USB-C Hub', '7-in-1 USB-C hub with HDMI and card reader', 'HUB-USBC-7IN1', 49.99, 22.00, 100, 'Accessories'),
    ('Monitor 27"', '27-inch 4K UHD monitor', 'MONITOR-27-4K', 399.99, 250.00, 40, 'Electronics'),
    ('Laptop Stand', 'Adjustable aluminum laptop stand', 'STAND-LAPTOP-ALU', 39.99, 18.00, 200, 'Accessories'),
    ('Webcam HD', '1080p HD webcam with microphone', 'WEBCAM-HD-1080', 79.99, 35.00, 60, 'Electronics'),
    ('Desk Lamp LED', 'Adjustable LED desk lamp', 'LAMP-DESK-LED', 34.99, 15.00, 120, 'Office'),
    ('Cable Organizer', 'Desktop cable management system', 'ORGANIZER-CABLE', 14.99, 5.00, 300, 'Office'),
    ('Portable SSD 1TB', '1TB portable solid state drive', 'SSD-PORTABLE-1TB', 129.99, 75.00, 50, 'Electronics')
ON CONFLICT (sku) DO NOTHING;

-- ==========================================
-- INSERT SAMPLE ORDERS
-- ==========================================

DO $$
DECLARE
    user_john UUID;
    user_jane UUID;
    user_bob UUID;
    user_alice UUID;
    
    product_laptop UUID;
    product_mouse UUID;
    product_keyboard UUID;
    product_monitor UUID;
    product_webcam UUID;
    product_stand UUID;
    
    order1 UUID;
    order2 UUID;
    order3 UUID;
    order4 UUID;
BEGIN
    -- Get user IDs
    SELECT id INTO user_john FROM app.users WHERE username = 'johndoe';
    SELECT id INTO user_jane FROM app.users WHERE username = 'janesmith';
    SELECT id INTO user_bob FROM app.users WHERE username = 'bobwilson';
    SELECT id INTO user_alice FROM app.users WHERE username = 'alicejones';
    
    -- Get product IDs
    SELECT id INTO product_laptop FROM app.products WHERE sku = 'LAPTOP-PRO-15';
    SELECT id INTO product_mouse FROM app.products WHERE sku = 'MOUSE-WIRELESS-01';
    SELECT id INTO product_keyboard FROM app.products WHERE sku = 'KEYBOARD-MECH-RGB';
    SELECT id INTO product_monitor FROM app.products WHERE sku = 'MONITOR-27-4K';
    SELECT id INTO product_webcam FROM app.products WHERE sku = 'WEBCAM-HD-1080';
    SELECT id INTO product_stand FROM app.products WHERE sku = 'STAND-LAPTOP-ALU';
    
    -- Order 1: John's complete workstation setup
    INSERT INTO app.orders (user_id, order_number, status, total_amount, tax_amount, shipping_amount)
    VALUES (user_john, generate_order_number(), 'delivered', 1869.95, 149.60, 25.00)
    RETURNING id INTO order1;
    
    INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
    VALUES
        (order1, product_laptop, 1, 1299.99),
        (order1, product_mouse, 1, 29.99),
        (order1, product_keyboard, 1, 89.99),
        (order1, product_stand, 1, 39.99);
    
    UPDATE app.orders SET completed_at = CURRENT_TIMESTAMP - INTERVAL '5 days' WHERE id = order1;
    
    -- Order 2: Jane's monitor and accessories
    INSERT INTO app.orders (user_id, order_number, status, total_amount, tax_amount, shipping_amount)
    VALUES (user_jane, generate_order_number(), 'shipped', 544.96, 43.60, 15.00)
    RETURNING id INTO order2;
    
    INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
    VALUES
        (order2, product_monitor, 1, 399.99),
        (order2, product_webcam, 1, 79.99),
        (order2, product_mouse, 2, 29.99);
    
    -- Order 3: Bob's bulk mouse order
    INSERT INTO app.orders (user_id, order_number, status, total_amount, tax_amount, shipping_amount)
    VALUES (user_bob, generate_order_number(), 'processing', 299.90, 24.00, 10.00)
    RETURNING id INTO order3;
    
    INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
    VALUES
        (order3, product_mouse, 10, 29.99);
    
    -- Order 4: Alice's pending order
    INSERT INTO app.orders (user_id, order_number, status, total_amount, tax_amount, shipping_amount)
    VALUES (user_alice, generate_order_number(), 'pending', 219.97, 17.60, 10.00)
    RETURNING id INTO order4;
    
    INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
    VALUES
        (order4, product_keyboard, 1, 89.99),
        (order4, product_webcam, 1, 79.99),
        (order4, product_stand, 1, 39.99);
END $$;

-- ==========================================
-- VERIFY DATA
-- ==========================================

DO $$
DECLARE
    user_count INTEGER;
    product_count INTEGER;
    order_count INTEGER;
    order_item_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM app.users;
    SELECT COUNT(*) INTO product_count FROM app.products;
    SELECT COUNT(*) INTO order_count FROM app.orders;
    SELECT COUNT(*) INTO order_item_count FROM app.order_items;
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Sample Data Population Complete!';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Records inserted:';
    RAISE NOTICE '  - Users: %', user_count;
    RAISE NOTICE '  - Products: %', product_count;
    RAISE NOTICE '  - Orders: %', order_count;
    RAISE NOTICE '  - Order Items: %', order_item_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Test queries:';
    RAISE NOTICE '  SELECT * FROM app.users;';
    RAISE NOTICE '  SELECT * FROM app.products;';
    RAISE NOTICE '  SELECT * FROM app.order_summary;';
    RAISE NOTICE '  SELECT * FROM app.product_inventory;';
    RAISE NOTICE '  SELECT * FROM app.audit_log;';
    RAISE NOTICE '==========================================';
END $$;

-- ==========================================
-- SAMPLE QUERIES FOR TESTING
-- ==========================================

-- Uncomment to run verification queries:

/*
-- View all users
SELECT username, email, first_name, last_name, is_verified, created_at
FROM app.users
ORDER BY created_at;

-- View product inventory
SELECT * FROM app.product_inventory
ORDER BY stock_status, name;

-- View order summary
SELECT * FROM app.order_summary
ORDER BY created_at DESC;

-- View recent audit log
SELECT table_name, action, changed_by, changed_at
FROM app.audit_log
ORDER BY changed_at DESC
LIMIT 20;

-- Order details with items
SELECT 
    o.order_number,
    o.status,
    u.username,
    p.name as product_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal
FROM app.orders o
JOIN app.users u ON o.user_id = u.id
JOIN app.order_items oi ON o.id = oi.order_id
JOIN app.products p ON oi.product_id = p.id
ORDER BY o.created_at DESC;

-- Low stock products
SELECT name, sku, stock_quantity, category
FROM app.products
WHERE stock_quantity < 10
ORDER BY stock_quantity;
*/



