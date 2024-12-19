#!/bin/bash

set -e  # Exit script on any error

#EXPORT PGOPTIONS='--client-min-messages=warning'

if [ -f ~/vault/.default.sead.server ]; then
    dbhost=$(head -n 1 ~/vault/.default.sead.server)
fi

dbuser=clearinghouse_worker
dbport=5432
dbname=sead_staging_20190521071657

on_schema_exists=abort

for i in "$@"; do
    case $i in
        -h=*|--dbhost=*)
            dbhost="${i#*=}"; shift;;
        -p=*|--port=*)
            dbport="${i#*=}"; shift ;;
        -d=*|--dbname=*)
            dbname="${i#*=}"; shift ;;
        -u=*|--dbuser=*)
            dbuser="${i#*=}"; shift ;;
        -x|--on-schema-exists=*)
            on_schema_exists="${i#*=}"; shift ;;
       *);;
    esac
done

function usage() {
    echo "usage: install_clearinghouse_database.bash [--dbhost=target-server] [--port=port] [--dbname=target-database] [--on-schema-exists=abort|drop|update]"
    exit 64
}

function check_setup() {

    if [ "$dbuser" != "clearinghouse_worker" ]; then
        echo "FATAL: clearinghouse DB must be initialized by user clearinghouse_worker." >&2
        exit 64
    fi
    if [ "$dbhost" == "" ] || [ "$dbname" == "" ]; then
        usage
    fi
    if [ "$on_schema_exists" != "abort" ] && [ "$on_schema_exists" != "drop" ] && [ "$on_schema_exists" != "update" ] ; then
        usage
    fi
    echo "Deploying SEAD Clearinghouse as $dbuser@$dbhost:$dbport/$dbname"
}

function dbexec() {
    database=$1
    username=$2
    sql=$3
    psql --host=$dbhost --username=$username --no-password --dbname=$database -q -X -1 -v ON_ERROR_STOP=1 --command "$sql"
    if [ $? -ne 0 ];  then
        echo "FATAL: Deploy aborted." >&2
        echo "FATAL: psql command failed!" >&2
        echo "$sql" >&2
        exit 64
    fi
}

function drop_schema() {
    echo "Dropping schema..."
    sql="drop schema if exists clearing_house cascade;"
    dbexec "$dbname" "clearinghouse_worker" "$sql"  > /dev/null 2>&1
}

function create_schema() {
    echo "Creating schema..."
    sql="create schema clearing_house;"
    dbexec "$dbname" "clearinghouse_worker" "$sql"
}

function set_permissions() {
    echo "Setting worker permissions..."
    psql --host=$dbhost --port=$dbport --username=humlab_admin --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF
        alter user clearinghouse_worker createdb;
        grant all privileges on database $dbname to clearinghouse_worker;
        grant connect on database $dbname to clearinghouse_worker;
EOF
}

function assign_privileges() {
    psql --host=$dbhost --port=$dbport --username=humlab_admin --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF

        grant usage on schema public, sead_utility to clearinghouse_worker;
        grant all privileges on all tables in schema public, sead_utility to clearinghouse_worker;
        grant all privileges on all sequences in schema public, sead_utility to clearinghouse_worker;
        grant execute on all functions in schema public, sead_utility to clearinghouse_worker;

        alter default privileges in schema public, sead_utility
        grant all privileges on tables to clearinghouse_worker;
        alter default privileges in schema public, sead_utility
        grant all privileges on sequences to clearinghouse_worker;

EOF
}

function setup_schema() {
    echo "Initializing schema..."
    sql="select exists(select from information_schema.schemata where schema_name = 'clearing_house')"
    schema_exists=$( psql --host=$dbhost --username=$dbuser --no-password --dbname=$dbname -tAc "$sql" )
    if [ "$schema_exists" = 't' ]
    then
        if [ "$on_schema_exists" == "drop" ]; then
            drop_schema
            create_schema
        elif [ "$on_schema_exists" == "update" ]; then
            echo "Action: Update of existing database requested"
        else
            echo "FATAL: Schema exists, use --on-schema-exists=[drop|update] to resolve conflict"
            exit 64
        fi
    else
        create_schema
    fi
}

function install_scripts() {
    echo "Setting worker permissions..."
    psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF

        set client_min_messages to warning;

        \i '01_utility_functions.sql'
        \i '02_create_clearinghouse_model.sql'
        \i '02_populate_clearinghouse_model.sql'
        \i '03_create_public_model.sql'
EOF
}

function create_model() {
    echo "Installing schema..."
    psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --no-password -q -1 -v ON_ERROR_STOP=1 <<EOF

        set client_min_messages to warning;

        call clearing_house.create_clearinghouse_model(false);
        call clearing_house.populate_clearinghouse_model();
        call clearing_house.create_public_model(false, false);

        \i '04_copy_xml_to_rdb.sql'
EOF
}

function install_reports() {
    echo "Installing report procedures..."
    psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --no-password -q -1 -v ON_ERROR_STOP=1 <<EOF

        set client_min_messages to warning;

        \i '05_review_ceramic_values.sql'
        \i '05_review_dataset.sql'
        \i '05_review_sample.sql'
        \i '05_review_sample_group.sql'
        \i '05_review_site.sql'

        \i '06_report_procedures.sql'
EOF
}

check_setup
set_permissions
setup_schema
install_scripts
create_model
install_reports
assign_privileges
