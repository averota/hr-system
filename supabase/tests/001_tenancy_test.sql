-- Test for 001_tenancy.sql
-- Run in Supabase Dashboard -> SQL Editor (dev project only).
-- Everything is rolled back at the end; nothing is saved.
--
-- PASS = "Success. No rows returned"
-- FAIL = an error message that starts with FAIL

begin;

-- Fixtures: two fake users, two tenants, one company each
insert into auth.users
  (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'authenticated', 'authenticated', 'user_a@test.local', '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'authenticated', 'authenticated', 'user_b@test.local', '{}', '{}', now(), now());

insert into core.tenant (name_en) values ('Tenant A'), ('Tenant B');

insert into core.parent_company (tenant_id, name_en)
select id, 'Company of ' || name_en from core.tenant;

insert into core.tenant_member (tenant_id, user_id)
select id,
       case name_en
         when 'Tenant A' then 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
         else 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
       end
from core.tenant;

-- Act as a logged-in user
set local role authenticated;

do $$
declare
  v_names text;
  v_count integer;
begin
  -- ---------- User A ----------
  perform set_config('request.jwt.claims',
    '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}', true);

  select string_agg(name_en, ', ') into v_names from core.tenant;
  if v_names is distinct from 'Tenant A' then
    raise exception 'FAIL: user A sees tenants [%], expected [Tenant A]', v_names;
  end if;

  select string_agg(name_en, ', ') into v_names from core.parent_company;
  if v_names is distinct from 'Company of Tenant A' then
    raise exception 'FAIL: user A sees companies [%], expected [Company of Tenant A]', v_names;
  end if;

  select count(*) into v_count from core.tenant_member;
  if v_count <> 1 then
    raise exception 'FAIL: user A sees % membership rows, expected 1', v_count;
  end if;

  -- Writes must be blocked
  begin
    insert into core.tenant (name_en) values ('Hack');
    raise exception 'FAIL: user A was able to insert a tenant';
  exception when insufficient_privilege then
    null;
  end;

  -- ---------- User B ----------
  perform set_config('request.jwt.claims',
    '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);

  select string_agg(name_en, ', ') into v_names from core.tenant;
  if v_names is distinct from 'Tenant B' then
    raise exception 'FAIL: user B sees tenants [%], expected [Tenant B]', v_names;
  end if;

  -- ---------- Not logged in as anyone ----------
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);

  select count(*) into v_count from core.tenant;
  if v_count <> 0 then
    raise exception 'FAIL: user with no identity sees % tenants, expected 0', v_count;
  end if;
end $$;

rollback;
