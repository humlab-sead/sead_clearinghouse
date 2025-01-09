-- select clearing_house_commit.delete_committed_records_script(1)

create or replace function clearing_house_commit.delete_committed_records_script(p_submission_id int)
returns text as
$$
declare
  v_data record;
  v_sql text;
  v_sql_script text = '';
  v_sql_count_template text;
  v_sql_delete_template text;
  v_record_count int;
begin

	v_sql_count_template := '
		select count(*)
		from clearing_house.%s
		where submission_id = %s
		  and transport_id is not null;
	';

	v_sql_delete_template = '
		delete from public.%s
		where %s in (
			select transport_id
			from clearing_house.%s
			where submission_id = %s
			  and transport_id is not null
		);
	';

	for v_data in (

		select distinct t.table_name, t.pk_name, coalesce(x.sort_order, 999) as sort_key
		from clearing_house_commit.tbl_sead_tables t
		left join clearing_house_commit.sorted_table_names() x
		  on x.table_name = t.table_name
		order by 3 desc

	) Loop

		v_sql := format(v_sql_count_template, v_data.table_name, p_submission_id);

		execute v_sql into v_record_count;

		if v_record_count > 0 then

			v_sql = format(v_sql_delete_template, v_data.table_name, v_data.pk_name, v_data.table_name, p_submission_id);

			raise info 'Table %: %', v_data.table_name, v_record_count;

			v_sql_script = v_sql_script || v_sql;

		end if;

	End Loop;

	return v_sql_script;

end $$ language plpgsql;

-- create or replace function clearing_house_commit.rollback_commit(p_submission_id int)
-- returns void as
-- $$
-- declare
--   v_sql text;
-- begin
--     v_sql = clearing_house_commit.delete_committed_records_script(p_submission_id);
--     TODO: reset clearinghouse database etc
-- end $$ language plpgsql;