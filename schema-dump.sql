

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."event_location_type_enum" AS ENUM (
    'online',
    'physical',
    'hybrid'
);


ALTER TYPE "public"."event_location_type_enum" OWNER TO "postgres";


CREATE TYPE "public"."event_rsvp_status_enum" AS ENUM (
    'invited',
    'attending',
    'maybe',
    'not_attending'
);


ALTER TYPE "public"."event_rsvp_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."event_status_enum" AS ENUM (
    'scheduled',
    'cancelled',
    'completed'
);


ALTER TYPE "public"."event_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."job_title_enum" AS ENUM (
    'Analyst',
    'Senior Analyst',
    'Associate',
    'Senior Associate',
    'Vice President',
    'Principal',
    'Partner'
);


ALTER TYPE "public"."job_title_enum" OWNER TO "postgres";


CREATE TYPE "public"."membership_status_enum" AS ENUM (
    'Active',
    'Canceled',
    'PastDue',
    'Trialing'
);


ALTER TYPE "public"."membership_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."network_connection_status" AS ENUM (
    'Interested',
    'Connected'
);


ALTER TYPE "public"."network_connection_status" OWNER TO "postgres";


CREATE TYPE "public"."payment_status_enum" AS ENUM (
    'succeeded',
    'pending',
    'failed',
    'requires_action',
    'canceled'
);


ALTER TYPE "public"."payment_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."screening_status_enum" AS ENUM (
    'submitted',
    'approved',
    'rejected'
);


ALTER TYPE "public"."screening_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."slack_channel_geo" AS ENUM (
    'Global',
    'NYC',
    'SF',
    'London',
    'Boston',
    'Other'
);


ALTER TYPE "public"."slack_channel_geo" OWNER TO "postgres";


CREATE TYPE "public"."slack_channel_type" AS ENUM (
    'General',
    'Geographic',
    'Industry',
    'Interest/Athletic'
);


ALTER TYPE "public"."slack_channel_type" OWNER TO "postgres";


CREATE TYPE "public"."support_ticket_status" AS ENUM (
    'New',
    'Open',
    'Closed'
);


ALTER TYPE "public"."support_ticket_status" OWNER TO "postgres";


CREATE TYPE "public"."user_status_enum" AS ENUM (
    'Approved',
    'Approved_EmailSent',
    'AccountCreated_AwaitingProfile',
    'ProfileComplete_AwaitingPayment',
    'PaymentFailed',
    'Member_AwaitingPreferences',
    'Member_Active',
    'Denied',
    'Inactive'
);


ALTER TYPE "public"."user_status_enum" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."audit_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    audit_row audit_logs;
BEGIN
    audit_row = ROW(
        gen_random_uuid(),        -- id
        TG_TABLE_NAME::TEXT,      -- table_name
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id 
            ELSE NEW.id 
        END,                     -- record_id
        TG_OP,                    -- operation
        CASE 
            WHEN TG_OP = 'UPDATE' OR TG_OP = 'DELETE' 
            THEN to_jsonb(OLD) 
            ELSE NULL 
        END,                      -- old_data
        CASE 
            WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' 
            THEN to_jsonb(NEW) 
            ELSE NULL 
        END,                      -- new_data
        (SELECT auth.uid()),      -- changed_by
        now(),                    -- changed_at
        current_setting('request.headers', true)::json->>'x-forwarded-for', -- ip_address
        current_setting('request.headers', true)::json->>'user-agent'      -- user_agent
    );
    
    INSERT INTO audit_logs 
    VALUES (audit_row.*);
    
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."audit_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_service_role"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF current_setting('request.jwt.claim.role')::text = 'service_role' THEN
        RETURN jsonb_build_object(
            'is_service_role', true,
            'current_role', current_setting('request.jwt.claim.role')::text,
            'timestamp', now()
        );
    ELSE
        RETURN jsonb_build_object(
            'is_service_role', false,
            'current_role', current_setting('request.jwt.claim.role')::text,
            'timestamp', now()
        );
    END IF;
END;
$$;


ALTER FUNCTION "public"."check_service_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_strong_password"("password" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    -- Password must be at least 8 characters
    IF length(password) < 8 THEN
        RAISE EXCEPTION 'Password must be at least 8 characters long';
    END IF;
    
    -- Password must contain at least one uppercase letter
    IF NOT password ~ '[A-Z]' THEN
        RAISE EXCEPTION 'Password must contain at least one uppercase letter';
    END IF;
    
    -- Password must contain at least one lowercase letter
    IF NOT password ~ '[a-z]' THEN
        RAISE EXCEPTION 'Password must contain at least one lowercase letter';
    END IF;
    
    -- Password must contain at least one number
    IF NOT password ~ '[0-9]' THEN
        RAISE EXCEPTION 'Password must contain at least one number';
    END IF;
    
    -- Password must contain at least one special character
    IF NOT password ~ '[!@#$%^&*(),.?":{}|<>]' THEN
        RAISE EXCEPTION 'Password must contain at least one special character';
    END IF;
    
    RETURN TRUE;
END;
$_$;


ALTER FUNCTION "public"."enforce_strong_password"("password" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_logo_url_from_website"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
  domain TEXT;
  project_ref TEXT := TG_ARGV[0];
BEGIN
  IF NEW.website IS NOT NULL AND (NEW.logo_url IS NULL OR NEW.logo_url = '') THEN
    -- Extract domain from website URL (simple version)
    domain := regexp_replace(NEW.website, '^https?://(www\.)?', '');
    domain := regexp_replace(domain, '/.*$', '');
    
    -- Set the logo URL using our edge function
    NEW.logo_url := 'https://' || project_ref || '.supabase.co/functions/v1/logo/' || domain;
  END IF;
  
  RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."generate_logo_url_from_website"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_auth_users"() RETURNS TABLE("id" "uuid", "email" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  SELECT id, email, created_at FROM auth.users LIMIT 1;
$$;


ALTER FUNCTION "public"."get_auth_users"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_complete_schema"() RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result jsonb;
BEGIN
    -- Get all enums
    WITH enum_types AS (
        SELECT 
            t.typname as enum_name,
            array_agg(e.enumlabel ORDER BY e.enumsortorder) as enum_values
        FROM pg_type t
        JOIN pg_enum e ON t.oid = e.enumtypid
        JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
        GROUP BY t.typname
    )
    SELECT jsonb_build_object(
        'enums',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'name', enum_name,
                    'values', to_jsonb(enum_values)
                )
            ),
            '[]'::jsonb
        )
    )
    FROM enum_types
    INTO result;

    -- Get all tables with their details
    WITH RECURSIVE 
    columns_info AS (
        SELECT 
            c.oid as table_oid,
            c.relname as table_name,
            a.attname as column_name,
            format_type(a.atttypid, a.atttypmod) as column_type,
            a.attnotnull as notnull,
            pg_get_expr(d.adbin, d.adrelid) as column_default,
            CASE 
                WHEN a.attidentity != '' THEN true
                WHEN pg_get_expr(d.adbin, d.adrelid) LIKE 'nextval%' THEN true
                ELSE false
            END as is_identity,
            EXISTS (
                SELECT 1 FROM pg_constraint con 
                WHERE con.conrelid = c.oid 
                AND con.contype = 'p' 
                AND a.attnum = ANY(con.conkey)
            ) as is_pk
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_attribute a ON a.attrelid = c.oid
        LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
        WHERE n.nspname = 'public' 
        AND c.relkind = 'r'
        AND a.attnum > 0 
        AND NOT a.attisdropped
    ),
    fk_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', con.conname,
                    'column', col.attname,
                    'foreign_schema', fs.nspname,
                    'foreign_table', ft.relname,
                    'foreign_column', fcol.attname,
                    'on_delete', CASE con.confdeltype
                        WHEN 'a' THEN 'NO ACTION'
                        WHEN 'c' THEN 'CASCADE'
                        WHEN 'r' THEN 'RESTRICT'
                        WHEN 'n' THEN 'SET NULL'
                        WHEN 'd' THEN 'SET DEFAULT'
                        ELSE NULL
                    END
                )
            ) as foreign_keys
        FROM pg_class c
        JOIN pg_constraint con ON con.conrelid = c.oid
        JOIN pg_attribute col ON col.attrelid = con.conrelid AND col.attnum = ANY(con.conkey)
        JOIN pg_class ft ON ft.oid = con.confrelid
        JOIN pg_namespace fs ON fs.oid = ft.relnamespace
        JOIN pg_attribute fcol ON fcol.attrelid = con.confrelid AND fcol.attnum = ANY(con.confkey)
        WHERE con.contype = 'f'
        GROUP BY c.oid
    ),
    index_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', i.relname,
                    'using', am.amname,
                    'columns', (
                        SELECT jsonb_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum))
                        FROM unnest(ix.indkey) WITH ORDINALITY as u(attnum, ord)
                        JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = u.attnum
                    )
                )
            ) as indexes
        FROM pg_class c
        JOIN pg_index ix ON ix.indrelid = c.oid
        JOIN pg_class i ON i.oid = ix.indexrelid
        JOIN pg_am am ON am.oid = i.relam
        WHERE NOT ix.indisprimary
        GROUP BY c.oid
    ),
    policy_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', pol.polname,
                    'command', CASE pol.polcmd
                        WHEN 'r' THEN 'SELECT'
                        WHEN 'a' THEN 'INSERT'
                        WHEN 'w' THEN 'UPDATE'
                        WHEN 'd' THEN 'DELETE'
                        WHEN '*' THEN 'ALL'
                    END,
                    'roles', (
                        SELECT string_agg(quote_ident(r.rolname), ', ')
                        FROM pg_roles r
                        WHERE r.oid = ANY(pol.polroles)
                    ),
                    'using', pg_get_expr(pol.polqual, pol.polrelid),
                    'check', pg_get_expr(pol.polwithcheck, pol.polrelid)
                )
            ) as policies
        FROM pg_class c
        JOIN pg_policy pol ON pol.polrelid = c.oid
        GROUP BY c.oid
    ),
    trigger_info AS (
        SELECT 
            c.oid as table_oid,
            jsonb_agg(
                jsonb_build_object(
                    'name', t.tgname,
                    'timing', CASE 
                        WHEN t.tgtype & 2 = 2 THEN 'BEFORE'
                        WHEN t.tgtype & 4 = 4 THEN 'AFTER'
                        WHEN t.tgtype & 64 = 64 THEN 'INSTEAD OF'
                    END,
                    'events', (
                        CASE WHEN t.tgtype & 1 = 1 THEN 'INSERT'
                             WHEN t.tgtype & 8 = 8 THEN 'DELETE'
                             WHEN t.tgtype & 16 = 16 THEN 'UPDATE'
                             WHEN t.tgtype & 32 = 32 THEN 'TRUNCATE'
                        END
                    ),
                    'statement', pg_get_triggerdef(t.oid)
                )
            ) as triggers
        FROM pg_class c
        JOIN pg_trigger t ON t.tgrelid = c.oid
        WHERE NOT t.tgisinternal
        GROUP BY c.oid
    ),
    table_info AS (
        SELECT DISTINCT 
            c.table_oid,
            c.table_name,
            jsonb_agg(
                jsonb_build_object(
                    'name', c.column_name,
                    'type', c.column_type,
                    'notnull', c.notnull,
                    'default', c.column_default,
                    'identity', c.is_identity,
                    'is_pk', c.is_pk
                ) ORDER BY c.column_name
            ) as columns,
            COALESCE(fk.foreign_keys, '[]'::jsonb) as foreign_keys,
            COALESCE(i.indexes, '[]'::jsonb) as indexes,
            COALESCE(p.policies, '[]'::jsonb) as policies,
            COALESCE(t.triggers, '[]'::jsonb) as triggers
        FROM columns_info c
        LEFT JOIN fk_info fk ON fk.table_oid = c.table_oid
        LEFT JOIN index_info i ON i.table_oid = c.table_oid
        LEFT JOIN policy_info p ON p.table_oid = c.table_oid
        LEFT JOIN trigger_info t ON t.table_oid = c.table_oid
        GROUP BY c.table_oid, c.table_name, fk.foreign_keys, i.indexes, p.policies, t.triggers
    )
    SELECT result || jsonb_build_object(
        'tables',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'name', table_name,
                    'columns', columns,
                    'foreign_keys', foreign_keys,
                    'indexes', indexes,
                    'policies', policies,
                    'triggers', triggers
                )
            ),
            '[]'::jsonb
        )
    )
    FROM table_info
    INTO result;

    -- Get all functions
    WITH function_info AS (
        SELECT 
            p.proname AS name,
            pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
        AND p.prokind = 'f'
    )
    SELECT result || jsonb_build_object(
        'functions',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'name', name,
                    'definition', definition
                )
            ),
            '[]'::jsonb
        )
    )
    FROM function_info
    INTO result;

    RETURN result;
END;
$$;


ALTER FUNCTION "public"."get_complete_schema"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_domain_from_url"("url" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $_$
DECLARE
    domain TEXT;
BEGIN
    IF url IS NULL OR url = '' THEN
        RETURN NULL;
    END IF;
    
    -- Extract domain part
    domain := regexp_replace(url, '^https?://(www\.)?', '');
    domain := regexp_replace(domain, '/.*$', '');
    domain := lower(domain);
    
    RETURN domain;
END;
$_$;


ALTER FUNCTION "public"."get_domain_from_url"("url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_email_config"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
    SELECT settings FROM public.email_config WHERE provider = 'customerio' ORDER BY updated_at DESC LIMIT 1;
$$;


ALTER FUNCTION "public"."get_email_config"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_users_with_profiles"() RETURNS TABLE("id" "uuid", "email" character varying, "phone" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "profile" "jsonb", "firm_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        au.id,
        au.email,
        au.phone,
        au.created_at,
        au.updated_at,
        to_jsonb(p.*) as profile,
        f.name as firm_name
    FROM auth.users au
    LEFT JOIN public.profiles p ON p.id = au.id
    LEFT JOIN public.firms f ON f.id = p.firm_id;
END;
$$;


ALTER FUNCTION "public"."get_users_with_profiles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_auth_user_created"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, email, status)
  VALUES (
    NEW.id,
    NEW.email,
    'AccountCreated_AwaitingProfile'
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_auth_user_created"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_application"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  notification_payload jsonb;
  edge_function_url text := 'https://xtavvykpwuxzwrqnsxva.supabase.co/functions/v1/notify-admin-new-application-slack';
  request_id bigint;
BEGIN
  -- Log new application
  INSERT INTO public.application_logs (applicant_id, action, details)
  VALUES (NEW.id, 'application_submitted', jsonb_build_object('first_name', NEW.first_name, 'last_name', NEW.last_name, 'work_email', NEW.work_email, 'firm_name', NEW.firm_name, 'job_title', NEW.job_title, 'date', NOW()));

  -- Prepare payload
  notification_payload := jsonb_build_object('applicant_id', NEW.id, 'first_name', NEW.first_name, 'last_name', NEW.last_name, 'work_email', NEW.work_email, 'firm_name', NEW.firm_name, 'job_title', NEW.job_title, 'linkedin_profile', NEW.linkedin_profile);

  RAISE NOTICE 'Attempting to send notification for applicant %', NEW.id;
  BEGIN
    request_id := net.http_post(
      url := edge_function_url,
      body := notification_payload,
      headers := jsonb_build_object('Content-Type', 'application/json') -- Corrected header format
    );
    RAISE NOTICE 'net.http_post request_id for applicant %: %', NEW.id, request_id;
  EXCEPTION
     WHEN OTHERS THEN
       RAISE WARNING 'Error during net.http_post call for applicant %: %', NEW.id, SQLERRM;
       INSERT INTO public.application_logs (applicant_id, action, details, created_at)
       VALUES (NEW.id, 'notification_failed', jsonb_build_object('error', SQLERRM), NOW());
       RETURN NEW;
  END;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_application"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_profile_related_records"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Insert records into related tables
    INSERT INTO public.profile_preferences (profile_id) VALUES (NEW.id);
    INSERT INTO public.profile_social_links (profile_id) VALUES (NEW.id);
    INSERT INTO public.profile_professional_details (profile_id) VALUES (NEW.id);
    INSERT INTO public.profile_images (profile_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_profile_related_records"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Insert into the correct public.profiles table
  INSERT INTO public.profiles (id)
  VALUES (new.id);
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_token_attempts"("token_param" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.applicants
  SET validation_attempts = validation_attempts + 1,
      updated_at = NOW() -- Also update the timestamp
  WHERE signup_token = token_param;
END;
$$;


ALTER FUNCTION "public"."increment_token_attempts"("token_param" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_stage_tag"("tag_id_to_check" "uuid") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.tags WHERE id = tag_id_to_check AND type = 'stage'
  );
$$;


ALTER FUNCTION "public"."is_stage_tag"("tag_id_to_check" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."maintenance_analyze_database"() RETURNS TABLE("table_name" "text", "was_analyzed" boolean)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    rec RECORD;
    was_analyzed BOOLEAN;
BEGIN
    FOR rec IN
        SELECT
            schemaname || '.' || relname AS table_full_name
        FROM pg_stat_user_tables
        WHERE
            -- Skip system tables
            schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY relname
    LOOP
        -- Analyze the table
        EXECUTE 'ANALYZE ' || rec.table_full_name;
        was_analyzed := true;
        
        -- Return the result
        table_name := rec.table_full_name;
        RETURN NEXT;
    END LOOP;
END;
$$;


ALTER FUNCTION "public"."maintenance_analyze_database"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."maintenance_archive_old_data"("older_than_days" integer DEFAULT 365) RETURNS TABLE("table_name" "text", "records_archived" integer)
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
    cutoff_date TIMESTAMP WITH TIME ZONE;
    rec RECORD;
    records_archived INTEGER;
BEGIN
    cutoff_date := NOW() - (older_than_days || ' days')::INTERVAL;
    
    -- Archive old audit logs
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_logs') THEN
        -- Create archive table if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_logs_archive') THEN
            EXECUTE 'CREATE TABLE audit_logs_archive (LIKE audit_logs INCLUDING ALL)';
        END IF;
        
        -- Move old records to archive
        EXECUTE 'WITH moved_rows AS (
            DELETE FROM audit_logs
            WHERE changed_at < $1
            RETURNING *
        )
        INSERT INTO audit_logs_archive
        SELECT * FROM moved_rows'
        USING cutoff_date;
        
        GET DIAGNOSTICS records_archived = ROW_COUNT;
        
        table_name := 'audit_logs';
        RETURN NEXT;
    END IF;
    
    -- Archive old notifications
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
        -- Create archive table if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications_archive') THEN
            EXECUTE 'CREATE TABLE notifications_archive (LIKE notifications INCLUDING ALL)';
        END IF;
        
        -- Move old records to archive
        EXECUTE 'WITH moved_rows AS (
            DELETE FROM notifications
            WHERE created_at < $1
            RETURNING *
        )
        INSERT INTO notifications_archive
        SELECT * FROM moved_rows'
        USING cutoff_date;
        
        GET DIAGNOSTICS records_archived = ROW_COUNT;
        
        table_name := 'notifications';
        RETURN NEXT;
    END IF;
    
    -- Archive old activity logs
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_activities') THEN
        -- Create archive table if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_activities_archive') THEN
            EXECUTE 'CREATE TABLE user_activities_archive (LIKE user_activities INCLUDING ALL)';
        END IF;
        
        -- Move old records to archive
        EXECUTE 'WITH moved_rows AS (
            DELETE FROM user_activities
            WHERE created_at < $1
            RETURNING *
        )
        INSERT INTO user_activities_archive
        SELECT * FROM moved_rows'
        USING cutoff_date;
        
        GET DIAGNOSTICS records_archived = ROW_COUNT;
        
        table_name := 'user_activities';
        RETURN NEXT;
    END IF;
END;
$_$;


