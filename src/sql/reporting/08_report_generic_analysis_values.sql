/*
-- select * from clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(3, null);
*/
-- Generic crosstab report (replaces ceramics crosstab also)
-- select analysis_type_id, count(*) from clearing_house.view_generic_analysis_lookup_values group by analysis_type_id
Create Or Replace View clearing_house.view_generic_analysis_lookup_values As
    Select 1 As analysis_type_id, d.submission_id, d.source_id, d.merged_db_id, d.local_db_id, d.public_db_id, d.analysis_entity_id, d.measurement_value, d.date_updated, d.dendro_lookup_id As lookup_id, dl.name As lookup
    From clearing_house.view_dendro d
    Left Join clearing_house.view_dendro_lookup dl
      On dl.merged_db_id = d.dendro_lookup_id
     And dl.submission_id in (0, d.submission_id)
    Union
    Select 2 As analysis_type_id, c.submission_id, c.source_id, c.merged_db_id, c.local_db_id, c.public_db_id, c.analysis_entity_id, c.measurement_value, c.date_updated, c.ceramics_lookup_id As lookup_id, cl.name As lookup
    From clearing_house.view_ceramics c
    Left join clearing_house.view_ceramics_lookup cl
      On cl.merged_db_id = c.ceramics_lookup_id
     And cl.submission_id in (0, c.submission_id);

-- select analysis_type_id, count(*) from clearing_house.view_generic_analysis_lookup_values group by analysis_type_id
Create Or Replace View clearing_house.public_view_generic_analysis_lookup_values As
    Select 1 As analysis_type_id, 0 AS submission_id, 2 AS source_id, d.dendro_id AS merged_db_id, 0 AS local_db_id, d.dendro_id AS public_db_id, d.analysis_entity_id, d.measurement_value, d.date_updated, d.dendro_lookup_id AS lookup_id, dl.name AS lookup
    From public.tbl_dendro d
    Left join public.tbl_dendro_lookup dl
      On d.dendro_lookup_id = dl.dendro_lookup_id
    Union
    Select 2 As analysis_type_id, 0 AS submission_id, 2 AS source_id, c.ceramics_id AS merged_db_id, 0 AS local_db_id, c.ceramics_id AS public_db_id, c.analysis_entity_id AS analysis_entity_id, c.measurement_value AS measurement_value, c.date_updated AS date_updated, c.ceramics_lookup_id AS lookup_id, cl.name AS lookup
    From public.tbl_ceramics c
    Left join public.tbl_ceramics_lookup cl
      On c.ceramics_lookup_id = cl.ceramics_lookup_id;

Create Or Replace View clearing_house.view_generic_analysis_lookup As
    with analysis_value_lookup as (
        Select distinct 2 As analysis_type_id, name
        From clearing_house.view_ceramics_lookup
        Union
        Select distinct 1 As analysis_type_id, name
        From clearing_house.view_dendro_lookup
    ) select analysis_type_id, name
      from analysis_value_lookup
      order by 1, 2;

-- select * from clearing_house.fn_clearinghouse_review_dataset_generic_analysis_lookup_values(1, null, null);
-- Drop Function clearing_house.fn_clearinghouse_review_dataset_generic_analysis_lookup_values(int, int, int)
-- select analysis_type_id from clearing_house.view_generic_analysis_lookup_values where submission_id = 1 limit 1

Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_generic_analysis_lookup_values(
    p_submission_id IN integer,
    p_dataset_id IN integer,
    p_analysis_type_id integer
)
Returns Table (
    local_db_id integer,
    method_id integer,
    dataset_name character varying,
    sample_name character varying,
    method_name character varying,
    lookup_name character varying,
    measurement_value character varying,
    public_db_id integer,
    public_method_id integer,
    public_sample_name character varying,
    public_method_name character varying,
    public_lookup_name character varying,
    public_measurement_value character varying,
    entity_type_id integer,
    date_updated text
) AS
$BODY$
Declare
    entity_type_id int;
