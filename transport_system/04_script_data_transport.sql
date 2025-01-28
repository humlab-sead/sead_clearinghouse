
create or replace function clearing_house_commit.generate_copy_out_script(p_submission_id int, p_entity text, p_target_folder text) returns text as $$
declare v_sql text;
begin

    -- program ''gzip > %s/submission_%s_%s.zip''
    v_sql = format('\copy (select * from clearing_house_commit.resolve_%s(%s)) to program ''gzip -qa9 > %s/submission_%s_%s.gz'' with (format text, delimiter E''\t'', encoding ''utf-8'');
    ',
        p_entity, p_submission_id, p_target_folder, p_submission_id, p_entity);

    return v_sql;

end $$ language plpgsql;

create or replace function clearing_house_commit.generate_copy_in_script(
    p_submission_id int,
    p_entity_name text,
    p_table_name text,
    p_pk_name text,
    p_target_folder text = '/tmp',
    p_delete_existing boolean = FALSE
) returns text as $$
declare v_sql text;
declare v_delete_sql text;
begin

    -- from program ''gunzip < %s/submission_%s_%s.zip''
    v_sql = E'
/************************************************************************************************************************************
 ** #ENTITY#
 ************************************************************************************************************************************/

drop table if exists clearing_house_commit.temp_#TABLE#;
create table clearing_house_commit.temp_#TABLE# as select * from public.#TABLE# where FALSE;

\\copy clearing_house_commit.temp_#TABLE# from program ''zcat -qac #DIR#/submission_#ID#_#ENTITY#.gz'' with (FORMAT text, DELIMITER E''\t'', ENCODING ''utf-8'');
#DELETE-SQL#

insert into public.#TABLE#
    select *
    from clearing_house_commit.temp_#TABLE# ;

\\echo Deployed #ENTITY#, rows inserted: :ROW_COUNT

\\o /dev/null
select clearing_house_commit.reset_serial_id(''public'', ''#TABLE#'', ''#PK#'');
\\o

drop table if exists clearing_house_commit.temp_#TABLE#;
';

    v_delete_sql = case when p_delete_existing then E'
delete from public.#TABLE#
    where #PK# in (select #PK# from clearing_house_commit.temp_#TABLE#);' else '' end;

    v_sql = replace(v_sql, '#DELETE-SQL#', v_delete_sql);
    v_sql = replace(v_sql, '#TABLE#', p_table_name);
    v_sql = replace(v_sql, '#ID#', p_submission_id::text);
    v_sql = replace(v_sql, '#ENTITY#', p_entity_name);
    v_sql = replace(v_sql, '#PK#', p_pk_name);
    v_sql = replace(v_sql, '#DIR#', p_target_folder);
    return v_sql;

end $$ language plpgsql;

create or replace function clearing_house_commit.generate_resolved_submission_copy_script(
    p_submission_id int,
    p_folder character varying,
    p_is_out boolean
) returns text as $xyz$
declare
    v_sql character varying;
    v_table_name character varying;
    v_entity_name character varying;
    v_count integer;
    v_pk_name character varying;
    v_sort_order integer;
begin
    begin

        -- perform clearing_house_commit.generate_resolve_functions('public', FALSE);
        -- perform clearing_house_commit.resolve_primary_keys(p_submission_id, 'public', FALSE);


        v_sql := '';

        for v_table_name, v_pk_name, v_entity_name, v_sort_order in (
            select distinct t.table_name, t.pk_name, t.entity_name, coalesce(x.sort_order, 999)
            from clearing_house_commit.tbl_sead_tables t
            left join clearing_house_commit.sorted_table_names() x
              on x.table_name = t.table_name
            order by 4 asc
        )
        loop

            execute format('select count(*) from clearing_house.%s where submission_id = $1', v_table_name)
                into v_count
                    using p_submission_id;

            if v_count = 0 then
                -- raise notice 'SKIPPED: % no data', v_table_name;
                continue;
            end if;

            if p_is_out then
                v_sql = v_sql || E'\n' || clearing_house_commit.generate_copy_out_script(p_submission_id, v_entity_name, p_folder);
            else
                v_sql = v_sql || E'\n' || clearing_house_commit.generate_copy_in_script(p_submission_id, v_entity_name, v_table_name, v_pk_name, p_folder) || E'\n';
            end if;

        end loop;

    end;

    return v_sql;

end $xyz$ language plpgsql;

-- select clearing_house_commit.rollback_commit(1)

create or replace function clearing_house_commit.rollback_commit(p_submission_id int)
returns void as
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

	raise info '%', v_sql_script;

end $$ language plpgsql;
