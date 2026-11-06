-- 014: close one allocation (ORG Stage 9c-1)
--
-- One controlled way to close a single allocation. This is the missing
-- "close one allocation" function: allocations are never edited, so a headcount
-- change = close the allocation, then create a new one (private.create_allocation).
--
-- The allocation guard (006) already allows closing by setting valid_to.
-- This function adds what the guard cannot:
--   * the allocation must be open and belong to the stated company
--   * a close date earlier than the allocation's start is refused with a clear
--     message (instead of a raw check-constraint error)
--   * the row is locked while closing
--
-- Closing an allocation does not touch the org unit, the Department listing,
-- the job or the position unit.
--
-- p_close_date defaults to today (server date, UTC). Pass it explicitly from the
-- frontend when the user picks a date. Not exposed to the frontend yet:
-- service_role only, like the other write functions.

create function private.close_allocation(
  p_company_id     integer,
  p_allocation_id  integer,
  p_close_date     date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_from date;
begin
  select valid_from into v_from
  from core.position_allocation
  where id = p_allocation_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Allocation % is not an open allocation of this company', p_allocation_id;
  end if;

  if p_close_date < v_from then
    raise exception 'Close date % is earlier than %, when this allocation started',
      p_close_date, v_from;
  end if;

  update core.position_allocation
  set valid_to = p_close_date
  where id = p_allocation_id;
end;
$$;

revoke execute on function private.close_allocation(integer, integer, date)
  from public, anon, authenticated;
grant execute on function private.close_allocation(integer, integer, date)
  to service_role;
