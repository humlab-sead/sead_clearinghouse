set session schema 'clearing_house_commit';

/*********************************************************************************************************************************
**  Function    clearing_house_commit.get_max_transported_id
**  Who         Roger Mähler
**  When
**  What        Gets the max transported/commited ID for a given table in the transport system
**  Used By     Transport system, during resolve and assignment of primary keys
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.get_max_transported_id(p_table_name character varying) returns int as $$
declare
    v_id int = 0;
    v_sql text = '';
begin
    v_sql = format(
        'select coalesce(max(transport_id), 0) + 1 from clearing_house.%s',
        case when p_table_name not like '%.%' then p_table_name else split_part(p_table_name, '.', 2) end
    );
    execute v_sql into v_id;
    return coalesce(v_id, 0);
end $$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.reset_serial_id
**  Who         Roger Mähler
**  When
**  What        Resets a database sequence given name of schema, table and column
**  Used By     Transport system, during resolve and assignment of primary keys
**  Returns     Next serial ID in sequence
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.reset_serial_id(
    p_schema_name character varying,
    p_table_name character varying,
    p_column_name character varying
) returns int as $$
declare
    v_sql text = '';
    v_id integer;
    v_sequence_name text;
    v_max_transport_id int = 0;
begin

    v_sequence_name  = pg_get_serial_sequence(format('%s', p_table_name), p_column_name);

    v_max_transport_id = clearing_house_commit.get_max_transported_id(p_table_name);

    if p_table_name not like format('%s.%%', p_schema_name) then
        p_table_name = format('%s.%s', p_schema_name, p_table_name);
    end if;

    v_sql = format('select max(%s) from %s', p_column_name, p_table_name);
    execute v_sql into v_id;

    v_id = greatest(coalesce(v_id, 1), 1, v_max_transport_id);

    perform setval(v_sequence_name, v_id);

    return v_id;
end $$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.get_next_id
**  Who         Roger Mähler
**  When
**  What        Returns (and optionally resets) next ID in given sequence
**  Used By     Transport system, during resolve and assignment of primary keys
**  Returns     Next serial ID in sequence
**  Revisions
**********************************************************************************************************************************/


create or replace function clearing_house_commit.get_next_id(
    p_schema_name character varying,
    p_table_name character varying,
    p_column_name character varying,
    p_reset_id boolean = FALSE
) returns int as $$
declare
    v_next_id              int = 0;
    v_sequence_name        text;
    v_transport_id_sql     text = '';
    v_max_transport_id     int = 0;
    v_dynamic_sql          text = '';
begin

    v_max_transport_id = clearing_house_commit.get_max_transported_id(p_table_name);

    if p_table_name not like format('%s.%%', p_schema_name) then
        p_table_name = format('%s.%s', p_schema_name, p_table_name);
    end if;

    v_sequence_name = pg_get_serial_sequence(p_table_name, p_column_name);
    if v_sequence_name is not null then
        if p_reset_id is TRUE then
            perform clearing_house_commit.reset_serial_id(p_schema_name, p_table_name, p_column_name);
        end if;
        v_next_id = nextval(v_sequence_name);
    else
        v_dynamic_sql = format('select max(%s) + 1 from %s', p_column_name, p_table_name);
        execute v_dynamic_sql into v_next_id;
    end if;

    -- Find MAX assigned id from transport_system (pending insert)
    v_transport_id_sql = format(
        'select coalesce(max(transport_id), 0) + 1 from clearing_house.%s',
        case when p_table_name not like '%.%' then p_table_name else split_part(p_table_name, '.', 2) end
    );

    execute v_transport_id_sql into v_max_transport_id;

    v_next_id = greatest(v_next_id, v_max_transport_id);

    return v_next_id;

end $$ language plpgsql;


create or replace function clearing_house_commit.allocate_sequence_ids()
returns void as
$$
declare
  v_data record;
  v_sql text;
  v_max_transport_id int;
  v_max_pk_value int;
  v_sequence_name character varying;