Begin

    if p_analysis_type_id is null then
        p_analysis_type_id := (select min(analysis_type_id) from clearing_house.view_generic_analysis_lookup_values where submission_id = p_submission_id limit 1);
    end if;

    entity_type_id := clearing_house.fn_get_entity_type_for(case when p_analysis_type_id = 1 then 'tbl_dendro' else 'tbl_ceramics' end);
	Return Query
        With LDB As (
            Select	d.submission_id                 As submission_id,
                    d.source_id                     As source_id,
                    d.local_db_id 			        As local_dataset_id,
                    d.dataset_name 			        As local_dataset_name,
                    ps.local_db_id 			        As local_physical_sample_id,
                    m.local_db_id 			        As local_method_id,

                    d.public_db_id 			        As public_dataset_id,
                    ps.public_db_id 			    As public_physical_sample_id,
                    m.public_db_id 			        As public_method_id,

                    vv.analysis_type_id,
                    vv.analysis_entity_id,
                    vv.local_db_id					As local_db_id,
                    vv.public_db_id					As public_db_id,

                    ps.sample_name					As sample_name,
                    m.method_name					As method_name,
                    vv.lookup					    As lookup_name,
                    vv.measurement_value			As measurement_value,

                    vv.date_updated                 As date_updated

            From clearing_house.view_datasets d
            Join clearing_house.view_analysis_entities ae
              On ae.dataset_id = d.merged_db_id
             And ae.submission_id In (0, d.submission_id)
            Join clearing_house.view_generic_analysis_lookup_values vv
              On vv.analysis_entity_id = ae.merged_db_id
             And vv.submission_id In (0, d.submission_id)
            Join clearing_house.view_physical_samples ps
              On ps.merged_db_id = ae.physical_sample_id
             And ps.submission_id In (0, d.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = d.method_id
             And m.submission_id In (0, d.submission_id)
           Where 1 = 1
              And d.submission_id = p_submission_id -- perf
              And d.local_db_id = Coalesce(-p_dataset_id, d.local_db_id) -- perf
        ), RDB As (
            Select	d.dataset_id 			    As dataset_id,
                    ps.physical_sample_id       As physical_sample_id,
                    m.method_id                 As method_id,

                    lv.public_db_id            As public_db_id,
                    lv.analysis_entity_id,
                    ps.sample_name              As sample_name,
                    m.method_name               As method_name,

                    lv.lookup                   As lookup_name,
                    lv.measurement_value        As measurement_value,
                    lv.date_updated			    As date_updated

                    From public.tbl_datasets d
                    Join public.tbl_analysis_entities ae
                      On ae.dataset_id = d.dataset_id
                    Join clearing_house.public_view_generic_analysis_lookup_values lv
                      On lv.analysis_entity_id = ae.analysis_entity_id
                    Join public.tbl_physical_samples ps
                      On ps.physical_sample_id = ae.physical_sample_id
                    Join public.tbl_methods m
                      On m.method_id = d.method_id
                )
            Select

                LDB.local_db_id                         As local_db_id,
                LDB.local_method_id 			        As method_id,

                LDB.local_dataset_name					As dataset_name,
                LDB.sample_name							As sample_name,
                LDB.method_name							As method_name,
                LDB.lookup_name							As lookup_name,
                LDB.measurement_value					As measurement_value,

                LDB.public_db_id 			            As public_db_id,
                LDB.public_method_id 			        As public_method_id,

                RDB.sample_name							As public_sample_name,
                RDB.method_name							As public_method_name,
                RDB.lookup_name							As public_lookup_name,
                RDB.measurement_value					As public_measurement_value,

                entity_type_id							As entity_type_id,
                to_char(LDB.date_updated,'YYYY-MM-DD')	As date_updated

            From LDB
            Left Join RDB
              On 1 = 1
             And RDB.analysis_entity_id = LDB.analysis_entity_id
            Where LDB.source_id = 1
              And LDB.submission_id = p_submission_id
              And LDB.local_dataset_id = Coalesce(-p_dataset_id, LDB.local_dataset_id)
              And LDB.analysis_type_id = p_analysis_type_id;
            -- Order by LDB.local_physical_sample_id;

End $BODY$ LANGUAGE plpgsql;
-- FUNCTION: clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(integer, integer)

-- DROP FUNCTION clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(integer, integer);

CREATE OR REPLACE FUNCTION clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(
	p_submission_id integer,
	p_analysis_type_id integer DEFAULT NULL::integer)
    RETURNS TABLE(sample_name text, local_db_id integer, public_db_id integer, entity_type_id integer, json_data_values json)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
    ROWS 1000
AS $BODY$
declare
	v_category_sql text;
	v_source_sql text;
	v_typed_fields text;
	v_column_names text;
	v_sql text;
begin
    if coalesce(p_analysis_type_id, 0) = 0 then
        select analysis_type_id
            into p_analysis_type_id
        from clearing_house.view_generic_analysis_lookup_values
        where submission_id = p_submission_id
        limit 1;
    end if;

	v_category_sql = format('
        select name
        from clearing_house.view_generic_analysis_lookup
        where analysis_type_id = %s
        order by name
    ', p_analysis_type_id);

	v_source_sql = format('
		select	sample_name, -- row name
                local_db_id, public_db_id, entity_type_id, -- extra columns
				lookup_name, -- category
				to_json(array[lookup_name, ''text'', max(measurement_value), max(public_measurement_value)]) as measurement_value
		from clearing_house.fn_clearinghouse_review_dataset_generic_analysis_lookup_values(%s, null, %s) c
		where TRUE
		group by sample_name, local_db_id, public_db_id, entity_type_id, lookup_name
		order by sample_name, lookup_name
    ', p_submission_id, p_analysis_type_id);

	v_typed_fields = (
        select string_agg(format('%I json', name), ', ' order by name)
        from clearing_house.view_generic_analysis_lookup
        where analysis_type_id = p_analysis_type_id
    );
    v_column_names = (
	    select string_agg(format('%I', name), ', ' order by name)
	    from clearing_house.view_generic_analysis_lookup
        where analysis_type_id = p_analysis_type_id
    );

    if v_column_names is null then
        return query
            select *
            from (values ('nada'::text, null::int, null::int, null::int, null::json)) as v
            where false;
    else
        v_sql = format('
            with crosstab_values as (
                select sample_name,
                       local_db_id,
                       public_db_id,
                       entity_type_id,
                       %s
                from crosstab(%L, %L) as ct(
                       sample_name text,
                       local_db_id int,
                       public_db_id int,
                       entity_type_id int,
                       %s
                )
            ) select sample_name, local_db_id, public_db_id, entity_type_id, to_json(x.*)
              from crosstab_values x
        ', v_column_names, v_source_sql, v_category_sql, v_typed_fields);

        -- Raise Info E'%\n%\n%', v_sql, v_category_sql, v_source_sql;
        return query execute v_sql;
    end if;
end
$BODY$;

ALTER FUNCTION clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(integer, integer)
    OWNER TO clearinghouse_worker;
