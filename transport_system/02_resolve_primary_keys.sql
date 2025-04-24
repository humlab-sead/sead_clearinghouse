set session schema 'clearing_house_commit';

create or replace function clearing_house_commit.strip_schema_name(p_table_name text)
returns text as $$
begin
    if p_table_name like '%.%' then
        p_table_name := split_part(p_table_name, '.', 2);
    end if;
    return p_table_name;
end;
$$ language plpgsql;


/*********************************************************************************************************************************
**  Function    clearing_house_commit.get_max_transported_id
**  Who         Roger Mähler
**  When
**  What        Gets the max transported/commited ID for a given table in the transport system
**  Used By     Transport system, during resolve and assignment of primary keys
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.get_max_transported_id(p_table_name text)
returns int as $$
declare
    v_id int;
begin
    execute format(
        'select coalesce(max(transport_id), 0) + 1 from clearing_house.%I',
        clearing_house_commit.strip_schema_name(p_table_name)
    ) into v_id;

    return coalesce(v_id, 0);
end;
$$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.get_max_allocated_id
**  Who         Roger Mähler
**  When
**  What        Gets the max pre-allocated (reserved) ID for a given table 
**  Used By     Transport system, during resolve and assignment of primary keys
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.get_max_allocated_id(p_table_name text, p_column_name text)
returns int as $$
begin
    return coalesce((
        select max(alloc_system_id::int)
        from sead_utility.system_id_allocations
        where table_name = clearing_house_commit.strip_schema_name(p_table_name)
          and column_name = p_column_name
    ), 0);
end;
$$ language plpgsql;


/*********************************************************************************************************************************
**  Function    clearing_house_commit.get_max_public_id
**  Who         Roger Mähler
**  When
**  What        Gets the max public ID for a given table in the transport system
**              (i.e. the max value of the public ID column in the table)
**              This function is used to determine the next available ID for a new record
**  Used By     Transport system, during resolve and assignment of primary keys
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.get_max_public_id(p_table_name text, p_column_name text)
returns int as $$
declare
    v_id int;
begin
    execute format('select max(%s) from public.%I', p_column_name, clearing_house_commit.strip_schema_name(p_table_name))
        into v_id;
    return coalesce(v_id, 0);
end;
$$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.get_max_allocated_id
**  Who         Roger Mähler
**  When
**  What        Returns next pre-allocated (reserved id) for a given primary id column in a given table
**  Used By     Transport system, during resolve and assignment of primary keys
**  Returns     Max pre-allocated ID or 0 if none
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.get_max_allocated_id(p_table_name text)
returns int as $$
begin
    return coalesce((
        select max(alloc_system_id::int)
        from sead_utility.system_id_allocations
        where table_name = clearing_house_commit.strip_schema_name(p_table_name)
          and column_name = p_column_name
    ), 0);
end;
$$ language plpgsql;


/*********************************************************************************************************************************
**  Function    clearing_house_commit.get_next_public_id
**  Who         Roger Mähler
**  When
**  What        Returns next ID for a given primary id column in a given table
**  Used By     Transport system, during resolve and assignment of primary keys
**  Returns     Next serial ID in sequence
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.get_next_public_id(p_table_name text, p_column_name text)
returns int as $$
declare
    v_sql text = '';
    v_id int = 0;
begin

    p_table_name = clearing_house_commit.strip_schema_name(p_table_name);

    v_id = greatest(
        clearing_house_commit.get_max_public_id(p_table_name, p_column_name),
        clearing_house_commit.get_max_transported_id(p_table_name),
        clearing_house_commit.get_max_allocated_id(p_table_name, p_column_name)
    ) + 1;

    return v_id;
end; $$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.reset_public_sequence_ids
**  Who         Roger Mähler
**  When
**  What        Resets public sequence IDs for all tables in public schema that exists in clearing_house schema
**  Used By     Transport system, during resolve and assignment of primary keys
**  Returns     Max pre-allocated ID or 0 if none
**  Revisions
**********************************************************************************************************************************/

create or replace procedure clearing_house_commit.reset_public_sequence_ids()
as
$$
declare
  v_data record;
  v_sql text;
  v_current_id int;
  v_next_id int;
begin

	for v_data in (
        with public_sequences as (
            select format('%s.%s', s.schemaname, s.sequencename) as sequence_name, last_value
            from pg_sequences s
            where schemaname = 'public'
             and last_value is not null
        ), public_sequences_that_exists_in_clearinghouse as (
            select distinct table_name, column_name, sequence_name, last_value,
                clearing_house_commit.get_next_public_id(table_name, column_name) as next_value
            from clearing_house.fn_dba_get_sead_public_db_schema()
            join public_sequences s
              on sequence_name = pg_get_serial_sequence(format('public.%I', table_name), column_name)
            where TRUE
              and table_schema = 'public'
              and to_regclass(format('clearing_house.%s', table_name)) IS NOT NULL
              and is_pk = 'YES'
              and last_value is not null
        )
            select sequence_name, last_value, next_value
            from public_sequences_that_exists_in_clearinghouse
            where last_value + 1 != next_value
	) Loop

        -- raise info 'Sequence % updated to % (was %)', v_data.sequence_name, v_data.next_value, v_data.last_value;

		perform setval(v_data.sequence_name, v_data.next_value, false);

	End Loop;

end $$ language plpgsql;