begin

	for v_data in (

		with clearinghouse_pk_columns as (

			select table_name_underscored as tablename, st.column_name as columnname
			from clearing_house.tbl_clearinghouse_submission_xml_content_tables cxt
			join clearing_house.tbl_clearinghouse_submission_tables ct using (table_id)
			join clearing_house.fn_dba_get_sead_public_db_schema() st on st.table_name = ct.table_name_underscored
			where TRUE
			  and st.table_schema = 'public'
			  and 'YES' in (st.is_pk)
			group by table_name_underscored, column_name

		), sead_sequence_columns as (

			with sequences as (
				select oid, relname as sequencename
				from pg_class
				where relkind = 'S'
			)
				select sch.nspname as schemaname, tab.relname as tablename, col.attname as columnname, col.attnum as columnnumber, seqs.sequencename
				from pg_attribute col
				join pg_class tab on col.attrelid = tab.oid
				join pg_namespace sch on tab.relnamespace = sch.oid
				left join pg_attrdef def on tab.oid = def.adrelid and col.attnum = def.adnum
				left join pg_depend deps on def.oid = deps.objid and deps.deptype = 'n'
				left join sequences seqs on deps.refobjid = seqs.oid
				where sch.nspname = 'public'
				  and col.attnum > 0
				  and seqs.sequencename is not null
				order by sch.nspname, tab.relname, col.attnum

		) select *
		  from clearinghouse_pk_columns
		  join sead_sequence_columns using (tablename, columnname)

	) Loop

		v_sql := format('select max(transport_id) from clearing_house.%s', v_data.tablename);

		execute v_sql into v_max_transport_id;

		v_sql := format('select max(%s) from public.%s', v_data.columnname, v_data.tablename);

		execute v_sql into v_max_pk_value;

		if coalesce(v_max_transport_id, 0) > coalesce(v_max_pk_value,0) then

			v_sequence_name = pg_get_serial_sequence(format('%s', v_data.tablename), v_data.columnname);

			raise info 'Adjusting sequence % on %.% to % (was %)',
				v_sequence_name, v_data.tablename, v_data.columnname, v_max_transport_id, v_max_pk_value;

			perform setval(v_sequence_name, v_max_transport_id);

		end if;

	End Loop;

end $$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.resolve_primary_key
**  Who         Roger Mähler
**  When
**  What        Assigns a public ID in field "transport_id" to all records in given table. Type of CRUD op. (C or U)
**              are stored in field "transport_type".
**              Existing records are assign "public_db_id", and new records are assigned next ID in sequence.
**              Note that the serial in the public DB is left untouched (apart from a reset) by this function.
**  Used By     Transport system, during packaging of a new CH submission transfer
**  Returns     Next serial ID in sequence
**  Idempotant  YES
**  Revisions
**********************************************************************************************************************************/
--select * from clearing_house_commit.resolve_primary_key(1, 'public', 'tbl_sites', 'site_id', 'source_name', 'cr_name')
--drop function clearing_house_commit.resolve_primary_key(int, text,text,text,text,text)
create or replace function clearing_house_commit.resolve_primary_key(
    p_submission_id int,
    p_schema_name text,
    p_table_name text,
    p_pk_name text,
    p_source_name text, -- name of submission's import file
    p_cr_name text -- name of CR that pre-allocated keys for this table
) returns text as $$
declare
    v_sql text;
    v_next_id integer;
begin
    begin

        -- FIXME update preallocated ids
        v_sql = format('
            update clearing_house.%1$I
            set transport_id = null, transport_date = null, transport_type = null
            where clearing_house.%1$I.submission_id = %2$s;
        ', p_table_name, p_submission_id);

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
            ', p_source_name, p_cr_name, p_table_name, p_pk_name, p_submission_id);
        end if;
        
        v_next_id = clearing_house_commit.get_next_id(p_schema_name, p_table_name, p_pk_name, true);
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
        ', v_next_id - 1, p_table_name, p_submission_id);

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

-- FIXME: resolve_primary_keys allocates an existing public_id to a new record, which is not correct

create or replace procedure clearing_house_commit.resolve_primary_keys(
    p_submission_id int,
    p_schema_name text,
    p_cr_name text = null,  -- name of CR if keys are pre-allocated 
    p_dry_run boolean = false,
) as $$
    declare v_schema_name character varying;
        v_table_name character varying;
        v_pk_name character varying;
        v_sql text = '';
        v_source_name text;
        v_count integer;
begin

    begin

        v_source_name := (select source_name from clearing_house.tbl_clearinghouse_submissions where submission_id = p_submission_id);

        perform clearing_house_commit.generate_sead_tables();

        for v_table_name, v_pk_name in (
            select table_name, pk_name
            from clearing_house_commit.tbl_sead_tables
            order by 1, 2
        )
        loop

            execute format('select count(*) from clearing_house.%s where submission_id = $1', v_table_name)
                into v_count
                    using p_submission_id;

            if v_count = 0 then
                continue;
            end if;


            v_sql = clearing_house_commit.resolve_primary_key(
                p_submission_id,
                p_schema_name,
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