ALTER FUNCTION "public"."maintenance_archive_old_data"("older_than_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."maintenance_reindex_fragmented_tables"("max_fragmentation_percent" integer DEFAULT 30) RETURNS TABLE("table_name" "text", "index_name" "text", "was_reindexed" boolean, "fragmentation_before" numeric, "fragmentation_after" numeric)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    rec RECORD;
    fragmentation_before NUMERIC;
    fragmentation_after NUMERIC;
    was_reindexed BOOLEAN;
BEGIN
    FOR rec IN
        SELECT
            schemaname || '.' || tablename AS table_full_name,
            indexrelname AS index_name,
            pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
            pg_stat_user_indexes.idx_scan AS index_scans,
            CASE
                WHEN indexrelname ~ 'pkey' THEN true
                ELSE false
            END AS is_primary_key,
            CASE
                WHEN indisunique THEN true
                ELSE false
            END AS is_unique,
            -- Estimate fragmentation
            CAST((
                CASE WHEN pg_stat_user_indexes.idx_scan = 0 THEN 0
                ELSE pg_stat_user_indexes.idx_tup_read::NUMERIC / pg_stat_user_indexes.idx_scan
                END
            ) AS NUMERIC) AS fragmentation
        FROM pg_stat_user_indexes
        JOIN pg_index ON pg_index.indexrelid = pg_stat_user_indexes.indexrelid
        WHERE
            -- Skip system tables
            schemaname NOT IN ('pg_catalog', 'information_schema') AND
            -- Skip rarely used indexes
            pg_stat_user_indexes.idx_scan > 10
        ORDER BY fragmentation DESC
    LOOP
        fragmentation_before := rec.fragmentation;
        was_reindexed := false;
        
        -- If fragmentation is higher than threshold, reindex
        IF rec.fragmentation > max_fragmentation_percent THEN
            EXECUTE 'REINDEX INDEX ' || rec.index_name;
            was_reindexed := true;
            
            -- Recalculate fragmentation
            EXECUTE 'ANALYZE ' || rec.table_full_name;
            
            -- Get updated fragmentation value
            SELECT
                CASE WHEN idx_scan = 0 THEN 0
                ELSE idx_tup_read::NUMERIC / idx_scan
                END
            INTO fragmentation_after
            FROM pg_stat_user_indexes
            WHERE indexrelname = rec.index_name
            LIMIT 1;
        ELSE
            fragmentation_after := fragmentation_before;
        END IF;
        
        -- Return the result
        table_name := rec.table_full_name;
        index_name := rec.index_name;
        RETURN NEXT;
    END LOOP;
END;
$$;


ALTER FUNCTION "public"."maintenance_reindex_fragmented_tables"("max_fragmentation_percent" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."maintenance_vacuum_tables"("max_dead_tuples" integer DEFAULT 10000) RETURNS TABLE("table_name" "text", "dead_tuples_before" integer, "dead_tuples_after" integer, "was_vacuumed" boolean)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    rec RECORD;
    dead_tuples_before INTEGER;
    dead_tuples_after INTEGER;
    was_vacuumed BOOLEAN;
BEGIN
    FOR rec IN
        SELECT
            schemaname || '.' || relname AS table_full_name,
            n_dead_tup AS dead_tuples
        FROM pg_stat_user_tables
        WHERE
            -- Skip system tables
            schemaname NOT IN ('pg_catalog', 'information_schema') AND
            -- Only consider tables with dead tuples
            n_dead_tup > max_dead_tuples
        ORDER BY n_dead_tup DESC
    LOOP
        dead_tuples_before := rec.dead_tuples;
        was_vacuumed := false;
        
        -- Vacuum the table
        EXECUTE 'VACUUM ' || rec.table_full_name;
        was_vacuumed := true;
        
        -- Refresh statistics
        EXECUTE 'ANALYZE ' || rec.table_full_name;
        
        -- Get updated dead tuples count
        SELECT n_dead_tup INTO dead_tuples_after
        FROM pg_stat_user_tables
        WHERE schemaname || '.' || relname = rec.table_full_name;
        
        -- Return the result
        table_name := rec.table_full_name;
        RETURN NEXT;
    END LOOP;
END;
$$;


ALTER FUNCTION "public"."maintenance_vacuum_tables"("max_dead_tuples" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mask_sensitive_data"("input_text" "text", "mask_type" "text" DEFAULT 'email'::"text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    IF input_text IS NULL THEN
        RETURN NULL;
    END IF;
    
    CASE mask_type
        WHEN 'email' THEN
            RETURN regexp_replace(
                input_text,
                '^(.{3})(.*)(@.*)$',
                '\1***\3'
            );
        WHEN 'phone' THEN
            RETURN regexp_replace(
                input_text,
                '^(.{3})(.*)(.{4})$',
                '\1-***-\3'
            );
        WHEN 'name' THEN
            RETURN substring(input_text FROM 1 FOR 1) || '****';
        ELSE
            RETURN '********';
    END CASE;
END;
$_$;


ALTER FUNCTION "public"."mask_sensitive_data"("input_text" "text", "mask_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."monitoring_detect_missing_indexes"() RETURNS TABLE("table_name" "text", "seq_scans" integer, "rows" integer, "recommendation" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        schemaname || '.' || relname AS table_name,
        seq_scan AS seq_scans,
        n_live_tup AS rows,
        CASE
            WHEN seq_scan > 1000 AND n_live_tup > 10000 THEN 'High priority: Table has many sequential scans with many rows'
            WHEN seq_scan > 100 AND n_live_tup > 10000 THEN 'Medium priority: Table has sequential scans with many rows'
            WHEN seq_scan > 10 AND n_live_tup > 1000 THEN 'Low priority: Consider adding indexes'
            ELSE 'No action needed'
        END AS recommendation
    FROM pg_stat_user_tables
    WHERE
        -- Skip system tables
        schemaname NOT IN ('pg_catalog', 'information_schema') AND
        -- Only tables with some activity
        seq_scan > 10
    ORDER BY
        seq_scan * n_live_tup DESC;
END;
$$;


ALTER FUNCTION "public"."monitoring_detect_missing_indexes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."monitoring_detect_unused_indexes"() RETURNS TABLE("table_name" "text", "index_name" "text", "index_size" "text", "recommendation" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        idx.schemaname || '.' || idx.tablename AS table_name,
        idx.indexrelname AS index_name,
        pg_size_pretty(pg_relation_size(idx.indexrelid)) AS index_size,
        CASE
            WHEN idx.idx_scan = 0 AND idx.indexrelname !~ '_pkey' AND idx.indexrelname !~ '_key' AND pg_relation_size(idx.indexrelid) > 10000000
            THEN 'High priority: Large unused index, consider dropping'
            WHEN idx.idx_scan = 0 AND idx.indexrelname !~ '_pkey' AND idx.indexrelname !~ '_key'
            THEN 'Medium priority: Unused index, consider dropping if not needed for constraints'
            WHEN idx.idx_scan < 10 AND idx.indexrelname !~ '_pkey' AND idx.indexrelname !~ '_key'
            THEN 'Low priority: Rarely used index'
            ELSE 'Keep index'
        END AS recommendation
    FROM pg_stat_user_indexes idx
    WHERE
        -- Skip system tables
        idx.schemaname NOT IN ('pg_catalog', 'information_schema') AND
        -- Skip primary and unique keys
        idx.indexrelname !~ '_pkey' AND
        idx.indexrelname !~ '_key'
    ORDER BY
        idx.idx_scan ASC,
        pg_relation_size(idx.indexrelid) DESC;
END;
$$;


ALTER FUNCTION "public"."monitoring_detect_unused_indexes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_entity_name"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $_$
DECLARE
    normalized TEXT;
BEGIN
    IF name IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Convert to lowercase
    normalized := lower(name);
    
    -- Remove common legal suffixes
    normalized := regexp_replace(normalized, ' (llc|inc|corp|corporation|ltd|limited|lp|llp|l\.p\.|l\.l\.p\.|gmbh|co|& co|and co|capital|ventures|venture|partners|management|advisors|group|holdings)$', '', 'g');
    
    -- Remove punctuation
    normalized := regexp_replace(normalized, '[^\w\s]', '', 'g');
    
    -- Normalize whitespace
    normalized := regexp_replace(normalized, '\s+', ' ', 'g');
    normalized := trim(normalized);
    
    RETURN normalized;
END;
$_$;


ALTER FUNCTION "public"."normalize_entity_name"("name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_self_connections"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.user_id = NEW.connected_user_id THEN
        RAISE EXCEPTION 'Cannot create a connection with yourself';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_self_connections"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_materialized_views"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_upcoming_events;
END;
$$;


ALTER FUNCTION "public"."refresh_materialized_views"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."run_scheduled_maintenance"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    vacuum_result INTEGER;
    reindex_result INTEGER;
    analyze_result INTEGER;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration INTERVAL;
BEGIN
    start_time := clock_timestamp();
    
    -- Vacuum tables with lots of dead tuples
    SELECT COUNT(*) INTO vacuum_result
    FROM maintenance_vacuum_tables(5000)
    WHERE was_vacuumed = true;
    
    -- Reindex fragmented indexes
    SELECT COUNT(*) INTO reindex_result
    FROM maintenance_reindex_fragmented_tables(20)
    WHERE was_reindexed = true;
    
    -- Analyze all tables to update statistics
    SELECT COUNT(*) INTO analyze_result
    FROM maintenance_analyze_database()
    WHERE was_analyzed = true;
    
    end_time := clock_timestamp();
    duration := end_time - start_time;
    
    -- Return a summary
    RETURN format(
        'Maintenance completed in %s minutes. Vacuumed %s tables, reindexed %s indexes, analyzed %s tables.',
        EXTRACT(EPOCH FROM duration) / 60,
        vacuum_result,
        reindex_result,
        analyze_result
    );
END;
$$;


ALTER FUNCTION "public"."run_scheduled_maintenance"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_event_format_from_location_type"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- If location_type is 'online' or 'online'::event_location_type_enum, set format_id to 'Virtual'
  IF (NEW.location_type = 'online' OR NEW.location_type = 'online'::event_location_type_enum) THEN
    NEW.format_id = (SELECT id FROM public.event_format_enum WHERE format_name = 'Virtual');
  -- If location_type is 'physical' or 'physical'::event_location_type_enum, set format_id to 'In-person'
  ELSIF (NEW.location_type = 'physical' OR NEW.location_type = 'physical'::event_location_type_enum) THEN
    NEW.format_id = (SELECT id FROM public.event_format_enum WHERE format_name = 'In-person');
  -- Mixed/hybrid events default to In-person for format
  ELSIF (NEW.location_type = 'hybrid' OR NEW.location_type = 'hybrid'::event_location_type_enum) THEN
    NEW.format_id = (SELECT id FROM public.event_format_enum WHERE format_name = 'In-person');
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_event_format_from_location_type"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."to_unix_timestamp"("ts" timestamp with time zone) RETURNS bigint
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
  RETURN EXTRACT(EPOCH FROM ts)::BIGINT;
END;
$$;


ALTER FUNCTION "public"."to_unix_timestamp"("ts" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_audit_profiles"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    -- Declare variables to hold data clearly
    v_record_id text;
    v_old_data jsonb := NULL;
    v_new_data jsonb := NULL;
    v_actor_id uuid := auth.uid(); -- Get actor ID once
    v_ip_address inet := NULL; -- Initialize as NULL
    v_user_agent text := NULL;
BEGIN
    -- Determine record ID (use text to match target column)
    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id::text;
        v_old_data := to_jsonb(OLD);
    ELSE
        v_record_id := NEW.id::text;
        v_new_data := to_jsonb(NEW);
        IF TG_OP = 'UPDATE' THEN
            v_old_data := to_jsonb(OLD);
        END IF;
    END IF;

    -- Attempt to get IP and User Agent safely
    BEGIN
       v_ip_address := current_setting('request.headers', true)::json->>'x-forwarded-for';
       v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
       -- Ignore errors if settings/headers are not available
       NULL;
    END;

    -- Explicitly list columns in INSERT statement, omitting the 'id' column
    INSERT INTO public.audit_logs (
        timestamp,
        actor_user_id,
        action,
        target_entity_type,
        target_entity_id,
        details, -- Include if you want to store old/new data JSON
        ip_address
        -- user_agent column was not found in the schema query, omitting
    ) VALUES (
        now(),                  -- timestamp
        v_actor_id,             -- actor_user_id (uuid)
        TG_OP,                  -- action (text)
        TG_TABLE_NAME::text,    -- target_entity_type (text)
        v_record_id,            -- target_entity_id (text)
        jsonb_build_object('old', v_old_data, 'new', v_new_data), -- details (jsonb) - Example
        v_ip_address            -- ip_address (inet)
        -- v_user_agent -- Omitted as column wasn't found
    );

    RETURN NULL; -- Function doesn't need to return OLD or NEW for AFTER trigger
END;
$$;


ALTER FUNCTION "public"."trg_audit_profiles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_addevent_calendar_subscriptions_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_addevent_calendar_subscriptions_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_addevent_calendars_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_addevent_calendars_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_customerio_config"("p_api_key" "text", "p_site_id" "text", "p_sender_name" "text" DEFAULT 'Your App'::"text", "p_sender_email" "text" DEFAULT 'noreply@yourdomain.com'::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_settings JSONB;
BEGIN
    -- Get existing settings
    SELECT settings INTO v_settings FROM public.email_config 
    WHERE provider = 'customerio' 
    ORDER BY updated_at DESC LIMIT 1;
    
    -- If settings exist, update them, otherwise use default
    IF v_settings IS NULL THEN
        v_settings := '{
            "enabled": true,
            "templates": {
                "password_reset": {
                    "template_id": "password_reset",
                    "subject": "Reset Your Password",
                    "sender_name": "Your App",
                    "sender_email": "noreply@yourdomain.com"
                }
            }
        }'::JSONB;
    END IF;
    
    -- Update with new values
    v_settings := jsonb_set(v_settings, '{api_key}', to_jsonb(p_api_key));
    v_settings := jsonb_set(v_settings, '{site_id}', to_jsonb(p_site_id));
    v_settings := jsonb_set(v_settings, '{templates,password_reset,sender_name}', to_jsonb(p_sender_name));
    v_settings := jsonb_set(v_settings, '{templates,password_reset,sender_email}', to_jsonb(p_sender_email));
    
    -- Insert or update the config
    INSERT INTO public.email_config (provider, settings)
    VALUES ('customerio', v_settings)
    ON CONFLICT (provider) DO UPDATE
    SET settings = v_settings, updated_at = now();
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
        RETURN FALSE;
END;
$$;


ALTER FUNCTION "public"."update_customerio_config"("p_api_key" "text", "p_site_id" "text", "p_sender_name" "text", "p_sender_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_event_attendance_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_event_attendance_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_modified_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_modified_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_timestamp"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_timestamp"() IS 'Trigger function to automatically update updated_at timestamp on row modification.';



CREATE OR REPLACE FUNCTION "public"."validate_event_dates"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if end date is after start date
    IF NEW.end_date <= NEW.start_date THEN
        RAISE EXCEPTION 'Event end date must be after start date';
    END IF;
    
    -- If publishing the event, ensure dates are in the future
    IF NEW.status = 'scheduled' AND NEW.start_date < NOW() THEN
        RAISE EXCEPTION 'Cannot schedule an event in the past';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_event_dates"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."access_levels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."access_levels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."addevent_calendar_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "addevent_calendar_id" "uuid" NOT NULL,
    "addevent_subscriber_id" "text",
    "subscription_status" "text" DEFAULT 'active'::"text" NOT NULL,
    "subscribed_datetime" timestamp with time zone DEFAULT "now"() NOT NULL,
    "unsubscribed_datetime" timestamp with time zone,
    "source" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."addevent_calendar_subscriptions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."addevent_calendar_subscriptions"."addevent_subscriber_id" IS 'External reference to subscriber ID in AddEvent system';



CREATE TABLE IF NOT EXISTS "public"."addevent_calendars" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "addevent_calendar_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "timezone" "text" NOT NULL,
    "addevent_subscription_page_url" "text",
    "addevent_calendar_widget_config" "jsonb",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."addevent_calendars" OWNER TO "postgres";


COMMENT ON COLUMN "public"."addevent_calendars"."addevent_calendar_id" IS 'External reference to calendar ID in AddEvent system';



CREATE TABLE IF NOT EXISTS "public"."addevent_integration" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "addevent_event_id" "text",
    "addevent_url" "text",
    "addevent_public_url" "text",
    "addevent_embed_code" "text",
    "addevent_add_to_calendar_config" "jsonb",
    "addevent_last_synced_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."addevent_integration" OWNER TO "postgres";


COMMENT ON TABLE "public"."addevent_integration" IS 'Stores AddEvent calendar integration data for community events';



CREATE TABLE IF NOT EXISTS "public"."addevent_interactions_log" (
    "id" bigint NOT NULL,
    "profile_id" "uuid",
    "community_event_id" "uuid",
    "addevent_calendar_id" "uuid",
    "interaction_type" "text" NOT NULL,
    "target_calendar_client" "text",
    "timestamp" timestamp with time zone DEFAULT "now"() NOT NULL,
    "source_page" "text",
    "ip_address" "inet",
    "user_agent" "text",
    "details" "jsonb"
);


ALTER TABLE "public"."addevent_interactions_log" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."addevent_interactions_log_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."addevent_interactions_log_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."addevent_interactions_log_id_seq" OWNED BY "public"."addevent_interactions_log"."id";



CREATE TABLE IF NOT EXISTS "public"."applicant_firms" (
    "applicant_id" "uuid" NOT NULL,
    "firm_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."applicant_firms" OWNER TO "postgres";


COMMENT ON TABLE "public"."applicant_firms" IS 'Junction table linking applicants to firms (Corrected firm_id type).';



CREATE TABLE IF NOT EXISTS "public"."applicants" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "first_name" "text",
    "last_name" "text",
    "email" "text" NOT NULL,
    "firm_name" "text",
    "firm_website_url" "text",
    "title" "text",
    "linkedin_url" "text",
    "status" "text" DEFAULT 'applicant'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "approval_date" timestamp with time zone,
    "signup_token" "text",
    "token_expiry" timestamp with time zone,
    "token_used" boolean DEFAULT false,
    "auth_user_id" "uuid",
    "validation_attempts" integer DEFAULT 0,
    "application_date" timestamp with time zone,
    "application_status" "text" NOT NULL,
    "admin_notes" "text",
    "admin_user_id" "uuid",
    "application_reviewed_at" timestamp with time zone,
    "work_email" "text",
    "firm_website" "text",
    "job_title" "text",
    "linkedin_profile" "text",
    "heard_from" "text",
    "eligibility_confirmed" boolean DEFAULT false
);


ALTER TABLE "public"."applicants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."application_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "applicant_id" "uuid",
    "action" "text" NOT NULL,
    "details" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."application_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."application_questions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "question_text" "text" NOT NULL,
    "question_type" "text" NOT NULL,
    "options" "jsonb",
    "required" boolean DEFAULT true,
    "sort_order" integer NOT NULL,
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."application_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."application_responses" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "applicant_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "response_text" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."application_responses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" bigint NOT NULL,
    "timestamp" timestamp with time zone DEFAULT "now"() NOT NULL,
    "actor_user_id" "uuid",
    "action" "text" NOT NULL,
    "target_entity_type" "text",
    "target_entity_id" "text",
    "details" "jsonb",
    "ip_address" "inet"
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


COMMENT ON COLUMN "public"."audit_logs"."actor_user_id" IS 'The user who performed the action, if applicable.';



COMMENT ON COLUMN "public"."audit_logs"."action" IS 'Description of the action (e.g., PROFILE_UPDATE, PAYMENT_SUCCEEDED, STATUS_CHANGE).';



COMMENT ON COLUMN "public"."audit_logs"."target_entity_type" IS 'e.g., profile, event, firm, membership, payment';



COMMENT ON COLUMN "public"."audit_logs"."target_entity_id" IS 'ID of the affected entity (can be UUID or other identifier)';



COMMENT ON COLUMN "public"."audit_logs"."details" IS 'Additional details about the action, e.g., changed fields, webhook payload snippet.';



ALTER TABLE "public"."audit_logs" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."audit_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."aum_ranges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "range_name" "text" NOT NULL,
    "min_value" numeric,
    "max_value" numeric,
    "display_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "aum_ranges_min_max_check" CHECK ((("min_value" IS NULL) OR ("max_value" IS NULL) OR ("min_value" <= "max_value")))
);


ALTER TABLE "public"."aum_ranges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."auth_settings_documentation" (
    "name" "text" NOT NULL,
    "description" "text",
    "value" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."auth_settings_documentation" OWNER TO "postgres";


COMMENT ON TABLE "public"."auth_settings_documentation" IS 'Documentation table for auth settings. Actual settings must be configured in Supabase Auth Dashboard.';



CREATE TABLE IF NOT EXISTS "public"."board_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."board_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."check_size_ranges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "range_name" "text" NOT NULL,
    "min_value" numeric,
    "max_value" numeric,
    "display_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "check_size_ranges_min_max_check" CHECK ((("min_value" IS NULL) OR ("max_value" IS NULL) OR ("min_value" <= "max_value")))
);


ALTER TABLE "public"."check_size_ranges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "start_datetime" timestamp with time zone NOT NULL,
    "end_datetime" timestamp with time zone NOT NULL,
    "virtual_event_url" "text",
    "location" "text",
    "status" "public"."event_status_enum" DEFAULT 'scheduled'::"public"."event_status_enum" NOT NULL,
    "created_by_user_id" "uuid",
    "max_attendees" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_format" "text",
    "sponsorship_status_id" "uuid",
    "logistics_status_id" "uuid",
    "timezone" "text",
    "organizer_name" "text",
    "organizer_email" "text",
    "addevent_event_id" "text",
    "addevent_url" "text",
    "addevent_add_to_calendar_config" "jsonb",
    "addevent_last_synced_at" timestamp with time zone,
    "all_day" boolean DEFAULT false NOT NULL,
    "event_url" "text",
    "addevent_embed_code" "text",
    "location_address" "text",
    "location_virtual_url" "text",
    "addevent_public_url" "text",
    CONSTRAINT "check_event_format" CHECK (("event_format" = ANY (ARRAY['Virtual'::"text", 'In Person'::"text"])))
);


ALTER TABLE "public"."community_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."community_events" IS 'Events organized for the community';



COMMENT ON COLUMN "public"."community_events"."start_datetime" IS 'Start date & time of the event';



COMMENT ON COLUMN "public"."community_events"."end_datetime" IS 'End date & time of the event';



COMMENT ON COLUMN "public"."community_events"."virtual_event_url" IS 'Virtual meeting link (Zoom, Google Meet, etc.)';



COMMENT ON COLUMN "public"."community_events"."location" IS 'Physical location address of the event.';



COMMENT ON COLUMN "public"."community_events"."status" IS 'e.g., scheduled, cancelled, completed. Consider ENUM.';



COMMENT ON COLUMN "public"."community_events"."updated_at" IS 'Consider using handle_updated_at() trigger.';



COMMENT ON COLUMN "public"."community_events"."addevent_event_id" IS 'External reference to event ID in AddEvent system - will be deprecated in favor of addevent_integration table';



COMMENT ON COLUMN "public"."community_events"."addevent_url" IS 'AddEvent-generated calendar sharing link';



COMMENT ON COLUMN "public"."community_events"."all_day" IS 'Whether this is an all-day event';



COMMENT ON COLUMN "public"."community_events"."event_url" IS 'External URL for the event page';



COMMENT ON COLUMN "public"."community_events"."addevent_embed_code" IS 'Code snippet for embedding AddEvent calendar on web';



CREATE OR REPLACE VIEW "public"."community_events_full" AS
 SELECT "ce"."id",
    "ce"."title",
    "ce"."description",
    "ce"."start_datetime",
    "ce"."end_datetime",
    "ce"."virtual_event_url",
    "ce"."location",
    "ce"."status",
    "ce"."created_by_user_id",
    "ce"."max_attendees",
    "ce"."created_at",
    "ce"."updated_at",
    "ce"."event_format",
    "ce"."sponsorship_status_id",
    "ce"."logistics_status_id",
    "ce"."timezone",
    "ce"."organizer_name",
    "ce"."organizer_email",
    "ce"."all_day",
    "ce"."event_url",
    "ce"."location_address",
    "ce"."location_virtual_url",
    "ae"."addevent_event_id",
    "ae"."addevent_url",
    "ae"."addevent_public_url",
    "ae"."addevent_embed_code",
    "ae"."addevent_add_to_calendar_config",
    "ae"."addevent_last_synced_at"
   FROM ("public"."community_events" "ce"
     LEFT JOIN "public"."addevent_integration" "ae" ON (("ce"."id" = "ae"."event_id")));


ALTER TABLE "public"."community_events_full" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."companies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "website" "text",
    "logo_url" "text",
    "description" "text",
    "linkedin_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_funding_date" "date",
    "investment_stage_id" "uuid"
);


ALTER TABLE "public"."companies" OWNER TO "postgres";


COMMENT ON TABLE "public"."companies" IS 'Target companies for investments and tracking';



COMMENT ON COLUMN "public"."companies"."name" IS 'Canonical name of the company.';



COMMENT ON COLUMN "public"."companies"."website" IS 'Official website URL of the company.';



COMMENT ON COLUMN "public"."companies"."logo_url" IS 'URL pointing to the company logo.';



COMMENT ON COLUMN "public"."companies"."description" IS 'Brief description of the company.';



COMMENT ON COLUMN "public"."companies"."linkedin_url" IS 'URL to the company''s LinkedIn page.';



COMMENT ON COLUMN "public"."companies"."last_funding_date" IS 'The date of the company''s most recent funding round.';



CREATE TABLE IF NOT EXISTS "public"."email_config" (
    "id" integer NOT NULL,
    "provider" character varying(255) NOT NULL,
    "settings" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."email_config" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."email_config_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."email_config_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."email_config_id_seq" OWNED BY "public"."email_config"."id";



CREATE TABLE IF NOT EXISTS "public"."employment_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "firm_id" "uuid" NOT NULL,
    "start_date" "date",
    "end_date" "date",
    "job_title" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."employment_history" OWNER TO "postgres";


COMMENT ON TABLE "public"."employment_history" IS 'Stores past employment records for members.';



COMMENT ON COLUMN "public"."employment_history"."profile_id" IS 'The member this employment record belongs to.';



COMMENT ON COLUMN "public"."employment_history"."firm_id" IS 'The firm the member previously worked at.';



COMMENT ON COLUMN "public"."employment_history"."start_date" IS 'Approximate start date at the past firm.';



COMMENT ON COLUMN "public"."employment_history"."end_date" IS 'Approximate end date at the past firm.';



COMMENT ON COLUMN "public"."employment_history"."job_title" IS 'Job title held at the past firm.';



CREATE TABLE IF NOT EXISTS "public"."event_attendance" (
    "profile_id" "uuid" NOT NULL,
    "event_id" "uuid" NOT NULL,
    "rsvp_status" "public"."event_rsvp_status_enum" NOT NULL,
    "attended" boolean DEFAULT false,
    "rsvped_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rsvp_datetime" timestamp with time zone DEFAULT "now"() NOT NULL,
    "addevent_attendee_id" "text",
    "source" "text",
    "custom_responses" "jsonb",
    "id" "uuid" DEFAULT "gen_random_uuid"()
);


ALTER TABLE "public"."event_attendance" OWNER TO "postgres";


COMMENT ON COLUMN "public"."event_attendance"."rsvp_status" IS 'e.g., invited, attending, maybe, not_attending. Consider ENUM.';



COMMENT ON COLUMN "public"."event_attendance"."updated_at" IS 'Consider using handle_updated_at() trigger.';



COMMENT ON COLUMN "public"."event_attendance"."addevent_attendee_id" IS 'External reference to attendee ID in AddEvent system';



CREATE TABLE IF NOT EXISTS "public"."event_format_enum" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "format_name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."event_format_enum" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_logistics_status_enum" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "status_name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."event_logistics_status_enum" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_sponsorship_status_enum" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "status_name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."event_sponsorship_status_enum" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_type_enum" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "type_name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."event_type_enum" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."external_user_identities" (
    "profile_id" "uuid" NOT NULL,
    "system_name" "text" NOT NULL,
    "external_user_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."external_user_identities" OWNER TO "postgres";


COMMENT ON TABLE "public"."external_user_identities" IS 'Stores user identifiers from various external systems linked to internal user profiles.';



COMMENT ON COLUMN "public"."external_user_identities"."profile_id" IS 'References the user profile in the public.profiles table.';



COMMENT ON COLUMN "public"."external_user_identities"."system_name" IS 'Identifier for the external system (e.g., zendesk, stripe).';



COMMENT ON COLUMN "public"."external_user_identities"."external_user_id" IS 'The user identifier within the specified external system.';



CREATE TABLE IF NOT EXISTS "public"."firm_investment_rounds" (
    "firm_id" "uuid" NOT NULL,
    "investment_round_id" "uuid" NOT NULL,
    "is_lead" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."firm_investment_rounds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."firm_lead_rounds" (
    "firm_id" "uuid" NOT NULL,
    "tag_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."firm_lead_rounds" OWNER TO "postgres";


COMMENT ON TABLE "public"."firm_lead_rounds" IS 'Links firms to the investment round tags they typically lead.';



CREATE TABLE IF NOT EXISTS "public"."firm_region_relationships" (
    "firm_id" "uuid" NOT NULL,
    "region_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."firm_region_relationships" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."firm_regions" (
    "firm_id" "uuid" NOT NULL,
    "tag_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."firm_regions" OWNER TO "postgres";


COMMENT ON TABLE "public"."firm_regions" IS 'Links firms to their geographical investment region tags.';



CREATE TABLE IF NOT EXISTS "public"."firm_sector_relationships" (
    "firm_id" "uuid" NOT NULL,
    "sector_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."firm_sector_relationships" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."firm_sectors" (
    "firm_id" "uuid" NOT NULL,
    "tag_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."firm_sectors" OWNER TO "postgres";


COMMENT ON TABLE "public"."firm_sectors" IS 'Links firms to their investment sector focus tags.';



CREATE TABLE IF NOT EXISTS "public"."firms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "website" "text",
    "logo_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "linkedin_url" "text",
    "current_fund_number" integer,
    "current_fund_size" "text",
    "firm_type_id" integer,
    "investment_region" "text",
    "sector_focus" "text",
    "funding_rounds_led" "text",
    "contact_email" "text"
);


ALTER TABLE "public"."firms" OWNER TO "postgres";


COMMENT ON TABLE "public"."firms" IS 'Investment firms and fund information';



COMMENT ON COLUMN "public"."firms"."website" IS 'Used to fetch the logo from logo.dev';



COMMENT ON COLUMN "public"."firms"."logo_url" IS 'URL pointing to the firm logo, potentially fetched from logo.dev or stored directly';



COMMENT ON COLUMN "public"."firms"."updated_at" IS 'Consider using a trigger function (e.g., handle_updated_at) to auto-update.';



COMMENT ON COLUMN "public"."firms"."current_fund_number" IS 'The number of the firm''s current fund (e.g., 5 for Fund V).';



COMMENT ON COLUMN "public"."firms"."current_fund_size" IS 'The size of the firm''s current fund (e.g., "$500M", "$1B+").';



COMMENT ON COLUMN "public"."firms"."firm_type_id" IS 'Reference to the type of VC firm.';



COMMENT ON COLUMN "public"."firms"."investment_region" IS 'Primary region(s) the firm invests in.';



COMMENT ON COLUMN "public"."firms"."sector_focus" IS 'Primary sector(s) the firm focuses on.';



COMMENT ON COLUMN "public"."firms"."funding_rounds_led" IS 'Typical funding rounds the firm leads.';



COMMENT ON COLUMN "public"."firms"."contact_email" IS 'Primary contact email for the firm.';



CREATE TABLE IF NOT EXISTS "public"."fortune_data_links" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "fortune_deal_id" "uuid" NOT NULL,
    "company_id" "uuid",
    "lead_investor_firm_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "other_investor_firm_ids" "uuid"[]
);


ALTER TABLE "public"."fortune_data_links" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fortune_deals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "startup_name" "text",
    "company_website" "text",
    "location" "text",
    "funding_amount_description" "text",
    "funding_amount" numeric,
    "funding_currency" "text",
    "round_type" "text",
    "lead_investor" "text",
    "other_investors" "text"[],
    "summary" "text",
    "article_publication_date" "date",
    "source_article_url" "text" NOT NULL,
    "source_article_title" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "extracted_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."fortune_deals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."frontier_interests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."frontier_interests" OWNER TO "postgres";


COMMENT ON TABLE "public"."frontier_interests" IS 'Stores specific frontier technology and research interests.';



COMMENT ON COLUMN "public"."frontier_interests"."name" IS 'The unique name of the frontier interest.';



COMMENT ON COLUMN "public"."frontier_interests"."description" IS 'A brief description of the frontier interest.';



CREATE TABLE IF NOT EXISTS "public"."icebreaker_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prompt" "text" NOT NULL,
    "description" "text",
    "display_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."icebreaker_options" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."integration_logs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "integration_type" "text" NOT NULL,
    "object_id" "text",
    "action" "text" NOT NULL,
    "success" boolean DEFAULT false NOT NULL,
    "response" "jsonb",
    "error_message" "text",
    "event_data" "jsonb",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."integration_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."integration_logs" IS 'Logs interactions with external services like Customer.io, HubSpot, etc.';



COMMENT ON COLUMN "public"."integration_logs"."integration_type" IS 'Name of the integrated service (e.g., customer_io)';



COMMENT ON COLUMN "public"."integration_logs"."object_id" IS 'Identifier of the primary object involved (e.g., applicant ID, profile ID)';



COMMENT ON COLUMN "public"."integration_logs"."action" IS 'Specific action performed (e.g., sync_applicant_approved)';



COMMENT ON COLUMN "public"."integration_logs"."response" IS 'API response payload from the external service';



COMMENT ON COLUMN "public"."integration_logs"."error_message" IS 'Details if the action was not successful';



COMMENT ON COLUMN "public"."integration_logs"."event_data" IS 'Payload data associated with tracked events, if applicable.';



ALTER TABLE "public"."integration_logs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."integration_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."interest_communities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."interest_communities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intro_cadence_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."intro_cadence_options" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intro_preferences_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "preference_name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."intro_preferences_options" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."investment_rounds" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "display_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."investment_rounds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."investment_stages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "display_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."investment_stages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."investments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "investor_profile_id" "uuid",
    "company_id" "uuid" NOT NULL,
    "investing_firm_id" "uuid" NOT NULL,
    "investment_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "investment_round_id" "uuid",
    "investment_stage_id" "uuid",
    "is_lead" boolean DEFAULT false
);


ALTER TABLE "public"."investments" OWNER TO "postgres";


COMMENT ON TABLE "public"."investments" IS 'Records individual investments made by members.';



COMMENT ON COLUMN "public"."investments"."investor_profile_id" IS 'The profile ID of the investor.';



COMMENT ON COLUMN "public"."investments"."company_id" IS 'The company that received the investment.';



COMMENT ON COLUMN "public"."investments"."investing_firm_id" IS 'The firm the investor represented at the time of this specific investment.';



COMMENT ON COLUMN "public"."investments"."investment_date" IS 'Approximate date of the investment.';



CREATE TABLE IF NOT EXISTS "public"."investor_name_mappings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "investor_name" "text" NOT NULL,
    "normalized_name" "text" NOT NULL,
    "firm_id" "uuid" NOT NULL,
    "confidence" real NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."investor_name_mappings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."job_locations" (
    "id" integer NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "public"."job_locations" OWNER TO "postgres";


COMMENT ON TABLE "public"."job_locations" IS 'Lookup table for job locations.';



CREATE SEQUENCE IF NOT EXISTS "public"."job_locations_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."job_locations_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."job_locations_id_seq" OWNED BY "public"."job_locations"."id";



CREATE TABLE IF NOT EXISTS "public"."job_postings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "job_name" "text" NOT NULL,
    "job_description" "text",
    "job_requirements" "text",
    "job_posting_url" "text",
    "email_submission_address" "text",
    "job_location_id" integer,
    "firm_id" "uuid" NOT NULL,
    "attachments" "text"[],
    "external_job_posting_id" "text",
    "posted_by_profile_id" "uuid",
    "original_created_at" "date",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "job_title_id" "uuid"
);


ALTER TABLE "public"."job_postings" OWNER TO "postgres";


COMMENT ON TABLE "public"."job_postings" IS 'Stores information about job opportunities.';



COMMENT ON COLUMN "public"."job_postings"."job_name" IS 'The title or name of the job position.';



COMMENT ON COLUMN "public"."job_postings"."job_description" IS 'Detailed description of the job role.';



COMMENT ON COLUMN "public"."job_postings"."job_requirements" IS 'Specific requirements for the job.';



COMMENT ON COLUMN "public"."job_postings"."job_posting_url" IS 'Direct URL to the external job posting.';



COMMENT ON COLUMN "public"."job_postings"."email_submission_address" IS 'Email address for submitting applications.';



COMMENT ON COLUMN "public"."job_postings"."job_location_id" IS 'Reference to the standardized job location.';



COMMENT ON COLUMN "public"."job_postings"."firm_id" IS 'The firm offering the job. Details like website/logo are linked via this ID.';



COMMENT ON COLUMN "public"."job_postings"."attachments" IS 'Array of URLs pointing to attachment files (e.g., in Supabase Storage).';



COMMENT ON COLUMN "public"."job_postings"."external_job_posting_id" IS 'Optional unique identifier from an external job board system.';



COMMENT ON COLUMN "public"."job_postings"."posted_by_profile_id" IS 'The profile ID of the user who submitted this job posting.';



COMMENT ON COLUMN "public"."job_postings"."original_created_at" IS 'The date the job was originally posted or created (from source).';



CREATE TABLE IF NOT EXISTS "public"."job_titles" (
    "name" "text" NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."job_titles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lifecycle_stages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "display_order" integer
);


ALTER TABLE "public"."lifecycle_stages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."linear_issues" (
    "id" "text" NOT NULL,
    "title" "text",
    "status" "text",
    "priority" "text",
    "assignee_id" "text",
    "reporter_id" "text",
    "linear_created_at" timestamp with time zone,
    "linear_updated_at" timestamp with time zone,
    "synced_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."linear_issues" OWNER TO "postgres";


COMMENT ON TABLE "public"."linear_issues" IS 'Stores issue data synced from Linear.';



COMMENT ON COLUMN "public"."linear_issues"."id" IS 'Primary key: The unique ID of the issue in Linear.';



CREATE TABLE IF NOT EXISTS "public"."member_locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "public"."member_locations" OWNER TO "postgres";


COMMENT ON TABLE "public"."member_locations" IS 'This is a duplicate of job_locations';



CREATE TABLE IF NOT EXISTS "public"."member_types" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."member_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."memberships" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "stripe_subscription_id" "text",
    "plan_id" "text" NOT NULL,
    "status" "public"."membership_status_enum" DEFAULT 'Active'::"public"."membership_status_enum" NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cancel_at_period_end" boolean DEFAULT false
);


ALTER TABLE "public"."memberships" OWNER TO "postgres";


COMMENT ON COLUMN "public"."memberships"."stripe_subscription_id" IS 'External reference to subscription ID in Stripe payment system';



COMMENT ON COLUMN "public"."memberships"."plan_id" IS 'Identifier for the membership plan (e.g., Stripe Price ID).';



COMMENT ON COLUMN "public"."memberships"."status" IS 'Current status of the membership (PSE03). Needs RLS policies (PSE08).';



COMMENT ON COLUMN "public"."memberships"."start_date" IS 'Date the current membership period started.';



COMMENT ON COLUMN "public"."memberships"."end_date" IS 'Date the current membership period ends or ended.';



COMMENT ON COLUMN "public"."memberships"."updated_at" IS 'Implement handle_updated_at() trigger function (PSE07).';



COMMENT ON COLUMN "public"."memberships"."cancel_at_period_end" IS 'True if the subscription is set to cancel at the end of the current billing period.';



CREATE OR REPLACE VIEW "public"."monitoring_slow_queries" AS
 SELECT "pg_stat_statements"."calls",
    "pg_stat_statements"."total_exec_time",
    "pg_stat_statements"."rows",
    "pg_stat_statements"."mean_exec_time",
    "pg_stat_statements"."max_exec_time",
    "pg_stat_statements"."query"
   FROM "extensions"."pg_stat_statements"
  ORDER BY "pg_stat_statements"."mean_exec_time" DESC
 LIMIT 100;


ALTER TABLE "public"."monitoring_slow_queries" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."monitoring_table_access" AS
 SELECT ((("pg_stat_user_tables"."schemaname")::"text" || '.'::"text") || ("pg_stat_user_tables"."relname")::"text") AS "table_name",
    "pg_stat_user_tables"."seq_scan" AS "sequential_scans",
    "pg_stat_user_tables"."seq_tup_read" AS "sequential_tuples_read",
    "pg_stat_user_tables"."idx_scan" AS "index_scans",
    "pg_stat_user_tables"."idx_tup_fetch" AS "index_tuples_fetched",
    "pg_stat_user_tables"."n_tup_ins" AS "tuples_inserted",
    "pg_stat_user_tables"."n_tup_upd" AS "tuples_updated",
    "pg_stat_user_tables"."n_tup_del" AS "tuples_deleted",
    "pg_stat_user_tables"."n_live_tup" AS "live_tuples",
    "pg_stat_user_tables"."n_dead_tup" AS "dead_tuples"
   FROM "pg_stat_user_tables"
  ORDER BY "pg_stat_user_tables"."seq_scan" DESC;


ALTER TABLE "public"."monitoring_table_access" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."monitoring_table_bloat" AS
 SELECT "pg_stat_user_tables"."schemaname",
    "pg_stat_user_tables"."relname" AS "table_name",
    "pg_stat_user_tables"."n_live_tup" AS "row_count",
    "pg_stat_user_tables"."n_dead_tup" AS "dead_tuples",
    "pg_size_pretty"("pg_relation_size"((((("pg_stat_user_tables"."schemaname")::"text" || '.'::"text") || ("pg_stat_user_tables"."relname")::"text"))::"regclass")) AS "table_size",
        CASE
            WHEN ("pg_stat_user_tables"."n_live_tup" > 0) THEN "round"(((("pg_stat_user_tables"."n_dead_tup")::numeric / ("pg_stat_user_tables"."n_live_tup")::numeric) * (100)::numeric), 2)
            ELSE (0)::numeric
        END AS "bloat_percentage"
   FROM "pg_stat_user_tables"
  ORDER BY
        CASE
            WHEN ("pg_stat_user_tables"."n_live_tup" > 0) THEN "round"(((("pg_stat_user_tables"."n_dead_tup")::numeric / ("pg_stat_user_tables"."n_live_tup")::numeric) * (100)::numeric), 2)
            ELSE (0)::numeric
        END DESC;


ALTER TABLE "public"."monitoring_table_bloat" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."network_connections" (
    "user_id_1" "uuid" NOT NULL,
    "user_id_2" "uuid" NOT NULL,
    "status" "public"."network_connection_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "connection_type" "text" DEFAULT 'interest_list'::"text" NOT NULL,
    CONSTRAINT "check_connection_type" CHECK (("connection_type" = ANY (ARRAY['interest_list'::"text", 'network_list'::"text"]))),
    CONSTRAINT "network_connections_check" CHECK (("user_id_1" <> "user_id_2"))
);


ALTER TABLE "public"."network_connections" OWNER TO "postgres";


COMMENT ON TABLE "public"."network_connections" IS 'Tracks user-to-user connection status (Interested/Starred, Connected).';



CREATE TABLE IF NOT EXISTS "public"."onboarding_progress" (
    "user_id" "uuid" NOT NULL,
    "step1_completed" boolean DEFAULT false,
    "step2_completed" boolean DEFAULT false,
    "step3_completed" boolean DEFAULT false,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."onboarding_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "stripe_payment_intent_id" "text" NOT NULL,
    "stripe_charge_id" "text",
    "amount" integer NOT NULL,
    "currency" "text" NOT NULL,
    "status" "public"."payment_status_enum" NOT NULL,
    "payment_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "membership_id" "uuid"
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."payments"."stripe_payment_intent_id" IS 'External reference to payment intent ID in Stripe payment system';



COMMENT ON COLUMN "public"."payments"."stripe_charge_id" IS 'External reference to charge ID in Stripe payment system';



COMMENT ON COLUMN "public"."payments"."amount" IS 'Amount in smallest currency unit (e.g., cents).';



COMMENT ON COLUMN "public"."payments"."currency" IS '3-letter ISO currency code.';



COMMENT ON COLUMN "public"."payments"."status" IS 'Status from Stripe (e.g., succeeded, pending, failed).';



COMMENT ON COLUMN "public"."payments"."payment_date" IS 'Timestamp when the payment was successfully processed by Stripe (from webhook).';



COMMENT ON COLUMN "public"."payments"."updated_at" IS 'Implement handle_updated_at() trigger function (PSE07). Needs RLS policies (PSE08).';



COMMENT ON COLUMN "public"."payments"."membership_id" IS 'Reference to the specific membership this payment relates to (especially for renewals).';



CREATE TABLE IF NOT EXISTS "public"."profile_community_sectors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "sector_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_community_sectors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_company_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "company_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "has_board_seat" boolean DEFAULT false NOT NULL,
    "is_director" boolean DEFAULT false NOT NULL,
    "board_role_id" "uuid"
);


ALTER TABLE "public"."profile_company_roles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_company_roles" IS 'Links profiles to companies in their track record and specifies their board role.';



COMMENT ON COLUMN "public"."profile_company_roles"."profile_id" IS 'The member associated with the company.';



COMMENT ON COLUMN "public"."profile_company_roles"."company_id" IS 'The company associated with the member.';



CREATE TABLE IF NOT EXISTS "public"."profile_frontier_interests" (
    "profile_id" "uuid" NOT NULL,
    "interest_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_frontier_interests" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_frontier_interests" IS 'Join table linking user profiles to their selected frontier interests.';



COMMENT ON COLUMN "public"."profile_frontier_interests"."profile_id" IS 'Foreign key referencing the user profile.';



COMMENT ON COLUMN "public"."profile_frontier_interests"."interest_id" IS 'Foreign key referencing the frontier interest.';



CREATE TABLE IF NOT EXISTS "public"."profile_images" (
    "profile_id" "uuid" NOT NULL,
    "profile_headshot_url" "text",
    "profile_image_url" "text",
    "background_image_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_interest_communities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "interest_community_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_interest_communities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_intro_sectors" (
    "profile_id" "uuid" NOT NULL,
    "sector_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_intro_sectors" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_intro_sectors" IS 'Join table connecting profiles to sectors they are interested in for intros.';



CREATE TABLE IF NOT EXISTS "public"."profile_intro_stages" (
    "profile_id" "uuid" NOT NULL,
    "investment_stage_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_intro_stages" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_intro_stages" IS 'Join table connecting profiles to investment stages they are interested in for intros.';



CREATE TABLE IF NOT EXISTS "public"."profile_job_location_preferences" (
    "profile_id" "uuid" NOT NULL,
    "job_location_id" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_job_location_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_job_location_preferences" IS 'Links profiles to their preferred job locations.';



CREATE TABLE IF NOT EXISTS "public"."profile_job_title_preferences" (
    "profile_id" "uuid" NOT NULL,
    "job_title_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_job_title_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_job_title_preferences" IS 'Links profiles to their preferred job titles.';



CREATE TABLE IF NOT EXISTS "public"."profile_match_sectors" (
    "profile_id" "uuid" NOT NULL,
    "sector_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_match_sectors" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_match_sectors" IS 'Join table connecting profiles to sectors for matching criteria.';



CREATE TABLE IF NOT EXISTS "public"."profile_match_stages" (
    "profile_id" "uuid" NOT NULL,
    "investment_stage_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_match_stages" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_match_stages" IS 'Join table connecting profiles to investment stages for matching criteria.';



CREATE TABLE IF NOT EXISTS "public"."profile_preferences" (
    "profile_id" "uuid" NOT NULL,
    "intro_opt_in" boolean DEFAULT false NOT NULL,
    "intro_prefs_cadence" "text",
    "intro_prefs_days" "text"[],
    "job_alert_opt_in" boolean DEFAULT false NOT NULL,
    "job_pref_titles" "text",
    "job_pref_locations" "text",
    "job_pref_sectors" "text",
    "job_pref_stages" "text",
    "event_pref_industry" boolean DEFAULT false NOT NULL,
    "event_pref_thematic" boolean DEFAULT false NOT NULL,
    "event_pref_interest_athletic" boolean DEFAULT false NOT NULL,
    "min_firm_peers_to_connect" integer,
    "notification_settings" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "preferences" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_preferences" IS 'User preferences for various platform features';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "first_name" "text",
    "last_name" "text",
    "work_email" "text",
    "firm_id" "uuid",
    "status" "public"."user_status_enum" DEFAULT 'AccountCreated_AwaitingProfile'::"public"."user_status_enum" NOT NULL,
    "hubspot_contact_id" "text",
    "stripe_customer_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone_number" "text",
    "onboarding_complete" boolean DEFAULT false,
    "x_lurl" "text",
    "blog_url" "text",
    "intro_cadence_id" "uuid",
    "is_leader" boolean DEFAULT false NOT NULL,
    "lifecycle_stage_id" "uuid",
    "intro_preference_id" "uuid",
    "intro_opt_in" boolean DEFAULT false NOT NULL,
    "intro_prefs_days" "text"[],
    "job_alert_opt_in" boolean DEFAULT false NOT NULL,
    "job_pref_titles" "text",
    "job_pref_locations" "text",
    "job_pref_sectors" "text",
    "job_pref_stages" "text",
    "event_pref_industry" boolean DEFAULT false NOT NULL,
    "event_pref_thematic" boolean DEFAULT false NOT NULL,
    "event_pref_interest_athletic" boolean DEFAULT false NOT NULL,
    "min_firm_peers_to_connect" integer,
    "preferences" "jsonb",
    "linkedin_profile" "text",
    "twitter_handle" "text",
    "github_username" "text",
    "other_links" "jsonb",
    "social_links" "jsonb",
    "job_title_id" "uuid",
    "aum_range_id" "uuid",
    "check_size_range_id" "uuid",
    "investment_sector" "text",
    "geo_focus" "text",
    "undergrad_university" "text",
    "grad_university" "text",
    "profile_bio" "text",
    "icebreaker_1_option_id" "uuid",
    "icebreaker_1_response" "text",
    "icebreaker_2_option_id" "uuid",
    "icebreaker_2_response" "text",
    "icebreaker_3_option_id" "uuid",
    "icebreaker_3_response" "text",
    "avatar_url" "text",
    "profile_image_url" "text",
    "background_image_url" "text",
    "opt_in_considering_mba" boolean,
    "opt_in_mba_mentorship" boolean,
    "undergrad_graduation_year" "text",
    "undergrad_major" "text",
    "grad_graduation_year" "text",
    "grad_major" "text",
    "areas_of_expertise" "text",
    "topics_to_learn" "text",
    "topics_to_trade" "text",
    "slack_email" "text",
    "opt_in_angel_syndicate" boolean,
    "has_leader_dashboard_access" boolean,
    "network_with_alumni_pref" boolean,
    "billing_email" "text",
    "member_since_date" "date",
    "has_mba" boolean,
    "is_mentor" boolean,
    "opt_in_small_dinners" boolean,
    "dinner_prefs_cadence" "text",
    "interest_bleeding_edge" "text",
    "event_suggestions" "text",
    "opt_in_service_provider_intro" boolean,
    "target_firms_to_meet" "text",
    "target_investor_titles_to_meet" "text",
    "is_leadership_team" boolean,
    "growsurf_share_url" "text",
    "how_heard_id" "uuid",
    "location_id" "uuid",
    "access_level_id" "uuid",
    "member_type_id" "uuid"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles" IS 'Central user profile information for platform members';



COMMENT ON COLUMN "public"."profiles"."work_email" IS 'Should match auth.users.email';



COMMENT ON COLUMN "public"."profiles"."status" IS 'Tracks the user lifecycle stage (PSE01). Initial default might depend on when record is created relative to approval.';



COMMENT ON COLUMN "public"."profiles"."hubspot_contact_id" IS 'External reference to contact ID in HubSpot CRM';



COMMENT ON COLUMN "public"."profiles"."stripe_customer_id" IS 'External reference to customer ID in Stripe payment system';



COMMENT ON COLUMN "public"."profiles"."updated_at" IS 'Implement handle_updated_at() trigger function (PSE07). RLS policies needed based on status enum (PSE08).';



COMMENT ON COLUMN "public"."profiles"."onboarding_complete" IS 'Flag indicating if user has completed the initial onboarding steps.';



CREATE TABLE IF NOT EXISTS "public"."sectors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "parent_id" "uuid",
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."sectors" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."profile_preferences_view" AS
 SELECT "p"."id" AS "profile_id",
    (("p"."first_name" || ' '::"text") || "p"."last_name") AS "full_name",
    ( SELECT "json_agg"("s"."name") AS "json_agg"
           FROM ("public"."profile_intro_sectors" "pis"
             JOIN "public"."sectors" "s" ON (("pis"."sector_id" = "s"."id")))
          WHERE ("pis"."profile_id" = "p"."id")) AS "intro_sectors",
    ( SELECT "json_agg"("ist"."name") AS "json_agg"
           FROM ("public"."profile_intro_stages" "pist"
             JOIN "public"."investment_stages" "ist" ON (("pist"."investment_stage_id" = "ist"."id")))
          WHERE ("pist"."profile_id" = "p"."id")) AS "intro_stages",
    ( SELECT "json_agg"("s"."name") AS "json_agg"
           FROM ("public"."profile_match_sectors" "pms"
             JOIN "public"."sectors" "s" ON (("pms"."sector_id" = "s"."id")))
          WHERE ("pms"."profile_id" = "p"."id")) AS "match_sectors",
    ( SELECT "json_agg"("ist"."name") AS "json_agg"
           FROM ("public"."profile_match_stages" "pmst"
             JOIN "public"."investment_stages" "ist" ON (("pmst"."investment_stage_id" = "ist"."id")))
          WHERE ("pmst"."profile_id" = "p"."id")) AS "match_stages"
   FROM "public"."profiles" "p";


ALTER TABLE "public"."profile_preferences_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_professional_details" (
    "profile_id" "uuid" NOT NULL,
    "job_title" "text",
    "aum" "text",
    "check_size" "text",
    "investment_sector" "text",
    "investment_stage" "text",
    "geo_focus" "text",
    "leads_rounds" boolean,
    "undergrad_university" "text",
    "grad_university" "text",
    "profile_bio" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_professional_details" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_professional_details" IS 'Professional information for profiles';



CREATE TABLE IF NOT EXISTS "public"."profile_sector_focuses" (
    "profile_id" "uuid" NOT NULL,
    "sector_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_sector_focuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_sector_preferences" (
    "profile_id" "uuid" NOT NULL,
    "sector_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_sector_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_sector_preferences" IS 'Links profiles to their preferred industry sectors.';



CREATE TABLE IF NOT EXISTS "public"."profile_social_links" (
    "profile_id" "uuid" NOT NULL,
    "linkedin_profile" "text",
    "twitter_handle" "text",
    "github_username" "text",
    "personal_website" "text",
    "other_links" "jsonb",
    "social_links" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_social_links" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_social_links" IS 'Social media links for user profiles';



CREATE TABLE IF NOT EXISTS "public"."profile_stage_focuses" (
    "profile_id" "uuid" NOT NULL,
    "investment_stage_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_stage_focuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_stage_preferences" (
    "profile_id" "uuid" NOT NULL,
    "investment_stage_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_stage_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."profile_stage_preferences" IS 'Links profiles to their preferred investment stages.';



CREATE TABLE IF NOT EXISTS "public"."profile_thematic_interests" (
    "profile_id" "uuid" NOT NULL,
    "thematic_area_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profile_thematic_interests" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."profile_track_record_companies" AS
 SELECT DISTINCT "inv"."investor_profile_id" AS "profile_id",
    "inv"."company_id",
    "c"."name" AS "company_name"
   FROM ("public"."investments" "inv"
     JOIN "public"."companies" "c" ON (("inv"."company_id" = "c"."id")));


ALTER TABLE "public"."profile_track_record_companies" OWNER TO "postgres";


COMMENT ON VIEW "public"."profile_track_record_companies" IS 'Represents the cumulative set of unique companies associated with a profile''s investment history (their track record).';



CREATE TABLE IF NOT EXISTS "public"."referral_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."referral_options" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."regions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "parent_id" "uuid",
    "code" "text",
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."regions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."scrape_tracking" (
    "id" integer NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "entity_type" "text" NOT NULL,
    "updated_fields" "jsonb",
    "scraped_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "source" "text",
    "scrape_method" "text",
    "status" "text",
    "error_message" "text",
    "metadata" "jsonb"
);


ALTER TABLE "public"."scrape_tracking" OWNER TO "postgres";


COMMENT ON TABLE "public"."scrape_tracking" IS 'Tracks web scraping activities performed against various entity types';



COMMENT ON COLUMN "public"."scrape_tracking"."entity_id" IS 'UUID reference to the entity being scraped (company, profile, etc.)';



COMMENT ON COLUMN "public"."scrape_tracking"."entity_type" IS 'Type of entity being scraped (determines which table entity_id references)';



CREATE SEQUENCE IF NOT EXISTS "public"."scrape_tracking_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."scrape_tracking_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."scrape_tracking_id_seq" OWNED BY "public"."scrape_tracking"."id";



CREATE TABLE IF NOT EXISTS "public"."screening_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "work_email" "text" NOT NULL,
    "firm_name" "text" NOT NULL,
    "firm_website" "text" NOT NULL,
    "linkedin_profile" "text" NOT NULL,
    "status" "public"."screening_status_enum" DEFAULT 'submitted'::"public"."screening_status_enum" NOT NULL,
    "submitted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reviewed_at" timestamp with time zone,
    "reviewer_notes" "text",
    "synced_to_profile_at" timestamp with time zone,
    "job_title_id" "uuid",
    "how_heard_id" "uuid"
);

ALTER TABLE ONLY "public"."screening_applications" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."screening_applications" OWNER TO "postgres";


COMMENT ON COLUMN "public"."screening_applications"."status" IS 'e.g., submitted, approved, rejected. Tracks the application review itself. Consider ENUM.';



COMMENT ON COLUMN "public"."screening_applications"."synced_to_profile_at" IS 'Timestamp indicating when the data was transferred to the profiles table upon approval.';



CREATE TABLE IF NOT EXISTS "public"."service_provider_categories" (
    "id" integer NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "public"."service_provider_categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."service_provider_categories" IS 'Lookup table for service provider categories.';



CREATE SEQUENCE IF NOT EXISTS "public"."service_provider_categories_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."service_provider_categories_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."service_provider_categories_id_seq" OWNED BY "public"."service_provider_categories"."id";



CREATE TABLE IF NOT EXISTS "public"."service_provider_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "service_provider_id" "uuid" NOT NULL,
    "reviewer_profile_id" "uuid" NOT NULL,
    "review_text" "text" NOT NULL,
    "attachments" "text"[],
    "external_review_id" "text",
    "review_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "service_provider_reviews_review_text_check" CHECK (("char_length"("review_text") > 0))
);


ALTER TABLE "public"."service_provider_reviews" OWNER TO "postgres";


COMMENT ON TABLE "public"."service_provider_reviews" IS 'Stores user reviews for service providers.';



COMMENT ON COLUMN "public"."service_provider_reviews"."service_provider_id" IS 'The service provider being reviewed.';



COMMENT ON COLUMN "public"."service_provider_reviews"."reviewer_profile_id" IS 'The profile of the user who wrote the review.';



COMMENT ON COLUMN "public"."service_provider_reviews"."review_text" IS 'The main content of the review.';



COMMENT ON COLUMN "public"."service_provider_reviews"."attachments" IS 'Array of URLs pointing to attachment files related to the review.';



COMMENT ON COLUMN "public"."service_provider_reviews"."external_review_id" IS 'Optional unique identifier from an external review system.';



COMMENT ON COLUMN "public"."service_provider_reviews"."review_date" IS 'The date the review was submitted.';



CREATE TABLE IF NOT EXISTS "public"."service_providers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "short_description" "text",
    "about_full_desc" "text",
    "website_url" "text",
    "logo_url" "text",
    "external_provider_id" "text",
    "contact_name" "text",
    "contact_email" "text",
    "category_id" integer,
    "created_by_profile_id" "uuid",
    "original_created_at" "date",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "delete_tag_ref" "bytea"[]
);


ALTER TABLE "public"."service_providers" OWNER TO "postgres";


COMMENT ON TABLE "public"."service_providers" IS 'Stores information about approved service providers for the community.';



COMMENT ON COLUMN "public"."service_providers"."name" IS 'Name of the service provider company.';



COMMENT ON COLUMN "public"."service_providers"."short_description" IS 'Short description blurb.';



COMMENT ON COLUMN "public"."service_providers"."about_full_desc" IS 'Full description blurb.';



COMMENT ON COLUMN "public"."service_providers"."website_url" IS 'URL to the provider''s website.';



COMMENT ON COLUMN "public"."service_providers"."logo_url" IS 'URL to the provider''s logo.';



COMMENT ON COLUMN "public"."service_providers"."external_provider_id" IS 'Optional unique identifier from an external system or the provider themselves.';



COMMENT ON COLUMN "public"."service_providers"."contact_name" IS 'Name of a contact person at the provider.';



COMMENT ON COLUMN "public"."service_providers"."contact_email" IS 'Email address of a contact person at the provider.';



COMMENT ON COLUMN "public"."service_providers"."category_id" IS 'Reference to the primary category of service offered.';



COMMENT ON COLUMN "public"."service_providers"."created_by_profile_id" IS 'The profile ID of the user who initially added or suggested this provider.';



COMMENT ON COLUMN "public"."service_providers"."original_created_at" IS 'The date the provider listing was originally created or added.';



CREATE TABLE IF NOT EXISTS "public"."signup_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "token" "text" NOT NULL,
    "email" "text" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "used_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."signup_tokens" OWNER TO "postgres";


COMMENT ON TABLE "public"."signup_tokens" IS 'Stores single-use tokens for verifying approved signups.';



COMMENT ON COLUMN "public"."signup_tokens"."token" IS 'The unique, secure token sent to the user.';



COMMENT ON COLUMN "public"."signup_tokens"."email" IS 'The email address of the user this token belongs to.';



COMMENT ON COLUMN "public"."signup_tokens"."expires_at" IS 'The timestamp when this token is no longer valid.';



COMMENT ON COLUMN "public"."signup_tokens"."used_at" IS 'Timestamp indicating when the token was successfully used to complete signup.';



CREATE TABLE IF NOT EXISTS "public"."slack_channels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "display_title" "text" NOT NULL,
    "description" "text",
    "type" "public"."slack_channel_type" NOT NULL,
    "geo_filter" "public"."slack_channel_geo",
    "join_url" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "channel_name" "text"
);


ALTER TABLE "public"."slack_channels" OWNER TO "postgres";


COMMENT ON TABLE "public"."slack_channels" IS 'Stores information for the Slack Directory.';



CREATE TABLE IF NOT EXISTS "public"."support_issue_links" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "zendesk_ticket_id" bigint,
    "zendesk_ticket_url" "text",
    "linear_issue_id" "text",
    "linear_issue_url" "text",
    "title" "text",
    "status" "text",
    "linked_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."support_issue_links" OWNER TO "postgres";


COMMENT ON TABLE "public"."support_issue_links" IS 'Links support tickets (e.g., Zendesk) with engineering issues (e.g., Linear).';



COMMENT ON COLUMN "public"."support_issue_links"."id" IS 'Internal auto-incrementing primary key.';



COMMENT ON COLUMN "public"."support_issue_links"."zendesk_ticket_id" IS 'Foreign key to the zendesk_tickets table.';



COMMENT ON COLUMN "public"."support_issue_links"."linear_issue_id" IS 'Foreign key to the linear_issues table.';



COMMENT ON COLUMN "public"."support_issue_links"."linked_user_id" IS 'Reference to the internal user profile related to this link.';



CREATE TABLE IF NOT EXISTS "public"."support_tickets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "subject" "text" NOT NULL,
    "description" "text" NOT NULL,
    "status" "public"."support_ticket_status" DEFAULT 'New'::"public"."support_ticket_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."support_tickets" OWNER TO "postgres";


COMMENT ON TABLE "public"."support_tickets" IS 'Stores user-submitted support requests.';



CREATE TABLE IF NOT EXISTS "public"."tags" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "type" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tags" OWNER TO "postgres";


COMMENT ON COLUMN "public"."tags"."type" IS 'Optional categorization for tags, e.g., event_focus, industry, region';



CREATE TABLE IF NOT EXISTS "public"."thematic_areas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."thematic_areas" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."track_record_comprehensive_view" AS
 SELECT "inv"."id" AS "investment_id",
    "inv"."investor_profile_id" AS "profile_id",
    "p"."first_name" AS "investor_first_name",
    "p"."last_name" AS "investor_last_name",
    "p"."work_email" AS "investor_email",
    "jt"."name" AS "investor_job_title",
    "p"."avatar_url" AS "investor_profile_image",
    "p"."aum_range_id" AS "investor_aum_range_id",
    "p"."check_size_range_id" AS "investor_check_size_range_id",
    "inv"."company_id",
    "c"."name" AS "company_name",
    "c"."website" AS "company_website",
    "c"."logo_url" AS "company_logo_url",
    "c"."description" AS "company_description",
    "c"."linkedin_url" AS "company_linkedin_url",
    "c"."investment_stage_id" AS "company_investment_stage_id",
    "comp_stage"."name" AS "company_stage_name",
    "c"."last_funding_date" AS "company_last_funding_date",
    "inv"."investing_firm_id",
    "f"."name" AS "firm_name",
    "f"."logo_url" AS "firm_logo_url",
    "f"."website" AS "firm_website",
    "f"."linkedin_url" AS "firm_linkedin_url",
    "inv"."investment_date",
    "inv"."investment_round_id",
    "inv_round"."name" AS "investment_round_name",
    "inv"."investment_stage_id",
    "inv_stage"."name" AS "investment_stage_name",
    "pcr"."board_role_id",
    "br"."name" AS "board_role_name",
    "pcr"."has_board_seat",
    "pcr"."is_director",
    "inv"."created_at",
    "inv"."updated_at"
   FROM ((((((((("public"."investments" "inv"
     JOIN "public"."profiles" "p" ON (("inv"."investor_profile_id" = "p"."id")))
     JOIN "public"."companies" "c" ON (("inv"."company_id" = "c"."id")))
     JOIN "public"."firms" "f" ON (("inv"."investing_firm_id" = "f"."id")))
     LEFT JOIN "public"."job_titles" "jt" ON (("p"."job_title_id" = "jt"."id")))
     LEFT JOIN "public"."investment_stages" "comp_stage" ON (("c"."investment_stage_id" = "comp_stage"."id")))
     LEFT JOIN "public"."investment_rounds" "inv_round" ON (("inv"."investment_round_id" = "inv_round"."id")))
     LEFT JOIN "public"."investment_stages" "inv_stage" ON (("inv"."investment_stage_id" = "inv_stage"."id")))
     LEFT JOIN "public"."profile_company_roles" "pcr" ON ((("inv"."investor_profile_id" = "pcr"."profile_id") AND ("inv"."company_id" = "pcr"."company_id"))))
     LEFT JOIN "public"."board_roles" "br" ON (("pcr"."board_role_id" = "br"."id")));


ALTER TABLE "public"."track_record_comprehensive_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_interested_firms" (
    "interested_profile_id" "uuid" NOT NULL,
    "target_firm_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_interested_firms" OWNER TO "postgres";


COMMENT ON COLUMN "public"."user_interested_firms"."interested_profile_id" IS 'The user expressing interest';



COMMENT ON COLUMN "public"."user_interested_firms"."target_firm_id" IS 'The firm the user is interested in';



CREATE TABLE IF NOT EXISTS "public"."users_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "role_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "public"."users_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vc_firm_type" (
    "id" integer NOT NULL,
    "name" "text" NOT NULL
);


ALTER TABLE "public"."vc_firm_type" OWNER TO "postgres";


COMMENT ON TABLE "public"."vc_firm_type" IS 'Lookup table for Venture Capital firm types.';



CREATE SEQUENCE IF NOT EXISTS "public"."vc_firm_type_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."vc_firm_type_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."vc_firm_type_id_seq" OWNED BY "public"."vc_firm_type"."id";



CREATE TABLE IF NOT EXISTS "public"."zendesk_tickets" (
    "id" bigint NOT NULL,
    "subject" "text",
    "requester_id" "text",
    "priority" "text",
    "status" "text",
    "tags" "text"[],
    "zendesk_created_at" timestamp with time zone,
    "zendesk_updated_at" timestamp with time zone,
    "synced_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "zendesk_tickets_status_check" CHECK ((("status" IS NULL) OR ("status" = ANY (ARRAY['new'::"text", 'open'::"text", 'pending'::"text", 'solved'::"text"]))))
);


ALTER TABLE "public"."zendesk_tickets" OWNER TO "postgres";


COMMENT ON TABLE "public"."zendesk_tickets" IS 'Stores ticket data synced from Zendesk.';



COMMENT ON COLUMN "public"."zendesk_tickets"."id" IS 'Primary key: The numeric ID of the ticket in Zendesk.';



COMMENT ON COLUMN "public"."zendesk_tickets"."subject" IS 'The subject line of the Zendesk ticket.';



COMMENT ON COLUMN "public"."zendesk_tickets"."requester_id" IS 'The user ID of the requester in Zendesk.';



COMMENT ON COLUMN "public"."zendesk_tickets"."priority" IS 'Priority of the ticket (e.g., low, normal, high, urgent). Optional.';



COMMENT ON COLUMN "public"."zendesk_tickets"."status" IS 'Current status of the ticket (e.g., new, open, pending, solved).';



COMMENT ON COLUMN "public"."zendesk_tickets"."tags" IS 'Tags associated with the ticket in Zendesk.';



COMMENT ON COLUMN "public"."zendesk_tickets"."zendesk_created_at" IS 'Timestamp when the ticket was created in Zendesk.';



COMMENT ON COLUMN "public"."zendesk_tickets"."zendesk_updated_at" IS 'Timestamp when the ticket was last updated in Zendesk.';



COMMENT ON COLUMN "public"."zendesk_tickets"."synced_at" IS 'Timestamp when this record was last synced or created locally.';



CREATE TABLE IF NOT EXISTS "public"."zendesk_users" (
    "id" bigint NOT NULL,
    "email" "text",
    "name" "text",
    "zendesk_created_at" timestamp with time zone,
    "synced_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."zendesk_users" OWNER TO "postgres";


COMMENT ON TABLE "public"."zendesk_users" IS 'Stores user data synced from Zendesk.';



COMMENT ON COLUMN "public"."zendesk_users"."id" IS 'Primary key: The numeric ID of the user in Zendesk.';



ALTER TABLE ONLY "public"."addevent_interactions_log" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."addevent_interactions_log_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."email_config" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."email_config_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."job_locations" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."job_locations_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."scrape_tracking" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."scrape_tracking_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."service_provider_categories" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."service_provider_categories_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."vc_firm_type" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."vc_firm_type_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."access_levels"
    ADD CONSTRAINT "access_levels_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."access_levels"
    ADD CONSTRAINT "access_levels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."addevent_calendar_subscriptions"
    ADD CONSTRAINT "addevent_calendar_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."addevent_calendars"
    ADD CONSTRAINT "addevent_calendars_addevent_calendar_id_key" UNIQUE ("addevent_calendar_id");



ALTER TABLE ONLY "public"."addevent_calendars"
    ADD CONSTRAINT "addevent_calendars_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."addevent_integration"
    ADD CONSTRAINT "addevent_integration_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."addevent_interactions_log"
    ADD CONSTRAINT "addevent_interactions_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."applicant_firms"
    ADD CONSTRAINT "applicant_firms_pkey" PRIMARY KEY ("applicant_id", "firm_id");



ALTER TABLE ONLY "public"."applicants"
    ADD CONSTRAINT "applicants_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."applicants"
    ADD CONSTRAINT "applicants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."applicants"
    ADD CONSTRAINT "applicants_signup_token_key" UNIQUE ("signup_token");



ALTER TABLE ONLY "public"."applicants"
    ADD CONSTRAINT "applicants_work_email_key" UNIQUE ("work_email");



ALTER TABLE ONLY "public"."application_logs"
    ADD CONSTRAINT "application_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."application_questions"
    ADD CONSTRAINT "application_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."application_responses"
    ADD CONSTRAINT "application_responses_applicant_id_question_id_key" UNIQUE ("applicant_id", "question_id");



ALTER TABLE ONLY "public"."application_responses"
    ADD CONSTRAINT "application_responses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."aum_ranges"
    ADD CONSTRAINT "aum_ranges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."aum_ranges"
    ADD CONSTRAINT "aum_ranges_range_name_key" UNIQUE ("range_name");



ALTER TABLE ONLY "public"."auth_settings_documentation"
    ADD CONSTRAINT "auth_settings_documentation_pkey" PRIMARY KEY ("name");



ALTER TABLE ONLY "public"."board_roles"
    ADD CONSTRAINT "board_roles_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."board_roles"
    ADD CONSTRAINT "board_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."check_size_ranges"
    ADD CONSTRAINT "check_size_ranges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."check_size_ranges"
    ADD CONSTRAINT "check_size_ranges_range_name_key" UNIQUE ("range_name");



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."email_config"
    ADD CONSTRAINT "email_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."email_config"
    ADD CONSTRAINT "email_config_provider_key" UNIQUE ("provider");



ALTER TABLE ONLY "public"."employment_history"
    ADD CONSTRAINT "employment_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "event_attendance_profile_event_unique" UNIQUE ("profile_id", "event_id");



ALTER TABLE ONLY "public"."event_format_enum"
    ADD CONSTRAINT "event_format_enum_format_name_key" UNIQUE ("format_name");



ALTER TABLE ONLY "public"."event_format_enum"
    ADD CONSTRAINT "event_format_enum_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_logistics_status_enum"
    ADD CONSTRAINT "event_logistics_status_enum_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_logistics_status_enum"
    ADD CONSTRAINT "event_logistics_status_enum_status_name_key" UNIQUE ("status_name");



ALTER TABLE ONLY "public"."event_sponsorship_status_enum"
    ADD CONSTRAINT "event_sponsorship_status_enum_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_sponsorship_status_enum"
    ADD CONSTRAINT "event_sponsorship_status_enum_status_name_key" UNIQUE ("status_name");



ALTER TABLE ONLY "public"."event_type_enum"
    ADD CONSTRAINT "event_type_enum_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_type_enum"
    ADD CONSTRAINT "event_type_enum_type_name_key" UNIQUE ("type_name");



ALTER TABLE ONLY "public"."external_user_identities"
    ADD CONSTRAINT "external_user_identities_pkey" PRIMARY KEY ("profile_id", "system_name");



ALTER TABLE ONLY "public"."firm_investment_rounds"
    ADD CONSTRAINT "firm_investment_rounds_pkey" PRIMARY KEY ("firm_id", "investment_round_id");



ALTER TABLE ONLY "public"."firm_lead_rounds"
    ADD CONSTRAINT "firm_lead_rounds_pkey" PRIMARY KEY ("firm_id", "tag_id");



ALTER TABLE ONLY "public"."firm_region_relationships"
    ADD CONSTRAINT "firm_region_relationships_pkey" PRIMARY KEY ("firm_id", "region_id");



ALTER TABLE ONLY "public"."firm_regions"
    ADD CONSTRAINT "firm_regions_pkey" PRIMARY KEY ("firm_id", "tag_id");



ALTER TABLE ONLY "public"."firm_sector_relationships"
    ADD CONSTRAINT "firm_sector_relationships_pkey" PRIMARY KEY ("firm_id", "sector_id");



ALTER TABLE ONLY "public"."firm_sectors"
    ADD CONSTRAINT "firm_sectors_pkey" PRIMARY KEY ("firm_id", "tag_id");



ALTER TABLE ONLY "public"."firms"
    ADD CONSTRAINT "firms_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."firms"
    ADD CONSTRAINT "firms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."firms"
    ADD CONSTRAINT "firms_website_key" UNIQUE ("website");



ALTER TABLE ONLY "public"."fortune_data_links"
    ADD CONSTRAINT "fortune_data_links_fortune_deal_id_key" UNIQUE ("fortune_deal_id");



ALTER TABLE ONLY "public"."fortune_data_links"
    ADD CONSTRAINT "fortune_data_links_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fortune_deals"
    ADD CONSTRAINT "fortune_deals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fortune_deals"
    ADD CONSTRAINT "fortune_deals_source_article_url_key" UNIQUE ("source_article_url");



ALTER TABLE ONLY "public"."frontier_interests"
    ADD CONSTRAINT "frontier_interests_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."frontier_interests"
    ADD CONSTRAINT "frontier_interests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."icebreaker_options"
    ADD CONSTRAINT "icebreaker_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."icebreaker_options"
    ADD CONSTRAINT "icebreaker_options_prompt_key" UNIQUE ("prompt");



ALTER TABLE ONLY "public"."integration_logs"
    ADD CONSTRAINT "integration_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."interest_communities"
    ADD CONSTRAINT "interest_communities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."intro_cadence_options"
    ADD CONSTRAINT "intro_cadence_options_cadence_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."intro_cadence_options"
    ADD CONSTRAINT "intro_cadence_options_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."intro_cadence_options"
    ADD CONSTRAINT "intro_cadence_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."intro_preferences_options"
    ADD CONSTRAINT "intro_preferences_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."intro_preferences_options"
    ADD CONSTRAINT "intro_preferences_options_preference_name_key" UNIQUE ("preference_name");



ALTER TABLE ONLY "public"."investment_rounds"
    ADD CONSTRAINT "investment_rounds_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."investment_rounds"
    ADD CONSTRAINT "investment_rounds_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."investment_stages"
    ADD CONSTRAINT "investment_stages_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."investment_stages"
    ADD CONSTRAINT "investment_stages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."investments"
    ADD CONSTRAINT "investments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."investor_name_mappings"
    ADD CONSTRAINT "investor_name_mappings_investor_name_key" UNIQUE ("investor_name");



ALTER TABLE ONLY "public"."investor_name_mappings"
    ADD CONSTRAINT "investor_name_mappings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."job_locations"
    ADD CONSTRAINT "job_locations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."job_locations"
    ADD CONSTRAINT "job_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."job_postings"
    ADD CONSTRAINT "job_postings_external_job_posting_id_key" UNIQUE ("external_job_posting_id");



ALTER TABLE ONLY "public"."job_postings"
    ADD CONSTRAINT "job_postings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."job_titles"
    ADD CONSTRAINT "job_titles_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."job_titles"
    ADD CONSTRAINT "job_titles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."job_titles"
    ADD CONSTRAINT "job_titles_uuid_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."lifecycle_stages"
    ADD CONSTRAINT "lifecycle_stages_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."lifecycle_stages"
    ADD CONSTRAINT "lifecycle_stages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lifecycle_stages"
    ADD CONSTRAINT "lifecycle_stages_stage_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."linear_issues"
    ADD CONSTRAINT "linear_issues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."member_locations"
    ADD CONSTRAINT "member_locations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."member_locations"
    ADD CONSTRAINT "member_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."member_types"
    ADD CONSTRAINT "member_types_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."member_types"
    ADD CONSTRAINT "member_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_stripe_subscription_id_key" UNIQUE ("stripe_subscription_id");



ALTER TABLE ONLY "public"."network_connections"
    ADD CONSTRAINT "network_connections_pkey" PRIMARY KEY ("user_id_1", "user_id_2");



ALTER TABLE ONLY "public"."onboarding_progress"
    ADD CONSTRAINT "onboarding_progress_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_stripe_charge_id_key" UNIQUE ("stripe_charge_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_stripe_payment_intent_id_key" UNIQUE ("stripe_payment_intent_id");



ALTER TABLE ONLY "public"."profile_community_sectors"
    ADD CONSTRAINT "profile_community_sectors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_community_sectors"
    ADD CONSTRAINT "profile_community_sectors_profile_id_sector_id_key" UNIQUE ("profile_id", "sector_id");



ALTER TABLE ONLY "public"."profile_company_roles"
    ADD CONSTRAINT "profile_company_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_frontier_interests"
    ADD CONSTRAINT "profile_frontier_interests_pkey" PRIMARY KEY ("profile_id", "interest_id");



ALTER TABLE ONLY "public"."profile_images"
    ADD CONSTRAINT "profile_images_pkey" PRIMARY KEY ("profile_id");



ALTER TABLE ONLY "public"."profile_interest_communities"
    ADD CONSTRAINT "profile_interest_communities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_interest_communities"
    ADD CONSTRAINT "profile_interest_communities_profile_id_interest_community__key" UNIQUE ("profile_id", "interest_community_id");



ALTER TABLE ONLY "public"."profile_intro_sectors"
    ADD CONSTRAINT "profile_intro_sectors_pkey" PRIMARY KEY ("profile_id", "sector_id");



ALTER TABLE ONLY "public"."profile_intro_stages"
    ADD CONSTRAINT "profile_intro_stages_pkey" PRIMARY KEY ("profile_id", "investment_stage_id");



ALTER TABLE ONLY "public"."profile_job_location_preferences"
    ADD CONSTRAINT "profile_job_location_preferences_pkey" PRIMARY KEY ("profile_id", "job_location_id");



ALTER TABLE ONLY "public"."profile_job_title_preferences"
    ADD CONSTRAINT "profile_job_title_preferences_pkey" PRIMARY KEY ("profile_id", "job_title_id");



ALTER TABLE ONLY "public"."profile_match_sectors"
    ADD CONSTRAINT "profile_match_sectors_pkey" PRIMARY KEY ("profile_id", "sector_id");



ALTER TABLE ONLY "public"."profile_match_stages"
    ADD CONSTRAINT "profile_match_stages_pkey" PRIMARY KEY ("profile_id", "investment_stage_id");



ALTER TABLE ONLY "public"."profile_preferences"
    ADD CONSTRAINT "profile_preferences_pkey" PRIMARY KEY ("profile_id");



ALTER TABLE ONLY "public"."profile_professional_details"
    ADD CONSTRAINT "profile_professional_details_pkey" PRIMARY KEY ("profile_id");



ALTER TABLE ONLY "public"."profile_sector_focuses"
    ADD CONSTRAINT "profile_sector_focuses_pkey" PRIMARY KEY ("profile_id", "sector_id");



ALTER TABLE ONLY "public"."profile_sector_preferences"
    ADD CONSTRAINT "profile_sector_preferences_pkey" PRIMARY KEY ("profile_id", "sector_id");



ALTER TABLE ONLY "public"."profile_social_links"
    ADD CONSTRAINT "profile_social_links_pkey" PRIMARY KEY ("profile_id");



ALTER TABLE ONLY "public"."profile_stage_focuses"
    ADD CONSTRAINT "profile_stage_focuses_pkey" PRIMARY KEY ("profile_id", "investment_stage_id");



ALTER TABLE ONLY "public"."profile_stage_preferences"
    ADD CONSTRAINT "profile_stage_preferences_pkey" PRIMARY KEY ("profile_id", "investment_stage_id");



ALTER TABLE ONLY "public"."profile_thematic_interests"
    ADD CONSTRAINT "profile_thematic_interests_pkey" PRIMARY KEY ("profile_id", "thematic_area_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_hubspot_contact_id_key" UNIQUE ("hubspot_contact_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_stripe_customer_id_key" UNIQUE ("stripe_customer_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_work_email_key" UNIQUE ("work_email");



ALTER TABLE ONLY "public"."referral_options"
    ADD CONSTRAINT "referral_options_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."referral_options"
    ADD CONSTRAINT "referral_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."regions"
    ADD CONSTRAINT "regions_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."regions"
    ADD CONSTRAINT "regions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."scrape_tracking"
    ADD CONSTRAINT "scrape_tracking_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."screening_applications"
    ADD CONSTRAINT "screening_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sectors"
    ADD CONSTRAINT "sectors_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."sectors"
    ADD CONSTRAINT "sectors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."service_provider_categories"
    ADD CONSTRAINT "service_provider_categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."service_provider_categories"
    ADD CONSTRAINT "service_provider_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."service_provider_reviews"
    ADD CONSTRAINT "service_provider_reviews_external_review_id_key" UNIQUE ("external_review_id");



ALTER TABLE ONLY "public"."service_provider_reviews"
    ADD CONSTRAINT "service_provider_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."service_providers"
    ADD CONSTRAINT "service_providers_external_provider_id_key" UNIQUE ("external_provider_id");



ALTER TABLE ONLY "public"."service_providers"
    ADD CONSTRAINT "service_providers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."signup_tokens"
    ADD CONSTRAINT "signup_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."signup_tokens"
    ADD CONSTRAINT "signup_tokens_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."slack_channels"
    ADD CONSTRAINT "slack_channels_join_url_key" UNIQUE ("join_url");



ALTER TABLE ONLY "public"."slack_channels"
    ADD CONSTRAINT "slack_channels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_issue_links"
    ADD CONSTRAINT "support_issue_links_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_tickets"
    ADD CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."thematic_areas"
    ADD CONSTRAINT "thematic_areas_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."thematic_areas"
    ADD CONSTRAINT "thematic_areas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."network_connections"
    ADD CONSTRAINT "unique_connection_pair_type" UNIQUE ("user_id_1", "user_id_2", "connection_type");



ALTER TABLE ONLY "public"."addevent_integration"
    ADD CONSTRAINT "unique_event_addevent" UNIQUE ("event_id");



ALTER TABLE ONLY "public"."addevent_calendar_subscriptions"
    ADD CONSTRAINT "unique_profile_calendar_subscription" UNIQUE ("profile_id", "addevent_calendar_id");



ALTER TABLE ONLY "public"."profile_company_roles"
    ADD CONSTRAINT "unique_profile_company" UNIQUE ("profile_id", "company_id");



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "unique_profile_event_rsvp" UNIQUE ("profile_id", "event_id");



ALTER TABLE ONLY "public"."user_interested_firms"
    ADD CONSTRAINT "user_interested_firms_pkey" PRIMARY KEY ("interested_profile_id", "target_firm_id");



ALTER TABLE ONLY "public"."users_roles"
    ADD CONSTRAINT "users_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vc_firm_type"
    ADD CONSTRAINT "vc_firm_type_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."vc_firm_type"
    ADD CONSTRAINT "vc_firm_type_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."zendesk_tickets"
    ADD CONSTRAINT "zendesk_tickets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."zendesk_users"
    ADD CONSTRAINT "zendesk_users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."zendesk_users"
    ADD CONSTRAINT "zendesk_users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_addevent_calendar_subscriptions_addevent_calendar_id" ON "public"."addevent_calendar_subscriptions" USING "btree" ("addevent_calendar_id");



CREATE INDEX "idx_addevent_calendar_subscriptions_addevent_subscriber_id" ON "public"."addevent_calendar_subscriptions" USING "btree" ("addevent_subscriber_id");



CREATE INDEX "idx_addevent_calendar_subscriptions_profile_id" ON "public"."addevent_calendar_subscriptions" USING "btree" ("profile_id");



CREATE INDEX "idx_addevent_calendar_subscriptions_status" ON "public"."addevent_calendar_subscriptions" USING "btree" ("subscription_status");



CREATE INDEX "idx_addevent_calendars_addevent_calendar_id" ON "public"."addevent_calendars" USING "btree" ("addevent_calendar_id");



CREATE INDEX "idx_addevent_integration_event_id" ON "public"."addevent_integration" USING "btree" ("addevent_event_id");



CREATE INDEX "idx_addevent_interactions_log_addevent_calendar_id" ON "public"."addevent_interactions_log" USING "btree" ("addevent_calendar_id");



CREATE INDEX "idx_addevent_interactions_log_community_event_id" ON "public"."addevent_interactions_log" USING "btree" ("community_event_id");



CREATE INDEX "idx_addevent_interactions_log_interaction_type" ON "public"."addevent_interactions_log" USING "btree" ("interaction_type");



CREATE INDEX "idx_addevent_interactions_log_profile_id" ON "public"."addevent_interactions_log" USING "btree" ("profile_id");



CREATE INDEX "idx_addevent_interactions_log_timestamp" ON "public"."addevent_interactions_log" USING "btree" ("timestamp");



CREATE INDEX "idx_applicants_date" ON "public"."applicants" USING "btree" ("application_date");



CREATE INDEX "idx_applicants_signup_token" ON "public"."applicants" USING "btree" ("signup_token");



CREATE INDEX "idx_applicants_status" ON "public"."applicants" USING "btree" ("application_status");



CREATE INDEX "idx_audit_logs_action" ON "public"."audit_logs" USING "btree" ("action");



CREATE INDEX "idx_audit_logs_actor_user_id" ON "public"."audit_logs" USING "btree" ("actor_user_id");



CREATE INDEX "idx_audit_logs_target" ON "public"."audit_logs" USING "btree" ("target_entity_type", "target_entity_id");



CREATE INDEX "idx_audit_logs_timestamp" ON "public"."audit_logs" USING "btree" ("timestamp");



CREATE INDEX "idx_community_events_addevent_event_id" ON "public"."community_events" USING "btree" ("addevent_event_id");



CREATE INDEX "idx_community_events_start_time" ON "public"."community_events" USING "btree" ("start_datetime");



CREATE INDEX "idx_community_events_status" ON "public"."community_events" USING "btree" ("status");



CREATE INDEX "idx_companies_domain" ON "public"."companies" USING "btree" ("public"."get_domain_from_url"("website"));



CREATE INDEX "idx_companies_investment_stage_id" ON "public"."companies" USING "btree" ("investment_stage_id");



CREATE INDEX "idx_companies_last_funding_date" ON "public"."companies" USING "btree" ("last_funding_date");



CREATE INDEX "idx_companies_name" ON "public"."companies" USING "btree" ("name");



CREATE INDEX "idx_companies_normalized_name" ON "public"."companies" USING "btree" ("public"."normalize_entity_name"("name"));



CREATE INDEX "idx_companies_website" ON "public"."companies" USING "btree" ("website");



CREATE INDEX "idx_employment_history_firm_id" ON "public"."employment_history" USING "btree" ("firm_id");



CREATE INDEX "idx_employment_history_profile_id" ON "public"."employment_history" USING "btree" ("profile_id");



CREATE INDEX "idx_event_attendance_addevent_attendee_id" ON "public"."event_attendance" USING "btree" ("addevent_attendee_id");



CREATE INDEX "idx_event_attendance_event_id" ON "public"."event_attendance" USING "btree" ("event_id");



CREATE UNIQUE INDEX "idx_event_attendance_id" ON "public"."event_attendance" USING "btree" ("id");



CREATE INDEX "idx_event_attendance_profile_id" ON "public"."event_attendance" USING "btree" ("profile_id");



CREATE INDEX "idx_external_user_identities_system_external_id" ON "public"."external_user_identities" USING "btree" ("system_name", "external_user_id");



CREATE INDEX "idx_firm_sector_relationships_combined" ON "public"."firm_sector_relationships" USING "btree" ("firm_id", "sector_id");



CREATE INDEX "idx_firms_domain" ON "public"."firms" USING "btree" ("public"."get_domain_from_url"("website"));



CREATE INDEX "idx_firms_firm_type_id" ON "public"."firms" USING "btree" ("firm_type_id");



CREATE INDEX "idx_firms_linkedin_url" ON "public"."firms" USING "btree" ("linkedin_url");



CREATE INDEX "idx_firms_name" ON "public"."firms" USING "btree" ("name");



CREATE INDEX "idx_firms_normalized_name" ON "public"."firms" USING "btree" ("public"."normalize_entity_name"("name"));



CREATE INDEX "idx_firms_website" ON "public"."firms" USING "btree" ("website");



CREATE INDEX "idx_fortune_data_links_company_id" ON "public"."fortune_data_links" USING "btree" ("company_id");



CREATE INDEX "idx_fortune_data_links_deal_id" ON "public"."fortune_data_links" USING "btree" ("fortune_deal_id");



CREATE INDEX "idx_fortune_data_links_firm_id" ON "public"."fortune_data_links" USING "btree" ("lead_investor_firm_id");



CREATE INDEX "idx_fortune_deals_company_website" ON "public"."fortune_deals" USING "btree" ("company_website");



CREATE INDEX "idx_fortune_deals_publication_date" ON "public"."fortune_deals" USING "btree" ("article_publication_date");



CREATE INDEX "idx_fortune_deals_startup_name" ON "public"."fortune_deals" USING "btree" ("startup_name");



CREATE INDEX "idx_integration_logs_created_at" ON "public"."integration_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_integration_logs_object_id" ON "public"."integration_logs" USING "btree" ("object_id");



CREATE INDEX "idx_integration_logs_type_action" ON "public"."integration_logs" USING "btree" ("integration_type", "action");



CREATE INDEX "idx_investments_company_id" ON "public"."investments" USING "btree" ("company_id");



CREATE INDEX "idx_investments_investing_firm_id" ON "public"."investments" USING "btree" ("investing_firm_id");



CREATE INDEX "idx_investments_investor_profile_id" ON "public"."investments" USING "btree" ("investor_profile_id");



CREATE INDEX "idx_investor_name_mappings_firm_id" ON "public"."investor_name_mappings" USING "btree" ("firm_id");



CREATE INDEX "idx_investor_name_mappings_name" ON "public"."investor_name_mappings" USING "btree" ("investor_name");



CREATE INDEX "idx_investor_name_mappings_normalized" ON "public"."investor_name_mappings" USING "btree" ("normalized_name");



CREATE INDEX "idx_job_postings_external_job_posting_id" ON "public"."job_postings" USING "btree" ("external_job_posting_id");



CREATE INDEX "idx_job_postings_firm_id" ON "public"."job_postings" USING "btree" ("firm_id");



CREATE INDEX "idx_job_postings_job_location_id" ON "public"."job_postings" USING "btree" ("job_location_id");



CREATE INDEX "idx_job_postings_job_title_id" ON "public"."job_postings" USING "btree" ("job_title_id");



CREATE INDEX "idx_job_postings_posted_by_profile_id" ON "public"."job_postings" USING "btree" ("posted_by_profile_id");



CREATE INDEX "idx_linear_issues_assignee_id" ON "public"."linear_issues" USING "btree" ("assignee_id");



CREATE INDEX "idx_linear_issues_status" ON "public"."linear_issues" USING "btree" ("status");



CREATE INDEX "idx_memberships_status" ON "public"."memberships" USING "btree" ("status");



CREATE INDEX "idx_memberships_stripe_sub_id" ON "public"."memberships" USING "btree" ("stripe_subscription_id");



CREATE INDEX "idx_memberships_user_id" ON "public"."memberships" USING "btree" ("user_id");



CREATE INDEX "idx_network_connections_user_id_2" ON "public"."network_connections" USING "btree" ("user_id_2");



CREATE INDEX "idx_payments_membership_id" ON "public"."payments" USING "btree" ("membership_id");



CREATE INDEX "idx_payments_stripe_charge_id" ON "public"."payments" USING "btree" ("stripe_charge_id");



CREATE INDEX "idx_payments_stripe_payment_intent_id" ON "public"."payments" USING "btree" ("stripe_payment_intent_id");



CREATE INDEX "idx_payments_user_id" ON "public"."payments" USING "btree" ("user_id");



CREATE INDEX "idx_profile_company_roles_board_role_id" ON "public"."profile_company_roles" USING "btree" ("board_role_id");



CREATE INDEX "idx_profile_company_roles_combined" ON "public"."profile_company_roles" USING "btree" ("profile_id", "company_id");



CREATE INDEX "idx_profile_company_roles_company_id" ON "public"."profile_company_roles" USING "btree" ("company_id");



CREATE INDEX "idx_profile_company_roles_profile_id" ON "public"."profile_company_roles" USING "btree" ("profile_id");



CREATE INDEX "idx_profile_frontier_interests_interest_id" ON "public"."profile_frontier_interests" USING "btree" ("interest_id");



CREATE INDEX "idx_profile_frontier_interests_profile_id" ON "public"."profile_frontier_interests" USING "btree" ("profile_id");



CREATE INDEX "idx_profiles_access_level_id" ON "public"."profiles" USING "btree" ("access_level_id");



CREATE INDEX "idx_profiles_aum_range_id" ON "public"."profiles" USING "btree" ("aum_range_id");



CREATE INDEX "idx_profiles_check_size_range_id" ON "public"."profiles" USING "btree" ("check_size_range_id");



CREATE INDEX "idx_profiles_firm_id" ON "public"."profiles" USING "btree" ("firm_id");



CREATE INDEX "idx_profiles_firm_job_title" ON "public"."profiles" USING "btree" ("firm_id", "job_title_id");



CREATE INDEX "idx_profiles_how_heard_id" ON "public"."profiles" USING "btree" ("how_heard_id");



CREATE INDEX "idx_profiles_hubspot_id" ON "public"."profiles" USING "btree" ("hubspot_contact_id");



CREATE INDEX "idx_profiles_intro_cadence_id" ON "public"."profiles" USING "btree" ("intro_cadence_id");



CREATE INDEX "idx_profiles_job_title_id" ON "public"."profiles" USING "btree" ("job_title_id");



CREATE INDEX "idx_profiles_lifecycle_stage_id" ON "public"."profiles" USING "btree" ("lifecycle_stage_id");



CREATE INDEX "idx_profiles_location_id" ON "public"."profiles" USING "btree" ("location_id");



CREATE INDEX "idx_profiles_member_type_id" ON "public"."profiles" USING "btree" ("member_type_id");



CREATE INDEX "idx_profiles_status" ON "public"."profiles" USING "btree" ("status");



CREATE INDEX "idx_profiles_stripe_customer_id" ON "public"."profiles" USING "btree" ("stripe_customer_id");



CREATE INDEX "idx_reviews_external_review_id" ON "public"."service_provider_reviews" USING "btree" ("external_review_id");



CREATE INDEX "idx_reviews_reviewer_profile_id" ON "public"."service_provider_reviews" USING "btree" ("reviewer_profile_id");



CREATE INDEX "idx_reviews_service_provider_id" ON "public"."service_provider_reviews" USING "btree" ("service_provider_id");



CREATE INDEX "idx_scrape_tracking_entity" ON "public"."scrape_tracking" USING "btree" ("entity_id", "entity_type");



CREATE INDEX "idx_scrape_tracking_scraped_at" ON "public"."scrape_tracking" USING "btree" ("scraped_at");



CREATE INDEX "idx_screening_applications_email" ON "public"."screening_applications" USING "btree" ("work_email");



CREATE INDEX "idx_screening_applications_job_title_id" ON "public"."screening_applications" USING "btree" ("job_title_id");



CREATE INDEX "idx_screening_applications_status" ON "public"."screening_applications" USING "btree" ("status");



CREATE INDEX "idx_service_providers_category_id" ON "public"."service_providers" USING "btree" ("category_id");



CREATE INDEX "idx_service_providers_created_by_profile_id" ON "public"."service_providers" USING "btree" ("created_by_profile_id");



CREATE INDEX "idx_service_providers_external_provider_id" ON "public"."service_providers" USING "btree" ("external_provider_id");



CREATE INDEX "idx_service_providers_name" ON "public"."service_providers" USING "btree" ("name");



CREATE INDEX "idx_signup_tokens_email" ON "public"."signup_tokens" USING "btree" ("email");



CREATE INDEX "idx_signup_tokens_expires_at" ON "public"."signup_tokens" USING "btree" ("expires_at");



CREATE INDEX "idx_signup_tokens_token" ON "public"."signup_tokens" USING "btree" ("token");



CREATE INDEX "idx_support_issue_links_linear_issue_id" ON "public"."support_issue_links" USING "btree" ("linear_issue_id");



CREATE INDEX "idx_support_issue_links_linked_user_id" ON "public"."support_issue_links" USING "btree" ("linked_user_id");



CREATE INDEX "idx_support_issue_links_zendesk_ticket_id" ON "public"."support_issue_links" USING "btree" ("zendesk_ticket_id");



CREATE INDEX "idx_support_tickets_status" ON "public"."support_tickets" USING "btree" ("status");



CREATE INDEX "idx_support_tickets_user_id" ON "public"."support_tickets" USING "btree" ("user_id");



CREATE INDEX "idx_tags_name" ON "public"."tags" USING "btree" ("name");



CREATE INDEX "idx_tags_type" ON "public"."tags" USING "btree" ("type");



CREATE INDEX "idx_zendesk_tickets_requester_id" ON "public"."zendesk_tickets" USING "btree" ("requester_id");



CREATE INDEX "idx_zendesk_tickets_status" ON "public"."zendesk_tickets" USING "btree" ("status");



CREATE INDEX "idx_zendesk_tickets_zendesk_updated_at" ON "public"."zendesk_tickets" USING "btree" ("zendesk_updated_at" DESC);



CREATE INDEX "idx_zendesk_users_email" ON "public"."zendesk_users" USING "btree" ("email");



CREATE INDEX "users_roles_role_id_idx" ON "public"."users_roles" USING "btree" ("role_id");



CREATE INDEX "users_roles_user_id_idx" ON "public"."users_roles" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "Sync Approved Applicant to CIO" AFTER INSERT OR UPDATE ON "public"."applicants" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://xtavvykpwuxzwrqnsxva.supabase.co/functions/v1/sync-to-customerio', 'POST', '{"Content-type":"application/json"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "Upsert CIO Subscription Object" AFTER INSERT OR UPDATE ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://xtavvykpwuxzwrqnsxva.functions.supabase.co/cio-upsert-custom-object', 'POST', '{"Content-type":"application/json"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "create_profile_related_records" AFTER INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_profile_related_records"();



CREATE OR REPLACE TRIGGER "handle_applicant_firms_updated_at" BEFORE UPDATE ON "public"."applicant_firms" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "handle_integration_logs_updated_at" BEFORE UPDATE ON "public"."integration_logs" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');



CREATE OR REPLACE TRIGGER "on_community_event_update" BEFORE UPDATE ON "public"."community_events" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_companies_update" BEFORE UPDATE ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_employment_history_update" BEFORE UPDATE ON "public"."employment_history" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_event_attendance_update" BEFORE UPDATE ON "public"."event_attendance" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_firm_update" BEFORE UPDATE ON "public"."firms" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_investments_update" BEFORE UPDATE ON "public"."investments" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_job_postings_update" BEFORE UPDATE ON "public"."job_postings" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_membership_update" BEFORE UPDATE ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_network_connections_update" BEFORE UPDATE ON "public"."network_connections" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_payment_update" BEFORE UPDATE ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_profile_update" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_service_provider_reviews_update" BEFORE UPDATE ON "public"."service_provider_reviews" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_service_providers_update" BEFORE UPDATE ON "public"."service_providers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_slack_channels_update" BEFORE UPDATE ON "public"."slack_channels" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "on_support_tickets_update" BEFORE UPDATE ON "public"."support_tickets" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_company_logo_url" BEFORE INSERT OR UPDATE OF "website" ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."generate_logo_url_from_website"('xtavvykpwuxzwrqnsxva');



CREATE OR REPLACE TRIGGER "set_firm_logo_url" BEFORE INSERT OR UPDATE OF "website" ON "public"."firms" FOR EACH ROW EXECUTE FUNCTION "public"."generate_logo_url_from_website"('xtavvykpwuxzwrqnsxva');



CREATE OR REPLACE TRIGGER "set_timestamp" BEFORE UPDATE ON "public"."community_events" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp" BEFORE UPDATE ON "public"."firms" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_timestamp"();



CREATE OR REPLACE TRIGGER "trg_audit_community_events" AFTER INSERT OR DELETE OR UPDATE ON "public"."community_events" FOR EACH ROW EXECUTE FUNCTION "public"."audit_changes"();



CREATE OR REPLACE TRIGGER "trg_audit_investments" AFTER INSERT OR DELETE OR UPDATE ON "public"."investments" FOR EACH ROW EXECUTE FUNCTION "public"."audit_changes"();



CREATE OR REPLACE TRIGGER "trg_audit_profiles" AFTER INSERT OR DELETE OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."trg_audit_profiles"();



CREATE OR REPLACE TRIGGER "trg_validate_event_dates" BEFORE INSERT OR UPDATE ON "public"."community_events" FOR EACH ROW EXECUTE FUNCTION "public"."validate_event_dates"();



CREATE OR REPLACE TRIGGER "update_addevent_calendar_subscriptions_timestamp" BEFORE UPDATE ON "public"."addevent_calendar_subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."update_addevent_calendar_subscriptions_timestamp"();



CREATE OR REPLACE TRIGGER "update_addevent_calendars_timestamp" BEFORE UPDATE ON "public"."addevent_calendars" FOR EACH ROW EXECUTE FUNCTION "public"."update_addevent_calendars_timestamp"();



CREATE OR REPLACE TRIGGER "update_aum_ranges_timestamp" BEFORE UPDATE ON "public"."aum_ranges" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_board_roles_timestamp" BEFORE UPDATE ON "public"."board_roles" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_check_size_ranges_timestamp" BEFORE UPDATE ON "public"."check_size_ranges" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_event_attendance_timestamp" BEFORE UPDATE ON "public"."event_attendance" FOR EACH ROW EXECUTE FUNCTION "public"."update_event_attendance_timestamp"();



CREATE OR REPLACE TRIGGER "update_event_format_enum_timestamp" BEFORE UPDATE ON "public"."event_format_enum" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_event_logistics_status_enum_timestamp" BEFORE UPDATE ON "public"."event_logistics_status_enum" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_event_sponsorship_status_enum_timestamp" BEFORE UPDATE ON "public"."event_sponsorship_status_enum" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_external_user_identities_timestamp" BEFORE UPDATE ON "public"."external_user_identities" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_icebreaker_options_timestamp" BEFORE UPDATE ON "public"."icebreaker_options" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_job_titles_timestamp" BEFORE UPDATE ON "public"."job_titles" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_profile_images_timestamp" BEFORE UPDATE ON "public"."profile_images" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_profile_preferences_timestamp" BEFORE UPDATE ON "public"."profile_preferences" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_profile_professional_details_timestamp" BEFORE UPDATE ON "public"."profile_professional_details" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_profile_social_links_timestamp" BEFORE UPDATE ON "public"."profile_social_links" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_support_issue_links_timestamp" BEFORE UPDATE ON "public"."support_issue_links" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "update_user_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_zendesk_tickets_timestamp" BEFORE UPDATE ON "public"."zendesk_tickets" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



ALTER TABLE ONLY "public"."addevent_calendar_subscriptions"
    ADD CONSTRAINT "addevent_calendar_subscriptions_addevent_calendar_id_fkey" FOREIGN KEY ("addevent_calendar_id") REFERENCES "public"."addevent_calendars"("id");



ALTER TABLE ONLY "public"."addevent_calendar_subscriptions"
    ADD CONSTRAINT "addevent_calendar_subscriptions_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."addevent_interactions_log"
    ADD CONSTRAINT "addevent_interactions_log_addevent_calendar_id_fkey" FOREIGN KEY ("addevent_calendar_id") REFERENCES "public"."addevent_calendars"("id");



ALTER TABLE ONLY "public"."addevent_interactions_log"
    ADD CONSTRAINT "addevent_interactions_log_community_event_id_fkey" FOREIGN KEY ("community_event_id") REFERENCES "public"."community_events"("id");



ALTER TABLE ONLY "public"."addevent_interactions_log"
    ADD CONSTRAINT "addevent_interactions_log_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."applicant_firms"
    ADD CONSTRAINT "applicant_firms_applicant_id_fkey" FOREIGN KEY ("applicant_id") REFERENCES "public"."applicants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applicant_firms"
    ADD CONSTRAINT "applicant_firms_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."applicants"
    ADD CONSTRAINT "applicants_admin_user_id_fkey" FOREIGN KEY ("admin_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."applicants"
    ADD CONSTRAINT "applicants_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."application_logs"
    ADD CONSTRAINT "application_logs_applicant_id_fkey" FOREIGN KEY ("applicant_id") REFERENCES "public"."applicants"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."application_responses"
    ADD CONSTRAINT "application_responses_applicant_id_fkey" FOREIGN KEY ("applicant_id") REFERENCES "public"."applicants"("id");



ALTER TABLE ONLY "public"."application_responses"
    ADD CONSTRAINT "application_responses_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."application_questions"("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_logistics_status_id_fkey" FOREIGN KEY ("logistics_status_id") REFERENCES "public"."event_logistics_status_enum"("id");



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_sponsorship_status_id_fkey" FOREIGN KEY ("sponsorship_status_id") REFERENCES "public"."event_sponsorship_status_enum"("id");



ALTER TABLE ONLY "public"."employment_history"
    ADD CONSTRAINT "employment_history_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."employment_history"
    ADD CONSTRAINT "employment_history_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "event_attendance_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."community_events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_attendance"
    ADD CONSTRAINT "event_attendance_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."external_user_identities"
    ADD CONSTRAINT "external_user_identities_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_investment_rounds"
    ADD CONSTRAINT "firm_investment_rounds_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_investment_rounds"
    ADD CONSTRAINT "firm_investment_rounds_investment_round_id_fkey" FOREIGN KEY ("investment_round_id") REFERENCES "public"."investment_rounds"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_lead_rounds"
    ADD CONSTRAINT "firm_lead_rounds_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_lead_rounds"
    ADD CONSTRAINT "firm_lead_rounds_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_region_relationships"
    ADD CONSTRAINT "firm_region_relationships_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_region_relationships"
    ADD CONSTRAINT "firm_region_relationships_region_id_fkey" FOREIGN KEY ("region_id") REFERENCES "public"."regions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_regions"
    ADD CONSTRAINT "firm_regions_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_regions"
    ADD CONSTRAINT "firm_regions_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_sector_relationships"
    ADD CONSTRAINT "firm_sector_relationships_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_sector_relationships"
    ADD CONSTRAINT "firm_sector_relationships_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "public"."sectors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_sectors"
    ADD CONSTRAINT "firm_sectors_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firm_sectors"
    ADD CONSTRAINT "firm_sectors_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."addevent_integration"
    ADD CONSTRAINT "fk_addevent_integration_event" FOREIGN KEY ("event_id") REFERENCES "public"."community_events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "fk_community_events_created_by" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "fk_community_events_logistics_status" FOREIGN KEY ("logistics_status_id") REFERENCES "public"."event_logistics_status_enum"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "fk_community_events_sponsorship_status" FOREIGN KEY ("sponsorship_status_id") REFERENCES "public"."event_sponsorship_status_enum"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "fk_companies_investment_stage" FOREIGN KEY ("investment_stage_id") REFERENCES "public"."investment_stages"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."firms"
    ADD CONSTRAINT "fk_firms_firm_type" FOREIGN KEY ("firm_type_id") REFERENCES "public"."vc_firm_type"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."investments"
    ADD CONSTRAINT "fk_investment_round" FOREIGN KEY ("investment_round_id") REFERENCES "public"."investment_rounds"("id");



ALTER TABLE ONLY "public"."job_postings"
    ADD CONSTRAINT "fk_job_postings_job_title" FOREIGN KEY ("job_title_id") REFERENCES "public"."job_titles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profile_company_roles"
    ADD CONSTRAINT "fk_profile_company_roles_board_role" FOREIGN KEY ("board_role_id") REFERENCES "public"."board_roles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_ice_breaker_1" FOREIGN KEY ("icebreaker_1_option_id") REFERENCES "public"."icebreaker_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_ice_breaker_2" FOREIGN KEY ("icebreaker_2_option_id") REFERENCES "public"."icebreaker_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_ice_breaker_3" FOREIGN KEY ("icebreaker_3_option_id") REFERENCES "public"."icebreaker_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_intro_cadence" FOREIGN KEY ("intro_cadence_id") REFERENCES "public"."intro_cadence_options"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_intro_preference" FOREIGN KEY ("intro_preference_id") REFERENCES "public"."intro_preferences_options"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "fk_profiles_lifecycle_stage" FOREIGN KEY ("lifecycle_stage_id") REFERENCES "public"."lifecycle_stages"("id");



ALTER TABLE ONLY "public"."screening_applications"
    ADD CONSTRAINT "fk_screening_applications_job_title" FOREIGN KEY ("job_title_id") REFERENCES "public"."job_titles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_interested_firms"
    ADD CONSTRAINT "fk_user_interested_firms_firm" FOREIGN KEY ("target_firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_interested_firms"
    ADD CONSTRAINT "fk_user_interested_firms_profile" FOREIGN KEY ("interested_profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fortune_data_links"
    ADD CONSTRAINT "fortune_data_links_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id");



ALTER TABLE ONLY "public"."fortune_data_links"
    ADD CONSTRAINT "fortune_data_links_fortune_deal_id_fkey" FOREIGN KEY ("fortune_deal_id") REFERENCES "public"."fortune_deals"("id");



ALTER TABLE ONLY "public"."fortune_data_links"
    ADD CONSTRAINT "fortune_data_links_lead_investor_firm_id_fkey" FOREIGN KEY ("lead_investor_firm_id") REFERENCES "public"."firms"("id");



ALTER TABLE ONLY "public"."investments"
    ADD CONSTRAINT "investments_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."investments"
    ADD CONSTRAINT "investments_investing_firm_id_fkey" FOREIGN KEY ("investing_firm_id") REFERENCES "public"."firms"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."investments"
    ADD CONSTRAINT "investments_investment_round_id_fkey" FOREIGN KEY ("investment_round_id") REFERENCES "public"."investment_rounds"("id");



ALTER TABLE ONLY "public"."investments"
    ADD CONSTRAINT "investments_investment_stage_id_fkey" FOREIGN KEY ("investment_stage_id") REFERENCES "public"."investment_stages"("id");



ALTER TABLE ONLY "public"."investments"
    ADD CONSTRAINT "investments_investor_profile_id_fkey" FOREIGN KEY ("investor_profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."investor_name_mappings"
    ADD CONSTRAINT "investor_name_mappings_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id");



ALTER TABLE ONLY "public"."job_postings"
    ADD CONSTRAINT "job_postings_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."job_postings"
    ADD CONSTRAINT "job_postings_job_location_id_fkey" FOREIGN KEY ("job_location_id") REFERENCES "public"."job_locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."job_postings"
    ADD CONSTRAINT "job_postings_posted_by_profile_id_fkey" FOREIGN KEY ("posted_by_profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."network_connections"
    ADD CONSTRAINT "network_connections_user_id_1_fkey" FOREIGN KEY ("user_id_1") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."network_connections"
    ADD CONSTRAINT "network_connections_user_id_2_fkey" FOREIGN KEY ("user_id_2") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."onboarding_progress"
    ADD CONSTRAINT "onboarding_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_membership_id_fkey" FOREIGN KEY ("membership_id") REFERENCES "public"."memberships"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profile_community_sectors"
    ADD CONSTRAINT "profile_community_sectors_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_community_sectors"
    ADD CONSTRAINT "profile_community_sectors_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "public"."sectors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_company_roles"
    ADD CONSTRAINT "profile_company_roles_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_company_roles"
    ADD CONSTRAINT "profile_company_roles_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_frontier_interests"
    ADD CONSTRAINT "profile_frontier_interests_interest_id_fkey" FOREIGN KEY ("interest_id") REFERENCES "public"."frontier_interests"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_frontier_interests"
    ADD CONSTRAINT "profile_frontier_interests_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_images"
    ADD CONSTRAINT "profile_images_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_interest_communities"
    ADD CONSTRAINT "profile_interest_communities_interest_community_id_fkey" FOREIGN KEY ("interest_community_id") REFERENCES "public"."interest_communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_interest_communities"
    ADD CONSTRAINT "profile_interest_communities_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_intro_sectors"
    ADD CONSTRAINT "profile_intro_sectors_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_intro_sectors"
    ADD CONSTRAINT "profile_intro_sectors_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "public"."sectors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_intro_stages"
    ADD CONSTRAINT "profile_intro_stages_investment_stage_id_fkey" FOREIGN KEY ("investment_stage_id") REFERENCES "public"."investment_stages"("id");



ALTER TABLE ONLY "public"."profile_intro_stages"
    ADD CONSTRAINT "profile_intro_stages_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_job_location_preferences"
    ADD CONSTRAINT "profile_job_location_preferences_job_location_id_fkey" FOREIGN KEY ("job_location_id") REFERENCES "public"."job_locations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_job_location_preferences"
    ADD CONSTRAINT "profile_job_location_preferences_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_job_title_preferences"
    ADD CONSTRAINT "profile_job_title_preferences_job_title_id_fkey" FOREIGN KEY ("job_title_id") REFERENCES "public"."job_titles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_job_title_preferences"
    ADD CONSTRAINT "profile_job_title_preferences_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_match_sectors"
    ADD CONSTRAINT "profile_match_sectors_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_match_sectors"
    ADD CONSTRAINT "profile_match_sectors_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "public"."sectors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_match_stages"
    ADD CONSTRAINT "profile_match_stages_investment_stage_id_fkey" FOREIGN KEY ("investment_stage_id") REFERENCES "public"."investment_stages"("id");



ALTER TABLE ONLY "public"."profile_match_stages"
    ADD CONSTRAINT "profile_match_stages_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_preferences"
    ADD CONSTRAINT "profile_preferences_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_professional_details"
    ADD CONSTRAINT "profile_professional_details_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_sector_focuses"
    ADD CONSTRAINT "profile_sector_focuses_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_sector_focuses"
    ADD CONSTRAINT "profile_sector_focuses_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "public"."sectors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_sector_preferences"
    ADD CONSTRAINT "profile_sector_preferences_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_sector_preferences"
    ADD CONSTRAINT "profile_sector_preferences_sector_id_fkey" FOREIGN KEY ("sector_id") REFERENCES "public"."sectors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_social_links"
    ADD CONSTRAINT "profile_social_links_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_stage_focuses"
    ADD CONSTRAINT "profile_stage_focuses_investment_stage_id_fkey" FOREIGN KEY ("investment_stage_id") REFERENCES "public"."investment_stages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_stage_focuses"
    ADD CONSTRAINT "profile_stage_focuses_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_stage_preferences"
    ADD CONSTRAINT "profile_stage_preferences_investment_stage_id_fkey" FOREIGN KEY ("investment_stage_id") REFERENCES "public"."investment_stages"("id");



ALTER TABLE ONLY "public"."profile_stage_preferences"
    ADD CONSTRAINT "profile_stage_preferences_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_thematic_interests"
    ADD CONSTRAINT "profile_thematic_interests_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profile_thematic_interests"
    ADD CONSTRAINT "profile_thematic_interests_thematic_area_id_fkey" FOREIGN KEY ("thematic_area_id") REFERENCES "public"."thematic_areas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_access_level_id_fkey" FOREIGN KEY ("access_level_id") REFERENCES "public"."access_levels"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_aum_range_id_fkey" FOREIGN KEY ("aum_range_id") REFERENCES "public"."aum_ranges"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_check_size_range_id_fkey" FOREIGN KEY ("check_size_range_id") REFERENCES "public"."check_size_ranges"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_firm_id_fkey" FOREIGN KEY ("firm_id") REFERENCES "public"."firms"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_how_heard_id_fkey" FOREIGN KEY ("how_heard_id") REFERENCES "public"."referral_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_icebreaker_1_option_id_fkey" FOREIGN KEY ("icebreaker_1_option_id") REFERENCES "public"."icebreaker_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_icebreaker_2_option_id_fkey" FOREIGN KEY ("icebreaker_2_option_id") REFERENCES "public"."icebreaker_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_icebreaker_3_option_id_fkey" FOREIGN KEY ("icebreaker_3_option_id") REFERENCES "public"."icebreaker_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_intro_cadence_id_fkey" FOREIGN KEY ("intro_cadence_id") REFERENCES "public"."intro_cadence_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_job_title_id_fkey" FOREIGN KEY ("job_title_id") REFERENCES "public"."job_titles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_lifecycle_stage_id_fkey" FOREIGN KEY ("lifecycle_stage_id") REFERENCES "public"."lifecycle_stages"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."member_locations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_member_type_id_fkey" FOREIGN KEY ("member_type_id") REFERENCES "public"."member_types"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."regions"
    ADD CONSTRAINT "regions_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."regions"("id");



ALTER TABLE ONLY "public"."screening_applications"
    ADD CONSTRAINT "screening_applications_how_heard_id_fkey" FOREIGN KEY ("how_heard_id") REFERENCES "public"."referral_options"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sectors"
    ADD CONSTRAINT "sectors_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."sectors"("id");



ALTER TABLE ONLY "public"."service_provider_reviews"
    ADD CONSTRAINT "service_provider_reviews_reviewer_profile_id_fkey" FOREIGN KEY ("reviewer_profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."service_provider_reviews"
    ADD CONSTRAINT "service_provider_reviews_service_provider_id_fkey" FOREIGN KEY ("service_provider_id") REFERENCES "public"."service_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."service_providers"
    ADD CONSTRAINT "service_providers_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."service_provider_categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."service_providers"
    ADD CONSTRAINT "service_providers_created_by_profile_id_fkey" FOREIGN KEY ("created_by_profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."support_issue_links"
    ADD CONSTRAINT "support_issue_links_linear_issue_id_fkey" FOREIGN KEY ("linear_issue_id") REFERENCES "public"."linear_issues"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."support_issue_links"
    ADD CONSTRAINT "support_issue_links_linked_user_id_fkey" FOREIGN KEY ("linked_user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."support_issue_links"
    ADD CONSTRAINT "support_issue_links_zendesk_ticket_id_fkey" FOREIGN KEY ("zendesk_ticket_id") REFERENCES "public"."zendesk_tickets"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."support_tickets"
    ADD CONSTRAINT "support_tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_interested_firms"
    ADD CONSTRAINT "user_interested_firms_interested_profile_id_fkey" FOREIGN KEY ("interested_profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_interested_firms"
    ADD CONSTRAINT "user_interested_firms_target_firm_id_fkey" FOREIGN KEY ("target_firm_id") REFERENCES "public"."firms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users_roles"
    ADD CONSTRAINT "users_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users_roles"
    ADD CONSTRAINT "users_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can update applications" ON "public"."applicants" FOR UPDATE USING ((("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text"));



CREATE POLICY "Admins can view all applications" ON "public"."applicants" FOR SELECT USING ((("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text"));



CREATE POLICY "Allow admin full access" ON "public"."screening_applications" USING ((("auth"."jwt"() ->> 'role'::"text") = 'admin'::"text"));



CREATE POLICY "Allow all access to authenticated users" ON "public"."fortune_data_links" USING (("auth"."role"() = 'authenticated'::"text")) WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow all access to authenticated users" ON "public"."fortune_deals" USING (("auth"."role"() = 'authenticated'::"text")) WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow all access to authenticated users" ON "public"."investor_name_mappings" USING (("auth"."role"() = 'authenticated'::"text")) WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow anon read access to job titles" ON "public"."job_titles" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow anon read access to referral options" ON "public"."referral_options" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Allow applicant SELECT by valid token" ON "public"."applicants" FOR SELECT USING ((("signup_token" IS NOT NULL) AND ("token_expiry" > "now"()) AND ("token_used" = false) AND ("validation_attempts" < 5)));



CREATE POLICY "Allow authenticated CRUD access to community events" ON "public"."community_events" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read access" ON "public"."companies" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read access" ON "public"."service_provider_reviews" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read access" ON "public"."service_providers" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read access" ON "public"."slack_channels" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read access to AUM ranges" ON "public"."aum_ranges" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to Check Size ranges" ON "public"."check_size_ranges" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to access levels" ON "public"."access_levels" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to addevent_calendars" ON "public"."addevent_calendars" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to event types" ON "public"."event_type_enum" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to event_format_enum" ON "public"."event_format_enum" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to event_logistics_status_enum" ON "public"."event_logistics_status_enum" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to event_sponsorship_status_enu" ON "public"."event_sponsorship_status_enum" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to firm lead rounds" ON "public"."firm_lead_rounds" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to firm regions" ON "public"."firm_regions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to firm sectors" ON "public"."firm_sectors" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to firm_investment_rounds" ON "public"."firm_investment_rounds" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to firm_region_relationships" ON "public"."firm_region_relationships" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to firm_sector_relationships" ON "public"."firm_sector_relationships" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to firms" ON "public"."firms" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read access to intro preference options" ON "public"."intro_preferences_options" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to investment_rounds" ON "public"."investment_rounds" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to job titles" ON "public"."job_titles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to lifecycle stages" ON "public"."lifecycle_stages" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to member types" ON "public"."member_types" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to other profile data" ON "public"."profile_social_links" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to other profile images" ON "public"."profile_images" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to other profile professional d" ON "public"."profile_professional_details" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to referral options" ON "public"."referral_options" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to regions" ON "public"."regions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated read access to tags" ON "public"."tags" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated user read access to own memberships" ON "public"."memberships" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow authenticated user read access to own payments" ON "public"."payments" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow authenticated user read access to own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "Allow authenticated user update access to own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Allow authenticated users to select their own profile" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "Allow authenticated users to update their own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Allow full access to service_role" ON "public"."signup_tokens" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow individual delete access" ON "public"."profile_frontier_interests" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow individual insert access" ON "public"."profile_frontier_interests" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow individual read access" ON "public"."profile_frontier_interests" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow individual user SELECT access to own applicant record" ON "public"."applicants" FOR SELECT USING (("auth"."uid"() = "auth_user_id"));



CREATE POLICY "Allow individual user UPDATE access to own applicant record" ON "public"."applicants" FOR UPDATE USING (("auth"."uid"() = "auth_user_id"));



CREATE POLICY "Allow own delete on profile_intro_sectors" ON "public"."profile_intro_sectors" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own delete on profile_intro_stages" ON "public"."profile_intro_stages" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own delete on profile_match_sectors" ON "public"."profile_match_sectors" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own delete on profile_match_stages" ON "public"."profile_match_stages" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own insert on profile_intro_sectors" ON "public"."profile_intro_sectors" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own insert on profile_intro_stages" ON "public"."profile_intro_stages" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own insert on profile_match_sectors" ON "public"."profile_match_sectors" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own insert on profile_match_stages" ON "public"."profile_match_stages" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own select on profile_intro_sectors" ON "public"."profile_intro_sectors" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own select on profile_intro_stages" ON "public"."profile_intro_stages" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own select on profile_match_sectors" ON "public"."profile_match_sectors" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow own select on profile_match_stages" ON "public"."profile_match_stages" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow public submissions" ON "public"."screening_applications" FOR INSERT WITH CHECK (true);



CREATE POLICY "Allow read access to all users" ON "public"."job_locations" FOR SELECT USING (true);



CREATE POLICY "Allow read access to all users" ON "public"."job_titles" FOR SELECT USING (true);



CREATE POLICY "Allow read access to all users" ON "public"."service_provider_categories" FOR SELECT USING (true);



CREATE POLICY "Allow read access to all users" ON "public"."vc_firm_type" FOR SELECT USING (true);



CREATE POLICY "Allow service_role access" ON "public"."integration_logs" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service_role full access" ON "public"."companies" USING (("auth"."role"() = 'service_role'::"text")) WITH CHECK (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Allow service_role full access" ON "public"."linear_issues" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service_role full access" ON "public"."service_providers" USING (("auth"."role"() = 'service_role'::"text")) WITH CHECK (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Allow service_role full access" ON "public"."support_issue_links" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service_role full access" ON "public"."zendesk_tickets" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service_role full access" ON "public"."zendesk_users" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service_role modify access" ON "public"."slack_channels" USING (("auth"."role"() = 'service_role'::"text")) WITH CHECK (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Allow service_role read access" ON "public"."support_tickets" FOR SELECT USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Allow user CRUD on own event attendance" ON "public"."event_attendance" USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user CRUD on own interested firms" ON "public"."user_interested_firms" USING (("auth"."uid"() = "interested_profile_id")) WITH CHECK (("auth"."uid"() = "interested_profile_id"));



CREATE POLICY "Allow user delete access to own employment history" ON "public"."employment_history" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user delete access to own investments" ON "public"."investments" FOR DELETE USING (("auth"."uid"() = "investor_profile_id"));



CREATE POLICY "Allow user delete access to own postings" ON "public"."job_postings" FOR DELETE USING (("auth"."uid"() = "posted_by_profile_id"));



CREATE POLICY "Allow user delete access to own reviews" ON "public"."service_provider_reviews" FOR DELETE USING (("auth"."uid"() = "reviewer_profile_id"));



CREATE POLICY "Allow user delete access to own roles" ON "public"."profile_company_roles" FOR DELETE USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user full access to own connections" ON "public"."network_connections" USING (("auth"."uid"() = "user_id_1")) WITH CHECK (("auth"."uid"() = "user_id_1"));



CREATE POLICY "Allow user full access to own tickets" ON "public"."support_tickets" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow user insert access" ON "public"."job_postings" FOR INSERT WITH CHECK (("auth"."uid"() = "posted_by_profile_id"));



CREATE POLICY "Allow user insert access for own investments" ON "public"."investments" FOR INSERT WITH CHECK (("auth"."uid"() = "investor_profile_id"));



CREATE POLICY "Allow user insert access for own reviews" ON "public"."service_provider_reviews" FOR INSERT WITH CHECK (("auth"."uid"() = "reviewer_profile_id"));



CREATE POLICY "Allow user insert access for own roles" ON "public"."profile_company_roles" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user insert access to own employment history" ON "public"."employment_history" FOR INSERT WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user read access to own connections" ON "public"."network_connections" FOR SELECT USING (("auth"."uid"() = "user_id_1"));



CREATE POLICY "Allow user read access to own employment history" ON "public"."employment_history" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user read access to own investments" ON "public"."investments" FOR SELECT USING (("auth"."uid"() = "investor_profile_id"));



CREATE POLICY "Allow user read access to own roles" ON "public"."profile_company_roles" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user update access to own employment history" ON "public"."employment_history" FOR UPDATE USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow user update access to own investments" ON "public"."investments" FOR UPDATE USING (("auth"."uid"() = "investor_profile_id")) WITH CHECK (("auth"."uid"() = "investor_profile_id"));



CREATE POLICY "Allow user update access to own postings" ON "public"."job_postings" FOR UPDATE USING (("auth"."uid"() = "posted_by_profile_id")) WITH CHECK (("auth"."uid"() = "posted_by_profile_id"));



CREATE POLICY "Allow user update access to own reviews" ON "public"."service_provider_reviews" FOR UPDATE USING (("auth"."uid"() = "reviewer_profile_id")) WITH CHECK (("auth"."uid"() = "reviewer_profile_id"));



CREATE POLICY "Allow user update access to own roles" ON "public"."profile_company_roles" FOR UPDATE USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow users to insert interactions" ON "public"."addevent_interactions_log" FOR INSERT TO "authenticated" WITH CHECK ((("profile_id" = "auth"."uid"()) OR ("profile_id" IS NULL)));



CREATE POLICY "Allow users to manage their own calendar subscriptions" ON "public"."addevent_calendar_subscriptions" FOR INSERT TO "authenticated" WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to manage their own external identities" ON "public"."external_user_identities" TO "authenticated" USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow users to manage their own images" ON "public"."profile_images" TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to manage their own job title preferences" ON "public"."profile_job_title_preferences" USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow users to manage their own location preferences" ON "public"."profile_job_location_preferences" USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow users to manage their own preferences" ON "public"."profile_preferences" TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to manage their own professional details" ON "public"."profile_professional_details" TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to manage their own sector focuses" ON "public"."profile_sector_focuses" TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to manage their own sector preferences" ON "public"."profile_sector_preferences" USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow users to manage their own social links" ON "public"."profile_social_links" TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to manage their own stage focuses" ON "public"."profile_stage_focuses" TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to manage their own stage preferences" ON "public"."profile_stage_preferences" USING (("auth"."uid"() = "profile_id")) WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Allow users to manage their own thematic interests" ON "public"."profile_thematic_interests" TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to update their own calendar subscriptions" ON "public"."addevent_calendar_subscriptions" FOR UPDATE TO "authenticated" USING (("profile_id" = "auth"."uid"())) WITH CHECK (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to view their own calendar subscriptions" ON "public"."addevent_calendar_subscriptions" FOR SELECT TO "authenticated" USING (("profile_id" = "auth"."uid"()));



CREATE POLICY "Allow users to view their own interactions" ON "public"."addevent_interactions_log" FOR SELECT TO "authenticated" USING ((("profile_id" = "auth"."uid"()) OR ("profile_id" IS NULL)));



CREATE POLICY "Anyone can submit an application" ON "public"."applicants" FOR INSERT WITH CHECK (true);



CREATE POLICY "Deny all access to audit logs" ON "public"."audit_logs" USING (false);



CREATE POLICY "Disallow direct modification" ON "public"."integration_logs" USING (false) WITH CHECK (false);



CREATE POLICY "Enable delete for own records" ON "public"."profile_community_sectors" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Enable delete for own records" ON "public"."profile_interest_communities" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Enable insert for authenticated users" ON "public"."profile_community_sectors" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Enable insert for authenticated users" ON "public"."profile_interest_communities" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "profile_id"));



CREATE POLICY "Enable read access for all users" ON "public"."board_roles" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."frontier_interests" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."icebreaker_options" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."interest_communities" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."intro_cadence_options" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."investment_stages" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."job_postings" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."member_locations" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."profile_community_sectors" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."profile_interest_communities" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."profile_sector_focuses" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."sectors" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."thematic_areas" FOR SELECT USING (true);



CREATE POLICY "Enable service role access" ON "public"."profile_sector_focuses" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Public can view roles" ON "public"."roles" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Public can view users_roles" ON "public"."users_roles" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Service role can delete roles" ON "public"."roles" FOR DELETE TO "service_role" USING (true);



CREATE POLICY "Service role can delete users_roles" ON "public"."users_roles" FOR DELETE TO "service_role" USING (true);



CREATE POLICY "Service role can insert roles" ON "public"."roles" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Service role can insert users_roles" ON "public"."users_roles" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Service role can update roles" ON "public"."roles" FOR UPDATE TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Service role can update users_roles" ON "public"."users_roles" FOR UPDATE TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



ALTER TABLE "public"."access_levels" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."addevent_calendar_subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."addevent_calendars" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."addevent_interactions_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."applicants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."aum_ranges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."board_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."check_size_ranges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."companies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."employment_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_attendance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_format_enum" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_logistics_status_enum" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_sponsorship_status_enum" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_type_enum" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."external_user_identities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."firm_investment_rounds" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."firm_lead_rounds" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."firm_region_relationships" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."firm_regions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."firm_sector_relationships" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."firm_sectors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."firms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."frontier_interests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."icebreaker_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."integration_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."interest_communities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."intro_cadence_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."intro_preferences_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."investment_rounds" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."investment_stages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."investments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."investor_name_mappings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."job_locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."job_postings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."job_titles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."lifecycle_stages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."linear_issues" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."member_locations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."member_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."memberships" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."network_connections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."onboarding_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_community_sectors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_company_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_frontier_interests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_interest_communities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_intro_sectors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_intro_stages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_job_location_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_job_title_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_match_sectors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_match_stages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_professional_details" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_sector_focuses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_sector_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_social_links" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_stage_focuses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_stage_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_thematic_interests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select_policy" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "profiles_update_policy" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."referral_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."regions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sectors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."service_provider_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."service_provider_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."service_providers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."signup_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."slack_channels" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."support_issue_links" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."support_tickets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thematic_areas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_interested_firms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vc_firm_type" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."zendesk_tickets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."zendesk_users" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON TYPE "public"."event_location_type_enum" TO "anon";
GRANT ALL ON TYPE "public"."event_location_type_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."event_location_type_enum" TO "service_role";



GRANT ALL ON TYPE "public"."event_rsvp_status_enum" TO "anon";
GRANT ALL ON TYPE "public"."event_rsvp_status_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."event_rsvp_status_enum" TO "service_role";



GRANT ALL ON TYPE "public"."event_status_enum" TO "anon";
GRANT ALL ON TYPE "public"."event_status_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."event_status_enum" TO "service_role";



GRANT ALL ON TYPE "public"."job_title_enum" TO "anon";
GRANT ALL ON TYPE "public"."job_title_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."job_title_enum" TO "service_role";



GRANT ALL ON TYPE "public"."membership_status_enum" TO "anon";
GRANT ALL ON TYPE "public"."membership_status_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."membership_status_enum" TO "service_role";



GRANT ALL ON TYPE "public"."network_connection_status" TO "anon";
GRANT ALL ON TYPE "public"."network_connection_status" TO "authenticated";
GRANT ALL ON TYPE "public"."network_connection_status" TO "service_role";



GRANT ALL ON TYPE "public"."payment_status_enum" TO "anon";
GRANT ALL ON TYPE "public"."payment_status_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."payment_status_enum" TO "service_role";



GRANT ALL ON TYPE "public"."screening_status_enum" TO "anon";
GRANT ALL ON TYPE "public"."screening_status_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."screening_status_enum" TO "service_role";



GRANT ALL ON TYPE "public"."slack_channel_geo" TO "anon";
GRANT ALL ON TYPE "public"."slack_channel_geo" TO "authenticated";
GRANT ALL ON TYPE "public"."slack_channel_geo" TO "service_role";



GRANT ALL ON TYPE "public"."slack_channel_type" TO "anon";
GRANT ALL ON TYPE "public"."slack_channel_type" TO "authenticated";
GRANT ALL ON TYPE "public"."slack_channel_type" TO "service_role";



GRANT ALL ON TYPE "public"."support_ticket_status" TO "anon";
GRANT ALL ON TYPE "public"."support_ticket_status" TO "authenticated";
GRANT ALL ON TYPE "public"."support_ticket_status" TO "service_role";



GRANT ALL ON TYPE "public"."user_status_enum" TO "anon";
GRANT ALL ON TYPE "public"."user_status_enum" TO "authenticated";
GRANT ALL ON TYPE "public"."user_status_enum" TO "service_role";



GRANT ALL ON FUNCTION "public"."audit_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."audit_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."audit_changes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_service_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_service_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_service_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_strong_password"("password" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_strong_password"("password" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_strong_password"("password" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_logo_url_from_website"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_logo_url_from_website"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_logo_url_from_website"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_auth_users"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_auth_users"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_auth_users"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_complete_schema"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_complete_schema"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_complete_schema"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_domain_from_url"("url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_domain_from_url"("url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_domain_from_url"("url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_email_config"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_email_config"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_email_config"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_users_with_profiles"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_users_with_profiles"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_users_with_profiles"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_application"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_application"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_application"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_profile_related_records"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_profile_related_records"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_profile_related_records"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_token_attempts"("token_param" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_token_attempts"("token_param" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_token_attempts"("token_param" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_stage_tag"("tag_id_to_check" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_stage_tag"("tag_id_to_check" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_stage_tag"("tag_id_to_check" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."maintenance_analyze_database"() TO "anon";
GRANT ALL ON FUNCTION "public"."maintenance_analyze_database"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."maintenance_analyze_database"() TO "service_role";



GRANT ALL ON FUNCTION "public"."maintenance_archive_old_data"("older_than_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."maintenance_archive_old_data"("older_than_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."maintenance_archive_old_data"("older_than_days" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."maintenance_reindex_fragmented_tables"("max_fragmentation_percent" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."maintenance_reindex_fragmented_tables"("max_fragmentation_percent" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."maintenance_reindex_fragmented_tables"("max_fragmentation_percent" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."maintenance_vacuum_tables"("max_dead_tuples" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."maintenance_vacuum_tables"("max_dead_tuples" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."maintenance_vacuum_tables"("max_dead_tuples" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."mask_sensitive_data"("input_text" "text", "mask_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."mask_sensitive_data"("input_text" "text", "mask_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mask_sensitive_data"("input_text" "text", "mask_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."monitoring_detect_missing_indexes"() TO "anon";
GRANT ALL ON FUNCTION "public"."monitoring_detect_missing_indexes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."monitoring_detect_missing_indexes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."monitoring_detect_unused_indexes"() TO "anon";
GRANT ALL ON FUNCTION "public"."monitoring_detect_unused_indexes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."monitoring_detect_unused_indexes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."normalize_entity_name"("name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."normalize_entity_name"("name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_entity_name"("name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_self_connections"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_self_connections"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_self_connections"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_materialized_views"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_materialized_views"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_materialized_views"() TO "service_role";



GRANT ALL ON FUNCTION "public"."run_scheduled_maintenance"() TO "anon";
GRANT ALL ON FUNCTION "public"."run_scheduled_maintenance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."run_scheduled_maintenance"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_event_format_from_location_type"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_event_format_from_location_type"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_event_format_from_location_type"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."to_unix_timestamp"("ts" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."to_unix_timestamp"("ts" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."to_unix_timestamp"("ts" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_audit_profiles"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_audit_profiles"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_audit_profiles"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_addevent_calendar_subscriptions_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_addevent_calendar_subscriptions_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_addevent_calendar_subscriptions_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_addevent_calendars_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_addevent_calendars_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_addevent_calendars_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_customerio_config"("p_api_key" "text", "p_site_id" "text", "p_sender_name" "text", "p_sender_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_customerio_config"("p_api_key" "text", "p_site_id" "text", "p_sender_name" "text", "p_sender_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_customerio_config"("p_api_key" "text", "p_site_id" "text", "p_sender_name" "text", "p_sender_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_event_attendance_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_event_attendance_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_event_attendance_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_event_dates"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_event_dates"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_event_dates"() TO "service_role";



GRANT ALL ON TABLE "public"."access_levels" TO "anon";
GRANT ALL ON TABLE "public"."access_levels" TO "authenticated";
GRANT ALL ON TABLE "public"."access_levels" TO "service_role";



GRANT ALL ON TABLE "public"."addevent_calendar_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."addevent_calendar_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."addevent_calendar_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."addevent_calendars" TO "anon";
GRANT ALL ON TABLE "public"."addevent_calendars" TO "authenticated";
GRANT ALL ON TABLE "public"."addevent_calendars" TO "service_role";



GRANT ALL ON TABLE "public"."addevent_integration" TO "anon";
GRANT ALL ON TABLE "public"."addevent_integration" TO "authenticated";
GRANT ALL ON TABLE "public"."addevent_integration" TO "service_role";



GRANT ALL ON TABLE "public"."addevent_interactions_log" TO "anon";
GRANT ALL ON TABLE "public"."addevent_interactions_log" TO "authenticated";
GRANT ALL ON TABLE "public"."addevent_interactions_log" TO "service_role";



GRANT ALL ON SEQUENCE "public"."addevent_interactions_log_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."addevent_interactions_log_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."addevent_interactions_log_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."applicant_firms" TO "anon";
GRANT ALL ON TABLE "public"."applicant_firms" TO "authenticated";
GRANT ALL ON TABLE "public"."applicant_firms" TO "service_role";



GRANT ALL ON TABLE "public"."applicants" TO "anon";
GRANT ALL ON TABLE "public"."applicants" TO "authenticated";
GRANT ALL ON TABLE "public"."applicants" TO "service_role";



GRANT ALL ON TABLE "public"."application_logs" TO "anon";
GRANT ALL ON TABLE "public"."application_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."application_logs" TO "service_role";



GRANT ALL ON TABLE "public"."application_questions" TO "anon";
GRANT ALL ON TABLE "public"."application_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."application_questions" TO "service_role";



GRANT ALL ON TABLE "public"."application_responses" TO "anon";
GRANT ALL ON TABLE "public"."application_responses" TO "authenticated";
GRANT ALL ON TABLE "public"."application_responses" TO "service_role";



GRANT ALL ON TABLE "public"."audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."audit_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."audit_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."audit_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."aum_ranges" TO "anon";
GRANT ALL ON TABLE "public"."aum_ranges" TO "authenticated";
GRANT ALL ON TABLE "public"."aum_ranges" TO "service_role";



GRANT ALL ON TABLE "public"."auth_settings_documentation" TO "anon";
GRANT ALL ON TABLE "public"."auth_settings_documentation" TO "authenticated";
GRANT ALL ON TABLE "public"."auth_settings_documentation" TO "service_role";



GRANT ALL ON TABLE "public"."board_roles" TO "anon";
GRANT ALL ON TABLE "public"."board_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."board_roles" TO "service_role";



GRANT ALL ON TABLE "public"."check_size_ranges" TO "anon";
GRANT ALL ON TABLE "public"."check_size_ranges" TO "authenticated";
GRANT ALL ON TABLE "public"."check_size_ranges" TO "service_role";



GRANT ALL ON TABLE "public"."community_events" TO "anon";
GRANT ALL ON TABLE "public"."community_events" TO "authenticated";
GRANT ALL ON TABLE "public"."community_events" TO "service_role";



GRANT ALL ON TABLE "public"."community_events_full" TO "anon";
GRANT ALL ON TABLE "public"."community_events_full" TO "authenticated";
GRANT ALL ON TABLE "public"."community_events_full" TO "service_role";



GRANT ALL ON TABLE "public"."companies" TO "anon";
GRANT ALL ON TABLE "public"."companies" TO "authenticated";
GRANT ALL ON TABLE "public"."companies" TO "service_role";



GRANT ALL ON TABLE "public"."email_config" TO "anon";
GRANT ALL ON TABLE "public"."email_config" TO "authenticated";
GRANT ALL ON TABLE "public"."email_config" TO "service_role";



GRANT ALL ON SEQUENCE "public"."email_config_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."email_config_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."email_config_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."employment_history" TO "anon";
GRANT ALL ON TABLE "public"."employment_history" TO "authenticated";
GRANT ALL ON TABLE "public"."employment_history" TO "service_role";



GRANT ALL ON TABLE "public"."event_attendance" TO "anon";
GRANT ALL ON TABLE "public"."event_attendance" TO "authenticated";
GRANT ALL ON TABLE "public"."event_attendance" TO "service_role";



GRANT ALL ON TABLE "public"."event_format_enum" TO "anon";
GRANT ALL ON TABLE "public"."event_format_enum" TO "authenticated";
GRANT ALL ON TABLE "public"."event_format_enum" TO "service_role";



GRANT ALL ON TABLE "public"."event_logistics_status_enum" TO "anon";
GRANT ALL ON TABLE "public"."event_logistics_status_enum" TO "authenticated";
GRANT ALL ON TABLE "public"."event_logistics_status_enum" TO "service_role";



GRANT ALL ON TABLE "public"."event_sponsorship_status_enum" TO "anon";
GRANT ALL ON TABLE "public"."event_sponsorship_status_enum" TO "authenticated";
GRANT ALL ON TABLE "public"."event_sponsorship_status_enum" TO "service_role";



GRANT ALL ON TABLE "public"."event_type_enum" TO "anon";
GRANT ALL ON TABLE "public"."event_type_enum" TO "authenticated";
GRANT ALL ON TABLE "public"."event_type_enum" TO "service_role";



GRANT ALL ON TABLE "public"."external_user_identities" TO "anon";
GRANT ALL ON TABLE "public"."external_user_identities" TO "authenticated";
GRANT ALL ON TABLE "public"."external_user_identities" TO "service_role";



GRANT ALL ON TABLE "public"."firm_investment_rounds" TO "anon";
GRANT ALL ON TABLE "public"."firm_investment_rounds" TO "authenticated";
GRANT ALL ON TABLE "public"."firm_investment_rounds" TO "service_role";



GRANT ALL ON TABLE "public"."firm_lead_rounds" TO "anon";
GRANT ALL ON TABLE "public"."firm_lead_rounds" TO "authenticated";
GRANT ALL ON TABLE "public"."firm_lead_rounds" TO "service_role";



GRANT ALL ON TABLE "public"."firm_region_relationships" TO "anon";
GRANT ALL ON TABLE "public"."firm_region_relationships" TO "authenticated";
GRANT ALL ON TABLE "public"."firm_region_relationships" TO "service_role";



GRANT ALL ON TABLE "public"."firm_regions" TO "anon";
GRANT ALL ON TABLE "public"."firm_regions" TO "authenticated";
GRANT ALL ON TABLE "public"."firm_regions" TO "service_role";



GRANT ALL ON TABLE "public"."firm_sector_relationships" TO "anon";
GRANT ALL ON TABLE "public"."firm_sector_relationships" TO "authenticated";
GRANT ALL ON TABLE "public"."firm_sector_relationships" TO "service_role";



GRANT ALL ON TABLE "public"."firm_sectors" TO "anon";
GRANT ALL ON TABLE "public"."firm_sectors" TO "authenticated";
GRANT ALL ON TABLE "public"."firm_sectors" TO "service_role";



GRANT ALL ON TABLE "public"."firms" TO "anon";
GRANT ALL ON TABLE "public"."firms" TO "authenticated";
GRANT ALL ON TABLE "public"."firms" TO "service_role";



GRANT ALL ON TABLE "public"."fortune_data_links" TO "anon";
GRANT ALL ON TABLE "public"."fortune_data_links" TO "authenticated";
GRANT ALL ON TABLE "public"."fortune_data_links" TO "service_role";



GRANT ALL ON TABLE "public"."fortune_deals" TO "anon";
GRANT ALL ON TABLE "public"."fortune_deals" TO "authenticated";
GRANT ALL ON TABLE "public"."fortune_deals" TO "service_role";



GRANT ALL ON TABLE "public"."frontier_interests" TO "anon";
GRANT ALL ON TABLE "public"."frontier_interests" TO "authenticated";
GRANT ALL ON TABLE "public"."frontier_interests" TO "service_role";



GRANT ALL ON TABLE "public"."icebreaker_options" TO "anon";
GRANT ALL ON TABLE "public"."icebreaker_options" TO "authenticated";
GRANT ALL ON TABLE "public"."icebreaker_options" TO "service_role";



GRANT ALL ON TABLE "public"."integration_logs" TO "anon";
GRANT ALL ON TABLE "public"."integration_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."integration_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."integration_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."integration_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."integration_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."interest_communities" TO "anon";
GRANT ALL ON TABLE "public"."interest_communities" TO "authenticated";
GRANT ALL ON TABLE "public"."interest_communities" TO "service_role";



GRANT ALL ON TABLE "public"."intro_cadence_options" TO "anon";
GRANT ALL ON TABLE "public"."intro_cadence_options" TO "authenticated";
GRANT ALL ON TABLE "public"."intro_cadence_options" TO "service_role";



GRANT ALL ON TABLE "public"."intro_preferences_options" TO "anon";
GRANT ALL ON TABLE "public"."intro_preferences_options" TO "authenticated";
GRANT ALL ON TABLE "public"."intro_preferences_options" TO "service_role";



GRANT ALL ON TABLE "public"."investment_rounds" TO "anon";
GRANT ALL ON TABLE "public"."investment_rounds" TO "authenticated";
GRANT ALL ON TABLE "public"."investment_rounds" TO "service_role";



GRANT ALL ON TABLE "public"."investment_stages" TO "anon";
GRANT ALL ON TABLE "public"."investment_stages" TO "authenticated";
GRANT ALL ON TABLE "public"."investment_stages" TO "service_role";



GRANT ALL ON TABLE "public"."investments" TO "anon";
GRANT ALL ON TABLE "public"."investments" TO "authenticated";
GRANT ALL ON TABLE "public"."investments" TO "service_role";



GRANT ALL ON TABLE "public"."investor_name_mappings" TO "anon";
GRANT ALL ON TABLE "public"."investor_name_mappings" TO "authenticated";
GRANT ALL ON TABLE "public"."investor_name_mappings" TO "service_role";



GRANT ALL ON TABLE "public"."job_locations" TO "anon";
GRANT ALL ON TABLE "public"."job_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."job_locations" TO "service_role";



GRANT ALL ON SEQUENCE "public"."job_locations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."job_locations_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."job_locations_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."job_postings" TO "anon";
GRANT ALL ON TABLE "public"."job_postings" TO "authenticated";
GRANT ALL ON TABLE "public"."job_postings" TO "service_role";



GRANT ALL ON TABLE "public"."job_titles" TO "anon";
GRANT ALL ON TABLE "public"."job_titles" TO "authenticated";
GRANT ALL ON TABLE "public"."job_titles" TO "service_role";



GRANT ALL ON TABLE "public"."lifecycle_stages" TO "anon";
GRANT ALL ON TABLE "public"."lifecycle_stages" TO "authenticated";
GRANT ALL ON TABLE "public"."lifecycle_stages" TO "service_role";



GRANT ALL ON TABLE "public"."linear_issues" TO "anon";
GRANT ALL ON TABLE "public"."linear_issues" TO "authenticated";
GRANT ALL ON TABLE "public"."linear_issues" TO "service_role";



GRANT ALL ON TABLE "public"."member_locations" TO "anon";
GRANT ALL ON TABLE "public"."member_locations" TO "authenticated";
GRANT ALL ON TABLE "public"."member_locations" TO "service_role";



GRANT ALL ON TABLE "public"."member_types" TO "anon";
GRANT ALL ON TABLE "public"."member_types" TO "authenticated";
GRANT ALL ON TABLE "public"."member_types" TO "service_role";



GRANT ALL ON TABLE "public"."memberships" TO "anon";
GRANT ALL ON TABLE "public"."memberships" TO "authenticated";
GRANT ALL ON TABLE "public"."memberships" TO "service_role";



GRANT ALL ON TABLE "public"."monitoring_slow_queries" TO "anon";
GRANT ALL ON TABLE "public"."monitoring_slow_queries" TO "authenticated";
GRANT ALL ON TABLE "public"."monitoring_slow_queries" TO "service_role";



GRANT ALL ON TABLE "public"."monitoring_table_access" TO "anon";
GRANT ALL ON TABLE "public"."monitoring_table_access" TO "authenticated";
GRANT ALL ON TABLE "public"."monitoring_table_access" TO "service_role";



GRANT ALL ON TABLE "public"."monitoring_table_bloat" TO "anon";
GRANT ALL ON TABLE "public"."monitoring_table_bloat" TO "authenticated";
GRANT ALL ON TABLE "public"."monitoring_table_bloat" TO "service_role";



GRANT ALL ON TABLE "public"."network_connections" TO "anon";
GRANT ALL ON TABLE "public"."network_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."network_connections" TO "service_role";



GRANT ALL ON TABLE "public"."onboarding_progress" TO "anon";
GRANT ALL ON TABLE "public"."onboarding_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."onboarding_progress" TO "service_role";



GRANT ALL ON TABLE "public"."payments" TO "anon";
GRANT ALL ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";



GRANT ALL ON TABLE "public"."profile_community_sectors" TO "anon";
GRANT ALL ON TABLE "public"."profile_community_sectors" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_community_sectors" TO "service_role";



GRANT ALL ON TABLE "public"."profile_company_roles" TO "anon";
GRANT ALL ON TABLE "public"."profile_company_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_company_roles" TO "service_role";



GRANT ALL ON TABLE "public"."profile_frontier_interests" TO "anon";
GRANT ALL ON TABLE "public"."profile_frontier_interests" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_frontier_interests" TO "service_role";



GRANT ALL ON TABLE "public"."profile_images" TO "anon";
GRANT ALL ON TABLE "public"."profile_images" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_images" TO "service_role";



GRANT ALL ON TABLE "public"."profile_interest_communities" TO "anon";
GRANT ALL ON TABLE "public"."profile_interest_communities" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_interest_communities" TO "service_role";



GRANT ALL ON TABLE "public"."profile_intro_sectors" TO "anon";
GRANT ALL ON TABLE "public"."profile_intro_sectors" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_intro_sectors" TO "service_role";



GRANT ALL ON TABLE "public"."profile_intro_stages" TO "anon";
GRANT ALL ON TABLE "public"."profile_intro_stages" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_intro_stages" TO "service_role";



GRANT ALL ON TABLE "public"."profile_job_location_preferences" TO "anon";
GRANT ALL ON TABLE "public"."profile_job_location_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_job_location_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."profile_job_title_preferences" TO "anon";
GRANT ALL ON TABLE "public"."profile_job_title_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_job_title_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."profile_match_sectors" TO "anon";
GRANT ALL ON TABLE "public"."profile_match_sectors" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_match_sectors" TO "service_role";



GRANT ALL ON TABLE "public"."profile_match_stages" TO "anon";
GRANT ALL ON TABLE "public"."profile_match_stages" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_match_stages" TO "service_role";



GRANT ALL ON TABLE "public"."profile_preferences" TO "anon";
GRANT ALL ON TABLE "public"."profile_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."sectors" TO "anon";
GRANT ALL ON TABLE "public"."sectors" TO "authenticated";
GRANT ALL ON TABLE "public"."sectors" TO "service_role";



GRANT ALL ON TABLE "public"."profile_preferences_view" TO "anon";
GRANT ALL ON TABLE "public"."profile_preferences_view" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_preferences_view" TO "service_role";



GRANT ALL ON TABLE "public"."profile_professional_details" TO "anon";
GRANT ALL ON TABLE "public"."profile_professional_details" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_professional_details" TO "service_role";



GRANT ALL ON TABLE "public"."profile_sector_focuses" TO "anon";
GRANT ALL ON TABLE "public"."profile_sector_focuses" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_sector_focuses" TO "service_role";



GRANT ALL ON TABLE "public"."profile_sector_preferences" TO "anon";
GRANT ALL ON TABLE "public"."profile_sector_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_sector_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."profile_social_links" TO "anon";
GRANT ALL ON TABLE "public"."profile_social_links" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_social_links" TO "service_role";



GRANT ALL ON TABLE "public"."profile_stage_focuses" TO "anon";
GRANT ALL ON TABLE "public"."profile_stage_focuses" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_stage_focuses" TO "service_role";



GRANT ALL ON TABLE "public"."profile_stage_preferences" TO "anon";
GRANT ALL ON TABLE "public"."profile_stage_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_stage_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."profile_thematic_interests" TO "anon";
GRANT ALL ON TABLE "public"."profile_thematic_interests" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_thematic_interests" TO "service_role";



GRANT ALL ON TABLE "public"."profile_track_record_companies" TO "anon";
GRANT ALL ON TABLE "public"."profile_track_record_companies" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_track_record_companies" TO "service_role";



GRANT ALL ON TABLE "public"."referral_options" TO "anon";
GRANT ALL ON TABLE "public"."referral_options" TO "authenticated";
GRANT ALL ON TABLE "public"."referral_options" TO "service_role";



GRANT ALL ON TABLE "public"."regions" TO "anon";
GRANT ALL ON TABLE "public"."regions" TO "authenticated";
GRANT ALL ON TABLE "public"."regions" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON TABLE "public"."scrape_tracking" TO "anon";
GRANT ALL ON TABLE "public"."scrape_tracking" TO "authenticated";
GRANT ALL ON TABLE "public"."scrape_tracking" TO "service_role";



GRANT ALL ON SEQUENCE "public"."scrape_tracking_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."scrape_tracking_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."scrape_tracking_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."screening_applications" TO "anon";
GRANT ALL ON TABLE "public"."screening_applications" TO "authenticated";
GRANT ALL ON TABLE "public"."screening_applications" TO "service_role";



GRANT ALL ON TABLE "public"."service_provider_categories" TO "anon";
GRANT ALL ON TABLE "public"."service_provider_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."service_provider_categories" TO "service_role";



GRANT ALL ON SEQUENCE "public"."service_provider_categories_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."service_provider_categories_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."service_provider_categories_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."service_provider_reviews" TO "anon";
GRANT ALL ON TABLE "public"."service_provider_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."service_provider_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."service_providers" TO "anon";
GRANT ALL ON TABLE "public"."service_providers" TO "authenticated";
GRANT ALL ON TABLE "public"."service_providers" TO "service_role";



GRANT ALL ON TABLE "public"."signup_tokens" TO "anon";
GRANT ALL ON TABLE "public"."signup_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."signup_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."slack_channels" TO "anon";
GRANT ALL ON TABLE "public"."slack_channels" TO "authenticated";
GRANT ALL ON TABLE "public"."slack_channels" TO "service_role";



GRANT ALL ON TABLE "public"."support_issue_links" TO "anon";
GRANT ALL ON TABLE "public"."support_issue_links" TO "authenticated";
GRANT ALL ON TABLE "public"."support_issue_links" TO "service_role";



GRANT ALL ON TABLE "public"."support_tickets" TO "anon";
GRANT ALL ON TABLE "public"."support_tickets" TO "authenticated";
GRANT ALL ON TABLE "public"."support_tickets" TO "service_role";



GRANT ALL ON TABLE "public"."tags" TO "anon";
GRANT ALL ON TABLE "public"."tags" TO "authenticated";
GRANT ALL ON TABLE "public"."tags" TO "service_role";



GRANT ALL ON TABLE "public"."thematic_areas" TO "anon";
GRANT ALL ON TABLE "public"."thematic_areas" TO "authenticated";
GRANT ALL ON TABLE "public"."thematic_areas" TO "service_role";



GRANT ALL ON TABLE "public"."track_record_comprehensive_view" TO "anon";
GRANT ALL ON TABLE "public"."track_record_comprehensive_view" TO "authenticated";
GRANT ALL ON TABLE "public"."track_record_comprehensive_view" TO "service_role";



GRANT ALL ON TABLE "public"."user_interested_firms" TO "anon";
GRANT ALL ON TABLE "public"."user_interested_firms" TO "authenticated";
GRANT ALL ON TABLE "public"."user_interested_firms" TO "service_role";



GRANT ALL ON TABLE "public"."users_roles" TO "anon";
GRANT ALL ON TABLE "public"."users_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."users_roles" TO "service_role";



GRANT ALL ON TABLE "public"."vc_firm_type" TO "anon";
GRANT ALL ON TABLE "public"."vc_firm_type" TO "authenticated";
GRANT ALL ON TABLE "public"."vc_firm_type" TO "service_role";



GRANT ALL ON SEQUENCE "public"."vc_firm_type_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vc_firm_type_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vc_firm_type_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."zendesk_tickets" TO "anon";
GRANT ALL ON TABLE "public"."zendesk_tickets" TO "authenticated";
GRANT ALL ON TABLE "public"."zendesk_tickets" TO "service_role";



GRANT ALL ON TABLE "public"."zendesk_users" TO "anon";
GRANT ALL ON TABLE "public"."zendesk_users" TO "authenticated";
GRANT ALL ON TABLE "public"."zendesk_users" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TYPES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TYPES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TYPES  TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






RESET ALL;
