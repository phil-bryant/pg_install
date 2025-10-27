-- ==========================================
-- Database Initialization Script
-- ==========================================
-- This script creates the core database schema
-- including tables, indexes, and constraints

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schema for application tables
CREATE SCHEMA IF NOT EXISTS app;

-- Set search path
SET search_path TO app, public;

-- ==========================================
-- TABLES
-- ==========================================

-- Users table
CREATE TABLE IF NOT EXISTS app.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT username_length CHECK (length(username) >= 3)
);

-- Products table
CREATE TABLE IF NOT EXISTS app.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(100) UNIQUE NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    cost DECIMAL(10, 2),
    stock_quantity INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    category VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT price_positive CHECK (price >= 0),
    CONSTRAINT cost_positive CHECK (cost >= 0 OR cost IS NULL),
    CONSTRAINT stock_non_negative CHECK (stock_quantity >= 0)
);

-- Orders table
CREATE TABLE IF NOT EXISTS app.orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    total_amount DECIMAL(10, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    shipping_amount DECIMAL(10, 2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT valid_status CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
    CONSTRAINT total_amount_positive CHECK (total_amount >= 0)
);

-- Order Items table
CREATE TABLE IF NOT EXISTS app.order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES app.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES app.products(id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT quantity_positive CHECK (quantity > 0),
    CONSTRAINT unit_price_positive CHECK (unit_price >= 0)
);

-- Audit log table
CREATE TABLE IF NOT EXISTS app.audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,
    action VARCHAR(50) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- ==========================================
-- INDEXES
-- ==========================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON app.users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON app.users(username);
CREATE INDEX IF NOT EXISTS idx_users_active ON app.users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON app.users(created_at);

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_products_sku ON app.products(sku);
CREATE INDEX IF NOT EXISTS idx_products_category ON app.products(category);
CREATE INDEX IF NOT EXISTS idx_products_active ON app.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_name ON app.products(name);

-- Orders indexes
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON app.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON app.orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON app.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON app.orders(created_at);

-- Order items indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON app.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON app.order_items(product_id);

-- Audit log indexes
CREATE INDEX IF NOT EXISTS idx_audit_log_table_name ON app.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_record_id ON app.audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON app.audit_log(changed_at);

-- ==========================================
-- FUNCTIONS
-- ==========================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION app.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate order number
CREATE OR REPLACE FUNCTION app.generate_order_number()
RETURNS VARCHAR AS $$
DECLARE
    new_order_number VARCHAR(50);
BEGIN
    new_order_number := 'ORD-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || LPAD(NEXTVAL('app.order_number_seq')::TEXT, 6, '0');
    RETURN new_order_number;
END;
$$ LANGUAGE plpgsql;

-- Create sequence for order numbers
CREATE SEQUENCE IF NOT EXISTS app.order_number_seq START 1;

-- Function to calculate order item subtotal
CREATE OR REPLACE FUNCTION app.calculate_order_item_subtotal()
RETURNS TRIGGER AS $$
BEGIN
    NEW.subtotal = NEW.quantity * NEW.unit_price;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update product stock on order
CREATE OR REPLACE FUNCTION app.update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE app.products
        SET stock_quantity = stock_quantity - NEW.quantity
        WHERE id = NEW.product_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE app.products
        SET stock_quantity = stock_quantity + OLD.quantity
        WHERE id = OLD.product_id;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE app.products
        SET stock_quantity = stock_quantity + OLD.quantity - NEW.quantity
        WHERE id = NEW.product_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to log changes (audit trail)
CREATE OR REPLACE FUNCTION app.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO app.audit_log (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', row_to_json(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO app.audit_log (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', row_to_json(OLD), row_to_json(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO app.audit_log (table_name, record_id, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', row_to_json(OLD), current_user);
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- TRIGGERS
-- ==========================================

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON app.users
    FOR EACH ROW
    EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON app.products
    FOR EACH ROW
    EXECUTE FUNCTION app.update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON app.orders
    FOR EACH ROW
    EXECUTE FUNCTION app.update_updated_at_column();

-- Trigger to auto-calculate order item subtotal
CREATE TRIGGER calculate_subtotal
    BEFORE INSERT OR UPDATE ON app.order_items
    FOR EACH ROW
    EXECUTE FUNCTION app.calculate_order_item_subtotal();

-- Trigger to update product stock
CREATE TRIGGER update_stock_on_order_item
    AFTER INSERT OR UPDATE OR DELETE ON app.order_items
    FOR EACH ROW
    EXECUTE FUNCTION app.update_product_stock();

-- Audit triggers
CREATE TRIGGER audit_users
    AFTER INSERT OR UPDATE OR DELETE ON app.users
    FOR EACH ROW
    EXECUTE FUNCTION app.audit_trigger_function();

CREATE TRIGGER audit_orders
    AFTER INSERT OR UPDATE OR DELETE ON app.orders
    FOR EACH ROW
    EXECUTE FUNCTION app.audit_trigger_function();

CREATE TRIGGER audit_products
    AFTER INSERT OR UPDATE OR DELETE ON app.products
    FOR EACH ROW
    EXECUTE FUNCTION app.audit_trigger_function();

-- ==========================================
-- VIEWS
-- ==========================================

-- View for order summary
CREATE OR REPLACE VIEW app.order_summary AS
SELECT
    o.id,
    o.order_number,
    o.status,
    u.username,
    u.email,
    o.total_amount,
    o.tax_amount,
    o.shipping_amount,
    COUNT(oi.id) as item_count,
    o.created_at,
    o.completed_at
FROM app.orders o
JOIN app.users u ON o.user_id = u.id
LEFT JOIN app.order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.order_number, o.status, u.username, u.email, 
         o.total_amount, o.tax_amount, o.shipping_amount, 
         o.created_at, o.completed_at;

-- View for product inventory
CREATE OR REPLACE VIEW app.product_inventory AS
SELECT
    p.id,
    p.name,
    p.sku,
    p.price,
    p.cost,
    p.stock_quantity,
    p.category,
    CASE
        WHEN p.stock_quantity = 0 THEN 'Out of Stock'
        WHEN p.stock_quantity < 10 THEN 'Low Stock'
        ELSE 'In Stock'
    END as stock_status,
    p.is_active
FROM app.products p;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Database schema initialized successfully!';
    RAISE NOTICE 'Tables created: users, products, orders, order_items, audit_log';
    RAISE NOTICE 'Triggers created: updated_at, stock management, audit logging';
    RAISE NOTICE 'Views created: order_summary, product_inventory';
END $$;



