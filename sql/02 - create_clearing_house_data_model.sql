/*********************************************************************************************************************************
**  Function    fn_dba_create_clearing_house_db_model
**  When        2013-10-17
**  What        Creates DB clearing_house specific schema objects (not entity objects) for Clearing House application
**  Who         Roger Mähler
**  Note
**  Uses
**  Used By     Clearing House server installation. DBA.
**  Revisions
**********************************************************************************************************************************/
-- Select clearing_house.fn_dba_create_clearing_house_db_model();
-- Drop Function If Exists fn_dba_create_clearing_house_db_model();
Create Or Replace Function clearing_house.fn_dba_create_clearing_house_db_model() Returns void As $$

Begin



    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_settings') Then

        -- Drop Table clearing_house.tbl_clearinghouse_settings
        Create Table If Not Exists clearing_house.tbl_clearinghouse_settings (
            setting_id serial not null,
            setting_group character varying(255) not null,
            setting_key character varying(255) not null,
            setting_value text not null,
            setting_datatype text not null,
            Constraint pk_tbl_clearinghouse_settings Primary Key (setting_id)
        );

        create unique index idx_tbl_clearinghouse_settings_key On clearing_house.tbl_clearinghouse_settings (setting_key);
        create index idx_tbl_clearinghouse_settings_group On clearing_house.tbl_clearinghouse_settings (setting_group);

    End If;
    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_info_references') Then

        -- Drop Table clearing_house.tbl_clearinghouse_info_references
        Create Table If Not Exists clearing_house.tbl_clearinghouse_info_references (
            info_reference_id serial not null,
            info_reference_type character varying(255) not null,
            display_name character varying(255) not null,
            href character varying(255),
            Constraint pk_tbl_clearinghouse_info_references Primary Key (info_reference_id)
        );

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_sessions') Then

        Create Table If Not Exists clearing_house.tbl_clearinghouse_sessions (
            session_id serial not null,
            user_id int not null default(0),
            ip character varying(255),
            start_time date not null,
            stop_time date,
            Constraint pk_tbl_clearinghouse_sessions_session_id Primary Key (session_id)
        );

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_signals') Then

        Create Table If Not Exists clearing_house.tbl_clearinghouse_signals (
            signal_id serial not null,
            use_case_id int not null default(0),
            recipient_user_id int not null default(0),
            recipient_address text not null,
            signal_time date not null,
            subject text,
            body text,
            status text,
            Constraint pk_clearinghouse_signals_signal_id Primary Key (signal_id)
        );

    End If;

    /*
    Create Table If Not Exists tbl_error_id_types (
        error_id int not null,
        description character varying(255) not null,
        Constraint pk_error_id Primary Key (error_id),
        Constraint fk_tbl_user_roles_role_id Foreign Key (role_id)
            References tbl_user_roles (role_id) Match Simple
                On Update No Action On Delete No Action
    );


    Insert Into tbl_error_id_types (error_id, description) Values (0, 'Not specified');

    Create Table If Not Exists tbl_error_log (
        error_log_id serial not null,
        error_id int not null,
        error_type character varying(32) not null,
        error_message text not null,
        error_file character varying(255) not null,
        error_line int not null,
        error_time date not null,
        error_user character varying(255) not null,
        Constraint pk_tbl_error_log Primary Key (error_log_id)
    );
    */

	if (false) Then

		Drop Table If Exists clearing_house.tbl_clearinghouse_activity_log;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submissions;
		Drop Table If Exists clearing_house.tbl_clearinghouse_signal_log;

		Drop Table If Exists clearing_house.tbl_clearinghouse_submissions;
		Drop Table If Exists clearing_house.tbl_clearinghouse_reject_cause_types;
		Drop Table If Exists clearing_house.tbl_clearinghouse_reject_causes;
		Drop Table If Exists clearing_house.tbl_clearinghouse_users;
		Drop Table If Exists clearing_house.tbl_clearinghouse_user_roles;
		Drop Table If Exists clearing_house.tbl_clearinghouse_data_provider_grades;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_states;

	End If;

    /*********************************************************************************************************************************
    ** Activity
    **********************************************************************************************************************************/

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_use_cases') Then

		-- Drop Table clearing_house.tbl_clearinghouse_use_cases
		-- Alter Table clearing_house.tbl_clearinghouse_use_cases Add Column entity_type_id int not null default(0)
		Create Table clearing_house.tbl_clearinghouse_use_cases (
			use_case_id int not null,
			use_case_name character varying(255) not null,
			entity_type_id int not null default(0),
			Constraint pk_tbl_clearinghouse_use_cases PRIMARY KEY (use_case_id)
		);

	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_activity_log') Then

		-- Drop Table clearing_house.tbl_clearinghouse_activity_log
		-- Alter Table clearing_house.tbl_clearinghouse_activity_log add column entity_type_id int not null default(0)
		Create Table clearing_house.tbl_clearinghouse_activity_log (
			activity_log_id serial not null,
			use_case_id int not null default(0),
			user_id int not null default(0),
			session_id int not null default(0),
			entity_type_id int not null default(0),
			entity_id int not null default(0),
			execute_start_time date not null,
			execute_stop_time date,
			status_id int not null default(0),
			activity_data text null,
			message text not null default(''),
			Constraint pk_activity_log_id PRIMARY KEY (activity_log_id)
		);

		Create Index idx_clearinghouse_activity_entity_id
			On clearing_house.tbl_clearinghouse_activity_log (entity_type_id, entity_id);

	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_signal_log') Then

		Create Table clearing_house.tbl_clearinghouse_signal_log (
			signal_log_id serial not null,
			use_case_id int not null,
			signal_time date not null,
			email text not null,
			cc text not null,
			subject text not null,
			body text not null,
			Constraint pk_signal_log_id PRIMARY KEY (signal_log_id)
		);

	End If;

    /*********************************************************************************************************************************
    ** Users
    **********************************************************************************************************************************/

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_data_provider_grades') Then

        Create Table clearing_house.tbl_clearinghouse_data_provider_grades (
            grade_id int not null,
            description character varying(255) not null,
            Constraint pk_grade_id PRIMARY KEY (grade_id)
        );

	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_user_roles') Then

        Create Table clearing_house.tbl_clearinghouse_user_roles (
            role_id int not null,
            role_name character varying(255) not null,
            Constraint pk_role_id PRIMARY KEY (role_id)
        );

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_users') Then
		-- Drop Table clearing_house.tbl_clearinghouse_users
        Create Table clearing_house.tbl_clearinghouse_users (
            user_id serial not null,
            user_name character varying(255) not null,
            full_name character varying(255) not null default(''),
            password character varying(255) not null,
            email character varying(1024) not null default (''),
            signal_receiver boolean not null default(false),
            role_id int not null default(1),
            data_provider_grade_id int not null default(2),
            is_data_provider boolean not null default(false),
            create_date date not null,
            Constraint pk_user_id PRIMARY KEY (user_id),
            Constraint fk_tbl_user_roles_role_id FOREIGN KEY (role_id)
                References clearing_house.tbl_clearinghouse_user_roles (role_id) MATCH SIMPLE
                    ON Update NO Action ON DELETE NO ACTION,
            Constraint fk_tbl_data_provider_grades_grade_id FOREIGN KEY (data_provider_grade_id)
                References clearing_house.tbl_clearinghouse_data_provider_grades (grade_id) MATCH SIMPLE
                    ON Update NO Action ON DELETE NO ACTION
        );

		-- Alter table clearing_house.tbl_clearinghouse_users Add column is_data_provider boolean not null default(false)
    End If;

    /*********************************************************************************************************************************
    ** XML content tables - intermediate tables using during process
    **********************************************************************************************************************************/

	If (false) Then

		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_values;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_records;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_columns;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_tables;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_tables;

	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_tables') Then

		Create Table clearing_house.tbl_clearinghouse_submission_tables (
			table_id serial not null,
			table_name character varying(255) not null,
			table_name_underscored character varying(255) not null,
			Constraint pk_tbl_clearinghouse_submission_tables Primary Key (table_id)
		);

		Create Unique Index idx_tbl_clearinghouse_submission_tables_name1
			On clearing_house.tbl_clearinghouse_submission_tables (table_name);

		Create Unique Index idx_tbl_clearinghouse_submission_tables_name2
			On clearing_house.tbl_clearinghouse_submission_tables (table_name_underscored);

	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_xml_content_tables') Then


		Create Table clearing_house.tbl_clearinghouse_submission_xml_content_tables (
			content_table_id serial not null,
			submission_id int not null,
			table_id int not null,
			record_count int not null,
			Constraint pk_tbl_submission_xml_content_meta_tables_table_id Primary Key (content_table_id),
			Constraint fk_tbl_clearinghouse_submission_xml_content_tables Foreign Key (table_id)
			  References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
				On Update NO ACTION ON DELETE Cascade,
            Constraint fk_tbl_clearinghouse_submission_xml_content_tables_sid Foreign Key (submission_id)
                References clearing_house.tbl_clearinghouse_submissions (submission_id) Match Simple
                    On Update NO ACTION ON DELETE Cascade
		);


		Create Unique Index fk_idx_tbl_submission_xml_content_tables_table_name
			On clearing_house.tbl_clearinghouse_submission_xml_content_tables (submission_id, table_id);


	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_xml_content_columns') Then

		Create Table clearing_house.tbl_clearinghouse_submission_xml_content_columns (
			column_id serial not null,
			submission_id int not null,
			table_id int not null,
			column_name character varying(255) not null,
			column_name_underscored character varying(255) not null,
			data_type character varying(255) not null,
			fk_flag boolean not null,
			fk_table character varying(255) null,
			fk_table_underscored character varying(255) null,
			Constraint pk_tbl_submission_xml_content_columns_column_id Primary Key (column_id),
			Constraint fk_tbl_submission_xml_content_columns_table_id Foreign Key (table_id)
			  References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
				On Update NO ACTION ON DELETE Cascade
		);

		Create Unique Index idx_tbl_submission_xml_content_columns_submission_id
			On clearing_house.tbl_clearinghouse_submission_xml_content_columns (submission_id, table_id, column_name);

	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_xml_content_records') Then

		Create Table clearing_house.tbl_clearinghouse_submission_xml_content_records (
			record_id serial not null,
			submission_id int not null,
			table_id int not null,
			local_db_id int null,
			public_db_id int null,
			Constraint pk_tbl_submission_xml_content_records_record_id Primary Key (record_id),
			Constraint fk_tbl_submission_xml_content_records_table_id Foreign Key (table_id)
			  References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
				On Update NO ACTION ON DELETE Cascade

		);

		Create Unique Index idx_tbl_submission_xml_content_records_submission_id
			On clearing_house.tbl_clearinghouse_submission_xml_content_records (submission_id, table_id, local_db_id);

	End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_xml_content_values') Then

		-- Drop Table tbl_submission_xml_content_record_values
		Create Table clearing_house.tbl_clearinghouse_submission_xml_content_values (
			value_id serial not null,
			submission_id int not null,
			table_id int not null,
			local_db_id int not null,
			column_id int not null,
			fk_flag boolean null,
			fk_local_db_id int null,
			fk_public_db_id int null,
			value text null,
			Constraint pk_tbl_submission_xml_content_record_values_value_id Primary Key (value_id),
			Constraint fk_tbl_submission_xml_content_meta_record_values_table_id Foreign Key (table_id)
			  References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
				On Update NO ACTION ON DELETE Cascade

		);

		Create Unique Index idx_tbl_submission_xml_content_record_values_column_id
			On clearing_house.tbl_clearinghouse_submission_xml_content_values (submission_id, table_id, local_db_id, column_id);

	End If;

    /*********************************************************************************************************************************
    ** Submissions
    **********************************************************************************************************************************/

     -- ALTER TABLE metainformation.tbl_upload_contents
     --  OWNER TO seadworker;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_states') Then

        Create Table clearing_house.tbl_clearinghouse_submission_states (
            submission_state_id int not null,
            submission_state_name character varying(255) not null,
            CONSTRAINT pk_submission_state_id PRIMARY KEY (submission_state_id)
        );

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submissions') Then

		--Alter Table clearing_house.tbl_clearinghouse_submissions Drop Column upload_date
		--Alter Table clearing_house.tbl_clearinghouse_submissions Add Column upload_date Date Not Null default now()
		-- Drop table clearing_house.tbl_clearinghouse_users

        Create Table clearing_house.tbl_clearinghouse_submissions
        (
          submission_id serial NOT NULL,
          submission_state_id integer NOT NULL,
          data_types character varying(255),
          upload_user_id integer NOT NULL,
          upload_date Date Not Null default now(),
          upload_content text,
          xml xml,
          status_text text,
          claim_user_id integer,
          claim_date_time date,
          Constraint pk_submission_id PRIMARY KEY (submission_id),
          Constraint fk_tbl_submissions_user_id_user_id FOREIGN KEY (claim_user_id)
              References clearing_house.tbl_clearinghouse_users (user_id) MATCH SIMPLE
                ON UPDATE NO ACTION ON DELETE NO ACTION,
          Constraint fk_tbl_submissions_state_id_state_id FOREIGN KEY (submission_state_id)
              References clearing_house.tbl_clearinghouse_submission_states (submission_state_id) MATCH SIMPLE
                ON UPDATE NO ACTION ON DELETE NO ACTION
        );

        --GRANT ALL ON TABLE metainformation.tbl_upload_contents TO seadworker;
        --COMMENT ON TABLE metainformation.tbl_upload_contents IS 'Table for storing information about an upload. The actual upload is stored in a file separately.';
        --COMMENT ON COLUMN metainformation.tbl_upload_contents.upload_data_types IS 'A series of data types contained in the uploaded data. This list should be separated by something.';

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_sead_create_table_log') Then

        CREATE TABLE "clearing_house"."tbl_clearinghouse_sead_create_table_log" (
            "create_script" text COLLATE "pg_catalog"."default",
            "drop_script" text COLLATE "pg_catalog"."default"
        )
        ;

        ALTER TABLE "clearing_house"."tbl_clearinghouse_sead_create_table_log" OWNER TO "clearinghouse_worker";

        CREATE TABLE "clearing_house"."tbl_clearinghouse_sead_create_view_log" (
            "create_script" text COLLATE "pg_catalog"."default",
            "drop_script" text COLLATE "pg_catalog"."default"
        )
        ;

        ALTER TABLE "clearing_house"."tbl_clearinghouse_sead_create_view_log" OWNER TO "clearinghouse_worker";

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_tables') Then

        CREATE TABLE clearing_house.tbl_clearinghouse_submission_tables
        (
            table_id integer NOT NULL DEFAULT nextval('clearing_house.tbl_clearinghouse_submission_tables_table_id_seq'::regclass),
            table_name character varying(255) COLLATE pg_catalog."default" NOT NULL,
            table_name_underscored character varying(255) COLLATE pg_catalog."default" NOT NULL,
            CONSTRAINT pk_tbl_clearinghouse_submission_tables PRIMARY KEY (table_id)
        );

        ALTER TABLE clearing_house.tbl_clearinghouse_submission_tables OWNER to clearinghouse_worker;

        CREATE UNIQUE INDEX idx_tbl_clearinghouse_submission_tables_name1
            ON clearing_house.tbl_clearinghouse_submission_tables USING btree
            (table_name COLLATE pg_catalog."default")
            TABLESPACE pg_default;

        CREATE UNIQUE INDEX idx_tbl_clearinghouse_submission_tables_name2
            ON clearing_house.tbl_clearinghouse_submission_tables USING btree
            (table_name_underscored COLLATE pg_catalog."default")
            TABLESPACE pg_default;

        GRANT ALL ON TABLE clearing_house.tbl_clearinghouse_submission_tables TO qv;
        GRANT SELECT, UPDATE ON TABLE clearing_house.tbl_clearinghouse_submission_tables TO readers;
        GRANT SELECT ON TABLE clearing_house.tbl_clearinghouse_submission_tables TO seadread;
        GRANT ALL ON TABLE clearing_house.tbl_clearinghouse_submission_tables TO clearinghouse_worker;

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_accepted_submissions') Then

        Create Table clearing_house.tbl_clearinghouse_accepted_submissions
        (
          accepted_submission_id serial NOT NULL,
          process_state_id bool NOT NULL,
          submission_id int,
          upload_file text,
          accept_user_id integer,
          Constraint pk_tbl_clearinghouse_accepted_submissions PRIMARY KEY (accepted_submission_id)
        );

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_reject_entity_types') Then

        Drop Table If Exists clearing_house.tbl_clearinghouse_reject_entity_types;

        Create Table clearing_house.tbl_clearinghouse_reject_entity_types
        (
			entity_type_id int NOT NULL,
			table_id int NULL,
			entity_type character varying(255) NOT NULL,
			Constraint pk_tbl_clearinghouse_reject_entity_types PRIMARY KEY (entity_type_id)
        );

        Create Index fk_clearinghouse_reject_entity_types On clearing_house.tbl_clearinghouse_reject_entity_types (table_id);

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_rejects') Then

        -- alter table clearing_house.tbl_clearinghouse_submission_rejects add column site_id int NOT NULL default(0)
        Create Table clearing_house.tbl_clearinghouse_submission_rejects
        (
			submission_reject_id serial NOT NULL,
			submission_id int NOT NULL,
			site_id int NOT NULL default(0),
			entity_type_id int NOT NULL,
			reject_scope_id int NOT NULL, /* 0, 1=specific, 2=General */
			reject_description text NULL,
			Constraint pk_tbl_clearinghouse_submission_rejects PRIMARY KEY (submission_reject_id),
			Constraint fk_tbl_clearinghouse_submission_rejects_submission_id Foreign Key (submission_id)
			  References clearing_house.tbl_clearinghouse_submissions (submission_id) Match Simple
				On Update NO ACTION ON DELETE Cascade
		);

        Create Index fk_clearinghouse_submission_rejects On clearing_house.tbl_clearinghouse_submission_rejects (submission_id);

    End If;


    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_submission_reject_entities') Then

        Create Table clearing_house.tbl_clearinghouse_submission_reject_entities
        (
			reject_entity_id serial NOT NULL,
			submission_reject_id int NOT NULL,
			local_db_id int NOT NULL,
			Constraint pk_tbl_clearinghouse_submission_reject_entities PRIMARY KEY (reject_entity_id),
			Constraint fk_tbl_clearinghouse_submission_reject_entities Foreign Key (submission_reject_id)
			  References clearing_house.tbl_clearinghouse_submission_rejects (submission_reject_id) Match Simple
				On Update NO ACTION ON DELETE Cascade
		);

        Create Index fk_clearinghouse_submission_reject_entities_submission On clearing_house.tbl_clearinghouse_submission_reject_entities (submission_reject_id);
        Create Index fk_clearinghouse_submission_reject_entities_local_db_id On clearing_house.tbl_clearinghouse_submission_reject_entities (local_db_id);

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_reports') Then

        --Drop Table clearing_house.tbl_clearinghouse_reports

        Create Table clearing_house.tbl_clearinghouse_reports
        (
            report_id int NOT NULL,
            report_name character varying(255),
            report_procedure text not null,
            Constraint pk_tbl_clearinghouse_reports PRIMARY KEY (report_id)
        );

    End If;

    If Not Exists (Select * From INFORMATION_SCHEMA.tables Where table_catalog = CURRENT_CATALOG And table_schema = 'clearing_house' And table_name = 'tbl_clearinghouse_sead_unknown_column_log') Then

        Create Table clearing_house.tbl_clearinghouse_sead_unknown_column_log (
            column_log_id serial not null,
            submission_id int,
            table_name text,
            column_name text,
            column_type text,
            alter_sql text,
            Constraint pk_tbl_clearinghouse_sead_unknown_column_log PRIMARY KEY (column_log_id)
        );

    End If;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_truncate_all_entity_tables
