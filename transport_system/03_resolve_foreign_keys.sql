set session schema 'clearing_house_commit';

/*********************************************************************************************************************************
**  Function    clearing_house_commit.generate_resolve_function
**  Who         Roger Mähler
**  When
**  What        Generates a function that returns all records with primary and foreign keys resolved
**              Each function result has the same return type as corresponding SEAD table
**  Used By     Transport system install: generate_resolve_functions
**              Resulting functions are used during packaging of a CH transfer
**  Returns     Function DDL script
**  Idempotant  YES
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.generate_resolve_function(p_schema_name character varying, p_table_name character varying) returns text as $$
declare
    v_entity_name character varying;
    v_field_clause text;
    v_join_clause text;
    v_sql text = '';
begin

    v_entity_name = clearing_house.fn_sead_table_entity_name(p_table_name::name)::character varying;

    select array_to_string(array_agg(
                case
                    when is_pk = 'YES'  then
                        format(E'\t\t\tcase when e.transport_id <= 0 then null else e.transport_id end::%2$s as %1$I', column_name, data_type)
                    when is_fk = 'YES' then
                        format(E'\t\t\tcase when e.%1$I > 0 then e.%1$I else fk%2$s.transport_id end::%3$s as %1$s', column_name, ordinal_position, data_type)
                    when column_name = 'date_updated' then
                        format(E'\t\t\tcase when e.date_updated is null then now() else e.date_updated end::%2$s as %1$s', column_name, data_type)
                    when column_name like '%_uuid' then
                        format(E'\t\t\tcase when e.%1$s is null then uuid_generate_v4() else e.%1$s end::%2$s as %1$s', column_name, data_type)
                    else
                        E'\t\t\te.' || column_name
                end order by ordinal_position), E',\n') as field_clauses,

            array_to_string(array_agg(
                case when is_fk = 'YES' then
                    format(E'\tleft join clearing_house.%I fk%s on e.submission_id = fk%s.submission_id and e.%I = fk%s.local_db_id',
                           fk_table_name, ordinal_position, ordinal_position, column_name, ordinal_position)
                else
                    null
                end order by ordinal_position), E'\n') as join_clauses

        into v_field_clause, v_join_clause
        from clearing_house.fn_dba_get_sead_public_db_schema(p_schema_name) x
        where table_name = p_table_name;

        v_sql = format('
create or replace function clearing_house_commit.resolve_%s(p_submission_id int) returns setof public.%s as $xyz$
begin
    return query
        select
        %s
        from clearing_house.%I e
        %s
        where e.submission_id = p_submission_id;
end $xyz$ language plpgsql;', v_entity_name, p_table_name, v_field_clause, p_table_name, v_join_clause);

        -- raise notice '%', v_sql;
        return v_sql;

end $$ language plpgsql;

/*********************************************************************************************************************************
**  Function    clearing_house_commit.generate_resolve_functions
**  Who         Roger Mähler
**  When
**  What        Generates a functions that for each SEAD table returns data with resolved PK/FK
**  Used By     Function is called during install of transport system.
**              The function should be called whenever public DB schema has changes
**              Resulting functions are used during packaging of a CH transfer
**  Returns     None
**  Idempotant  YES
**  Revisions
**********************************************************************************************************************************/

create or replace function clearing_house_commit.generate_resolve_functions(p_schema_name character varying, p_dry_run boolean)
    returns void /* setof text */ as $$
declare
    v_table_name character varying;
    v_sql text = '';
begin
    begin
        for v_table_name in (select distinct table_name from clearing_house_commit.tbl_sead_tables)
        loop
            v_sql = clearing_house_commit.generate_resolve_function(p_schema_name, v_table_name);
            if (not p_dry_run) then
                 execute v_sql;
            end if;
            -- return next v_sql;
        end loop;
    end;
end;$$ language plpgsql;



