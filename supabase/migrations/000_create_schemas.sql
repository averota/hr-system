-- Stage 0: schema layout
--   core    : business tables (tenant, company, hierarchy, allocation ...)
--   private : helper functions used by RLS policies and triggers
--   public  : thin views / RPC functions called by the frontend (already exists)
--
-- core and private are NOT added to the API "exposed schemas" list,
-- so the browser can never query them directly.

create schema if not exists core;
create schema if not exists private;

-- anon (not logged in) gets nothing in either schema.
revoke all on schema core from public, anon;
revoke all on schema private from public, anon;

-- Logged-in users need schema USAGE so that security_invoker views in
-- public can read core tables. Table-level GRANTs and RLS policies are
-- added per table in later stages; USAGE alone gives access to nothing.
grant usage on schema core to authenticated, service_role;
grant usage on schema private to authenticated, service_role;

-- Functions are executable by everyone by default in Postgres.
-- Change that default for these two schemas: access must be granted explicitly.
alter default privileges in schema core
  revoke execute on functions from public, anon;
alter default privileges in schema private
  revoke execute on functions from public, anon;
