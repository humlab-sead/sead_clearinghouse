-- Drop Function clearing_house.fn_clearinghouse_review_dataset_ceramic_values_client_data(int, int);
-- Select * From clearing_house.fn_clearinghouse_review_dataset_ceramic_values_client_data(1, 3024)
Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_ceramic_values_client_data(int, int)
Returns Table (

	local_db_id					int,
    method_id					int,
    sample_name					character varying,
    method_name					character varying,
    lookup_name				    character varying,
    measurement_value			character varying,

	public_db_id 				int,
    public_method_id			int,
    public_sample_name			character varying,
    public_method_name			character varying,
    public_lookup_name		    character varying,
    public_measurement_value	character varying,

	entity_type_id				int

) As $$
Declare
    entity_type_id int;
    public_ds_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_ceramics');

	Select x.public_db_id Into public_ds_id
	From clearing_house.view_datasets x
	Where x.local_db_id = -$2;

	Return Query

        With LDB As (
            Select	d.submission_id                         As submission_id,
                    d.source_id                             As source_id,
                    d.local_db_id 			                As local_dataset_id,
                    ps.local_db_id 			                As local_physical_sample_id,
                    m.local_db_id 			                As local_method_id,

                    d.public_db_id 			                As public_dataset_id,
                    ps.public_db_id 			            As public_physical_sample_id,
                    m.public_db_id 			                As public_method_id,

                    c.local_db_id                           As local_db_id,
                    c.public_db_id                          As public_db_id,

                    ps.sample_name                          As sample_name,
                    m.method_name                           As method_name,
                    cl.name                                 As lookup_name,
                    c.measurement_value                     As measurement_value,

                    cl.date_updated                     	As date_updated  -- Select count(*)

            From clearing_house.view_datasets d
            Join clearing_house.view_analysis_entities ae
              On ae.dataset_id = d.merged_db_id
             And ae.submission_id In (0, d.submission_id)
            Join clearing_house.view_ceramics c
              On c.analysis_entity_id = ae.merged_db_id
             And c.submission_id In (0, d.submission_id)
            Join clearing_house.view_ceramics_lookup cl
              On cl.merged_db_id = c.ceramics_lookup_id
             And cl.submission_id In (0, d.submission_id)
            Join clearing_house.view_physical_samples ps
              On ps.merged_db_id = ae.physical_sample_id
             And ps.submission_id In (0, d.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = d.method_id
             And m.submission_id In (0, d.submission_id)
           Where 1 = 1
              And d.submission_id = $1 -- perf
              And d.local_db_id = -$2 -- perf
        ), RDB As (
            Select	d.dataset_id 			                As dataset_id,
                    ps.physical_sample_id                   As physical_sample_id,
                    m.method_id                             As method_id,

                    c.ceramics_id                           As ceramics_id,

                    ps.sample_name                          As sample_name,
                    m.method_name                           As method_name,
                    cl.name                                 As lookup_name,
                    c.measurement_value                     As measurement_value

            From public.tbl_datasets d
            Join public.tbl_analysis_entities ae
              On ae.dataset_id = d.dataset_id
            Join public.tbl_ceramics c
              On c.analysis_entity_id = ae.analysis_entity_id
            Join public.tbl_ceramics_lookup cl
              On cl.ceramics_lookup_id = c.ceramics_lookup_id
            Join public.tbl_physical_samples ps
              On ps.physical_sample_id = ae.physical_sample_id
            Join public.tbl_methods m
              On m.method_id = d.method_id
            Where ae.dataset_id = public_ds_id -- perf
        )
            Select

                -- LDB.local_dataset_id 			                As dataset_id,
                -- LDB.local_physical_sample_id 			        As physical_sample_id,
                LDB.local_db_id                                 As local_db_id,
                LDB.local_method_id 			                As method_id,
                LDB.sample_name									As sample_name,
                LDB.method_name									As method_name,
                LDB.lookup_name									As lookup_name,
                LDB.measurement_value							As measurement_value,

                -- LDB.public_dataset_id 			                As public_dataset_id,
                -- LDB.public_physical_sample_id 			        As public_physical_sample_id,
                LDB.public_db_id 			                    As public_db_id,
                LDB.public_method_id 			                As public_method_id,
                RDB.sample_name									As public_sample_name,
                RDB.method_name									As public_method_name,
                RDB.lookup_name									As public_lookup_name,
                RDB.measurement_value							As public_measurement_value,

                entity_type_id									As entity_type_id --,
                -- to_char(LDB.date_updated,'YYYY-MM-DD')			As date_updated

            From LDB
            Left Join RDB
              On 1 = 1
             And RDB.ceramics_id = LDB.public_db_id
             --And RDB.dataset_id = public_ds_id -- LDB.public_dataset_id
             --And RDB.physical_sample_id = LDB.public_physical_sample_id
             --And RDB.method_id = LDB.public_method_id

            Where LDB.source_id = 1
              And LDB.submission_id = $1
              And LDB.local_dataset_id = -$2
            Order by LDB.local_physical_sample_id;

End $$ Language plpgsql;