**	Who			Roger Mähler
**	When		2018-03-25
**	What		Truncates all clearinghouse entity tables and resets sequences
**  Note        NOTE! This Function clears ALL entities in CH tables!
**	Uses
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_truncate_all_entity_tables()
Create Or Replace Function clearing_house.fn_truncate_all_entity_tables()
Returns void As $$
    Declare x record;
    Declare command text;
    Declare item_count int;
Begin

    -- Raise 'This error raise must be removed before this function will run';

	For x In (
        Select t.*
        From clearing_house.tbl_clearinghouse_submission_tables t
	) Loop

        command = 'select count(*) from clearing_house.' || x.table_name_underscored || ';';

        Raise Notice '%: %', command, item_count;

        Begin
            Execute command Into item_count;
            If item_count > 0 Then
                command = 'TRUNCATE clearing_house.' || x.table_name_underscored || ' RESTART IDENTITY;';
                Execute command;
            End If;
       Exception
            When undefined_table Then
                Raise Notice 'Missing: %', x.table_name_underscored;
                -- Do nothing, and loop to try the UPDATE again.
       End;

	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_values Restart Identity Cascade;
	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_columns Restart Identity Cascade;
	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_records Restart Identity Cascade;
	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_tables Restart Identity Cascade;
    Truncate Table clearing_house.tbl_clearinghouse_submissions Restart Identity Cascade;
    -- Truncate Table clearing_house.tbl_clearinghouse_xml_temp Restart Identity Cascade;

	End Loop;
	End
$$ Language plpgsql;
