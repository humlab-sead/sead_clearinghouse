/*********************************************************************************************************************************
**  Schema    clearing_house_commit
**  What      all stuff related to ch data commit
**********************************************************************************************************************************/

set role humlab_admin;

\o /dev/null

drop schema if exists clearing_house_commit cascade \g /dev/null

\o

create schema if not exists clearing_house_commit authorization clearinghouse_worker;

create type clearing_house_commit.resolve_primary_keys_result as (
    submission_id int,
    table_name text,
    column_name text,
    update_sql text,
    action text,
    row_count int,
    start_id int,
    status_id int,
    execute_date timestamp
);

set role clearinghouse_worker;

create or replace function clearing_house_commit.commit_submission(p_submission_id int)
	returns void
as $$
begin
	update clearing_house.tbl_clearinghouse_submissions
		set submission_state_id = 4
	where submission_id = p_submission_id;
end $$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.generate_sead_tables
**  Who         Roger Mähler
**  When
**  What        Fetches relevant schema information from the public SEAD database
**  Used By     Transport system install script
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.generate_sead_tables()
returns void language 'plpgsql' as $body$
begin

    drop table if exists clearing_house_commit.tbl_sead_tables;
    drop table if exists clearing_house_commit.tbl_sead_table_keys;
    -- drop index if exists clearing_house_commit.idx_tbl_sead_tables_entity_name;

    create table if not exists clearing_house_commit.tbl_sead_tables (
        table_name information_schema.sql_identifier primary key,
        pk_name information_schema.sql_identifier not null,
        entity_name information_schema.sql_identifier not null,
        is_global_lookup information_schema.yes_or_no not null default('NO'),
        is_local_lookup information_schema.yes_or_no not null default('NO'),
		is_aggregate_root information_schema.yes_or_no not null default('NO'),
        has_foreign_key information_schema.yes_or_no not null default('NO'),
		parent_aggregate information_schema.sql_identifier null
    );

    create unique index if not exists idx_clearinghouse_entity_tables_entity_name
        on clearing_house_commit.tbl_sead_tables (entity_name);

	--, is_lookup, is_aggregate_root, aggregate_root
	insert into clearing_house_commit.tbl_sead_tables (table_name, pk_name, entity_name)
		select x.table_name, x.column_name, clearing_house.fn_sead_table_entity_name(x.table_name::text)
		from clearing_house.fn_dba_get_sead_public_db_schema() x
		where true
          and x.table_schema = 'public'
          and x.is_pk = 'YES'
        on conflict (table_name)
        do update set (pk_name, entity_name) = (excluded.pk_name, excluded.entity_name);

    update clearing_house_commit.tbl_sead_tables
        set is_global_lookup = 'YES'
    where table_name like '%_types';

    create table if not exists clearing_house_commit.tbl_sead_table_keys (
        table_name information_schema.sql_identifier not null,
        column_name information_schema.sql_identifier not null,
        is_pk information_schema.yes_or_no not null default('NO'),
        is_fk information_schema.yes_or_no not null default('NO'),
        fk_table_name information_schema.sql_identifier null,
        fk_column_name information_schema.sql_identifier null,
        constraint pk_tbl_sead_table_keys primary key (table_name, column_name)
    );

	insert into clearing_house_commit.tbl_sead_table_keys (table_name, column_name, is_pk, is_fk, fk_table_name, fk_column_name)
		select table_name, column_name, is_pk, is_fk, fk_table_name, fk_column_name
		from clearing_house.fn_dba_get_sead_public_db_schema() x
		where TRUE
          and x.table_schema = 'public'
          and 'YES' in (x.is_pk, x.is_fk)
        on conflict (table_name, column_name)
        do update set (is_pk, is_fk, fk_table_name, fk_column_name) = (excluded.is_pk, excluded.is_fk, excluded.fk_table_name, excluded.fk_column_name);

    with tables_with_foreign_keys as (
        select distinct table_name
        from clearing_house_commit.tbl_sead_table_keys
        where is_fk = 'YES'
    )
        update clearing_house_commit.tbl_sead_tables t set has_foreign_key = 'YES'
        from tables_with_foreign_keys k
        where k.table_name = t.table_name;

end
$body$;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.sorted_table_names
**  Who         Roger Mähler
**  When
**  What        Returns table name sorted in a way that dependent tables are returned after referred tables
**              This function defines the order in shich table data are inserted into the public database.
**  Used By     Transport system install script
**  Note
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.sorted_table_names()
returns table (table_name text, sort_order int) as $$
  declare v_processed_tables text[] := '{}';
  declare v_table_count int;
  declare v_count int;
  declare v_table_name text = '';
begin
    v_count = 0;
    v_table_count = (select count(*) from clearing_house_commit.tbl_sead_tables);
    v_processed_tables = (
        select array_agg(t.table_name)
        from clearing_house_commit.tbl_sead_tables t
        where t.table_name not in (
            select fk.table_name
            from clearing_house_commit.tbl_sead_table_keys fk
            where fk.is_fk = 'YES'
        )
    );
    while cardinality(v_processed_tables) <= v_table_count loop
        v_count = v_count + 1;
        v_table_name = (
            select min(t.table_name)
            from clearing_house_commit.tbl_sead_tables t
            where not t.table_name = ANY (v_processed_tables)
              and not t.table_name in (
                  select fk.table_name
                  from clearing_house_commit.tbl_sead_table_keys fk
                  where TRUE
                    and fk.table_name <> fk.fk_table_name
                    and fk.is_fk = 'YES'
                    and not fk.fk_table_name = ANY (v_processed_tables)
             )
        );
        if v_table_name is null then
            exit;
        end if;
        v_processed_tables = array_append(v_processed_tables, v_table_name);
    end loop;

    return query
        select unnest(v_processed_tables), generate_subscripts(v_processed_tables, 1);

end $$ language plpgsql;