/*********************************************************************************************************************************
**  Function    clearing_house_commit.resolve_primary_key
**  Who         Roger Mähler
**  When
**  What        Assigns a public ID in field "transport_id" to all records in given table. Type of CRUD op. (C or U)
**              are stored in field "transport_type".
**              Existing records are assigned "public_db_id", and new records are assigned next ID in sequence.
**              Note that the serial in the public DB is left untouched (apart from a reset) by this function.
**  Used By     Transport system, during packaging of a new CH submission transfer
**  Returns     Next serial ID in sequence
**  Idempotant  YES
**  Revisions
**********************************************************************************************************************************/
--select * from clearing_house_commit.resolve_primary_key('XYZ', 'public', 'tbl_sites', 'site_id', 'source_name', 'cr_name')
--drop function clearing_house_commit.resolve_primary_key(text, text,text,text,text,text)
create or replace function clearing_house_commit.resolve_primary_key(
    p_submission_name text,
    p_table_name text,
    p_pk_name text,
    p_source_name text, -- name of submission's import file
    p_cr_name text -- name of CR that pre-allocated keys for this table
) returns text as $$
declare
    v_sql text;
    v_next_id integer;
    v_submission_id integer;
begin
    begin

        v_submission_id := (
            select submission_id
            from clearing_house.tbl_clearinghouse_submissions
            where submission_name = p_submission_name
        );

        -- FIXME update preallocated ids
        v_sql = format('
            update clearing_house.%1$I
            set transport_id = null, transport_date = null, transport_type = null
            where clearing_house.%1$I.submission_id = %2$s;
        ', p_table_name, v_submission_id);

        if coalesce(p_cr_name,'') != '' and coalesce(p_source_name,'') != '' then
            v_sql = v_sql || format('
            with allocated_identities as (
                select external_system_id::int as local_db_id, alloc_system_id::int as public_id
                from sead_utility.system_id_allocations
                where submission_identifier = ''%1$s''
                  and change_request_identifier = ''%2$s''
                  and table_name = ''%3$s''
                  and column_name = ''%4$s''
            ) update clearing_house.%3$I
                set transport_id =  a.public_id,
                    transport_date = now(),
                    transport_type = ''A''
                from allocated_identities a
                where clearing_house.%3$I.submission_id = %5$s
                  and -(clearing_house.%3$I.local_db_id::int) = a.local_db_id;
            ', p_source_name, p_cr_name, p_table_name, p_pk_name, v_submission_id);
        end if;
        
        v_next_id = clearing_house_commit.get_next_public_id(p_table_name, p_pk_name);
        v_sql = v_sql || format('
            with new_keys as (
                select local_db_id, %1$s + row_number() over (order by local_db_id asc) as new_db_id
                from clearing_house.%2$I
                where submission_id = %3$s
                and public_db_id is null
                and transport_id is null
            ) update clearing_house.%2$I
                set transport_id = case when public_db_id is null then n.new_db_id else public_db_id end,
                    transport_date = now(),
                    transport_type = case when public_db_id is null then ''C'' else ''U'' end
                from new_keys n
                where clearing_house.%2$I.submission_id = %3$s
                and clearing_house.%2$I.local_db_id = n.local_db_id;
        ', v_next_id - 1, p_table_name, v_submission_id);

        --raise notice '%', v_sql;
        return v_sql;
    end;
end;$$ language plpgsql;

        
/*********************************************************************************************************************************
**  Function    clearing_house_commit.resolve_primary_keys
**  Who         Roger Mähler
**  When
**  What        Loops through all data tables in a SEAD submission and resolves the primary keys if table has data
**              and has a primary key.
**              The primary key is resolved by assigning a new public ID in field "transport_id".
**              
**              If `p_alloc_ids_cr_name` is set, the function will use the pre-allocated identity
**              for the given table and system id value if such an identity exists.
**              Otherwise, the function will use the next available identity based on primary keys
**              next incremental value (serial) and the maximum pre-allocated value for given table and column.
**              
**              The function returns a list of all affected primary keys with some statistical attributes.   
**  Used By     Transport system, during packaging of a new CH submission transfer
**  Returns     Statistics of affected records
**  Idempotant  YES
**  Revisions
**********************************************************************************************************************************/

create or replace procedure clearing_house_commit.resolve_primary_keys(
    p_submission_name text,
    p_cr_name text = null,  -- name of CR if keys are pre-allocated 
    p_dry_run boolean = false
) as $$
    declare v_schema_name character varying;
        v_table_name character varying;
        v_pk_name character varying;
        v_sql text = '';
        v_source_name text;
        v_count integer;
        v_submission_id integer;
begin

    begin

        v_submission_id := (select submission_id from clearing_house.tbl_clearinghouse_submissions where submission_name = p_submission_name);
        v_source_name := (select source_name from clearing_house.tbl_clearinghouse_submissions where submission_id = v_submission_id);

        perform clearing_house_commit.generate_sead_tables();

        for v_table_name, v_pk_name in (
            select table_name, pk_name
            from clearing_house_commit.tbl_sead_tables
            order by 1, 2
        )
        loop

            execute format('select count(*) from clearing_house.%s where submission_id = $1', v_table_name)
                into v_count
                    using v_submission_id;

            if v_count = 0 then
                continue;
            end if;


            v_sql = clearing_house_commit.resolve_primary_key(
                p_submission_name,
                v_table_name,
                v_pk_name,
                v_source_name,
                p_cr_name
            );

            if (not p_dry_run) then
                 execute v_sql;
            end if;

        end loop;

    exception
        when sqlstate 'GUARD' then
            raise notice '%', 'GUARDED';
    end;
end;$$ language plpgsql;


