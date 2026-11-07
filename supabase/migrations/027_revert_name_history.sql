-- 027: revert name history (ORG Stage 9j)
--
-- Decision: a corrected name must show everywhere, regardless of date.
-- So the name columns on org_unit, pos_unit and job_position stay the only
-- source of names, and the history of names is removed.
--
-- Removes Part A of 026: the three triggers, the trigger function and
-- core.name_history (its indexes and policy go with the table).
--
-- Keeps Part B of 026: private.create_org_unit and private.create_pos_unit
-- still trim names and refuse a blank English name.
--
-- Nothing reads core.name_history, so no view or function is affected.

drop trigger if exists org_unit_name_history on core.org_unit;
drop trigger if exists pos_unit_name_history on core.pos_unit;
drop trigger if exists job_position_name_history on core.job_position;

drop function if exists private.name_history_sync();

drop table if exists core.name_history;
