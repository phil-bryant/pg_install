-- ==========================================
-- Users and Roles Configuration
-- ==========================================
-- This script configures database permissions
-- and grants appropriate access to different roles

-- ==========================================
-- GRANT SCHEMA USAGE
-- ==========================================

-- Grant usage on schema to roles
GRANT USAGE ON SCHEMA app TO read_write_role;
GRANT USAGE ON SCHEMA app TO read_only_role;

-- Grant usage to application users
GRANT USAGE ON SCHEMA app TO app_user;
GRANT USAGE ON SCHEMA app TO app_readonly;

-- ==========================================
-- PERMISSIONS FOR READ-WRITE ROLE
-- ==========================================

-- Grant all privileges on all tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO read_write_role;

-- Grant usage on all sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO read_write_role;

-- Grant execute on all functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO read_write_role;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO read_write_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT USAGE, SELECT ON SEQUENCES TO read_write_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT EXECUTE ON FUNCTIONS TO read_write_role;

-- ==========================================
-- PERMISSIONS FOR READ-ONLY ROLE
-- ==========================================

-- Grant select on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA app TO read_only_role;

-- Grant usage on sequences (for currval)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO read_only_role;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT SELECT ON TABLES TO read_only_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT USAGE, SELECT ON SEQUENCES TO read_only_role;

-- ==========================================
-- ASSIGN ROLES TO USERS
-- ==========================================

-- Grant read-write role to app_user
GRANT read_write_role TO app_user;

-- Grant read-only role to app_readonly
GRANT read_only_role TO app_readonly;

-- ==========================================
-- ROW-LEVEL SECURITY (Optional - Commented)
-- ==========================================

-- Uncomment to enable row-level security
/*
-- Enable RLS on sensitive tables
ALTER TABLE app.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.orders ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own data
CREATE POLICY users_own_data ON app.users
    FOR ALL
    TO app_user
    USING (username = current_user);

-- Policy: Users can only see their own orders
CREATE POLICY users_own_orders ON app.orders
    FOR ALL
    TO app_user
    USING (user_id IN (SELECT id FROM app.users WHERE username = current_user));

-- Policy: Read-only users can see all data
CREATE POLICY readonly_all_users ON app.users
    FOR SELECT
    TO read_only_role
    USING (true);

CREATE POLICY readonly_all_orders ON app.orders
    FOR SELECT
    TO read_only_role
    USING (true);
*/

-- ==========================================
-- REVOKE PUBLIC ACCESS
-- ==========================================

-- Revoke public access from schema
REVOKE ALL ON SCHEMA app FROM PUBLIC;

-- Revoke public access from all tables
REVOKE ALL ON ALL TABLES IN SCHEMA app FROM PUBLIC;

-- Revoke public access from all sequences
REVOKE ALL ON ALL SEQUENCES IN SCHEMA app FROM PUBLIC;

-- Revoke public access from all functions
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA app FROM PUBLIC;

-- ==========================================
-- SPECIAL GRANTS
-- ==========================================

-- Allow app_owner full control (already has it as owner, but explicit)
GRANT ALL ON SCHEMA app TO app_owner;
GRANT ALL ON ALL TABLES IN SCHEMA app TO app_owner;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app TO app_owner;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA app TO app_owner;

-- Allow app_owner to grant permissions
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO read_write_role;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app
    GRANT SELECT ON TABLES TO read_only_role;

-- ==========================================
-- VERIFY PERMISSIONS
-- ==========================================

-- Create a verification function
CREATE OR REPLACE FUNCTION app.verify_permissions()
RETURNS TABLE (
    role_name TEXT,
    schema_name TEXT,
    privilege_type TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        grantee::TEXT as role_name,
        table_schema::TEXT as schema_name,
        privilege_type::TEXT,
        'GRANTED'::TEXT as status
    FROM information_schema.role_table_grants
    WHERE table_schema = 'app'
    AND grantee IN ('read_write_role', 'read_only_role', 'app_user', 'app_readonly', 'app_owner')
    ORDER BY grantee, privilege_type;
END;
$$ LANGUAGE plpgsql;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Users and Roles Configuration Complete!';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Roles configured:';
    RAISE NOTICE '  - read_write_role: Full CRUD access';
    RAISE NOTICE '  - read_only_role: SELECT access only';
    RAISE NOTICE '';
    RAISE NOTICE 'User assignments:';
    RAISE NOTICE '  - app_owner: Full database owner';
    RAISE NOTICE '  - app_user: Read-write access (via read_write_role)';
    RAISE NOTICE '  - app_readonly: Read-only access (via read_only_role)';
    RAISE NOTICE '';
    RAISE NOTICE 'Run: SELECT * FROM app.verify_permissions();';
    RAISE NOTICE 'to view all granted permissions.';
    RAISE NOTICE '==========================================';
END $$;



