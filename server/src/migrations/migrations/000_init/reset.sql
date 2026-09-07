-- Step 1: Disable Foreign Key Checks Temporarily
SET session_replication_role = replica;

-- Step 2: Drop All Tables in the Public Schema
DO $$ 
DECLARE 
    table_record RECORD;
BEGIN
    FOR table_record IN (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE 'DROP TABLE IF EXISTS "' || table_record.tablename || '" CASCADE';
    END LOOP;
END $$;

-- Step 3: Drop All Functions in the Public Schema
DO $$ 
DECLARE 
    func_record RECORD;
BEGIN
    FOR func_record IN (
        SELECT proname, oid 
        FROM pg_proc 
        WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    ) LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS "' || func_record.proname || '"(' || pg_get_function_identity_arguments(func_record.oid) || ') CASCADE';
    END LOOP;
END $$;

-- Step 4: Drop All Views in the Public Schema
DO $$ 
DECLARE 
    view_record RECORD;
BEGIN
    FOR view_record IN (
        SELECT viewname 
        FROM pg_views 
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE 'DROP VIEW IF EXISTS "' || view_record.viewname || '" CASCADE';
    END LOOP;
END $$;

-- Step 5: Drop All Sequences in the Public Schema
DO $$ 
DECLARE 
    seq_record RECORD;
BEGIN
    FOR seq_record IN (
        SELECT relname AS sequencename
        FROM pg_class
        WHERE relkind = 'S' -- 'S' indicates a sequence
          AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    ) LOOP
        EXECUTE 'DROP SEQUENCE IF EXISTS "' || seq_record.sequencename || '" CASCADE';
    END LOOP;
END $$;

-- Step 6: Drop All Enums in the Public Schema
DO $$ 
DECLARE 
    enum_record RECORD;
BEGIN
    FOR enum_record IN (
        SELECT typname AS enumname
        FROM pg_type
        WHERE typtype = 'e' -- 'e' indicates an enum type
          AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    ) LOOP
        EXECUTE 'DROP TYPE IF EXISTS "' || enum_record.enumname || '" CASCADE';
    END LOOP;
END $$;

-- Step 7: Re-enable Foreign Key Checks
SET session_replication_role = origin;