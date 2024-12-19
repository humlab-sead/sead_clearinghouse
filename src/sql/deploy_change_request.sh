#!/bin/bash

SHELL=/bin/bash

set -e  # Exit script on any error

script_name=`basename "$0"`
target_folder=
force=0
add_change_request=NO
add_to_git_clone=NO
sead_ccs_folder=
sqitch_command=./docker-sqitch.sh
target_project=subsystem
script_folder=`pwd`
on_schema_exists=drop
author="Roger Mähler"

g_real_path=$(readlink -f "${BASH_SOURCE[0]}")
g_scripts_folder=SCRIPT_DIR=$(dirname "$g_real_path")

function usage() {
    echo "usage: $script_name [--force] [--add-change-request [--sead-ccs-folder=path|--add-to-git-clone]] "
    echo "       advanced option: [--target-folder=dir]"
    echo ""
    echo "       --force                  Force overwrite of existing target folder if exists"
    echo "       --target-folder=dir      Override default target dir (not recommended)"
    echo "       --add-change-request     Add script to SEAD Control System"
    echo "       --sead-ccs-folder=path   Path to SEAD Control System"
    echo "       --add-to-git-clone       Deploy target (as defined in sqitch.conf"
    exit 64
}

for i in "$@"; do
    case $i in
        --target-folder=*)
            target_folder="${i#*=}";
            shift ;;
        --force)
            force=1;
            shift ;;
        --on-schema-exists=*)
            on_schema_exists="${i#*=}"; shift ;;
        --add-change-request)
            add_change_request="YES";
            shift ;;
        --add-to-git-clone)
            add_to_git_clone="YES";
            shift ;;
        --sead-ccs-folder=*)
            sead_ccs_folder="${i#*=}";
            shift ;;
        --help)
            usage ;
            exit 0 ;;
       *)
        echo "error: unknown option $i" ;
        usage ;
        exit 0 ;
       ;;
    esac
done

if [ "$add_to_git_clone" == "YES" ]; then
    sead_ccs_folder=`pwd`/sead_change_control
fi

function get_cr_id() {
    day=$(date +%Y%m%d)
    cr_x="${day}_DDL_CLEARINGHOUSE_SYSTEM"
    echo "${cr_x^^}"
}

function generate_change_request() {

    crid=`get_cr_id`

    rm -rf $target_folder
    mkdir -p $target_folder

    echo "-- Deploy subsystem: $crid"                                                      > $target_folder/${crid}.sql
    echo "-- NOTE DO NOT CHANGE THIS FILE! USE CH ./src/sql/deploy_clearinghouse.sh"      >> $target_folder/${crid}.sql
    echo "/***************************************************************************"   >> $target_folder/${crid}.sql
    echo "Author         $author"                                                         >> $target_folder/${crid}.sql
    echo "Date           $day"                                                            >> $target_folder/${crid}.sql
    echo "Description    Deploy of Clearinghouse Transport System."                       >> $target_folder/${crid}.sql
    echo "Issue          https://github.com/humlab-sead/sead_change_control/issues/215"   >> $target_folder/${crid}.sql
    echo "Prerequisites  "                                                                >> $target_folder/${crid}.sql
    echo "Reviewer"                                                                       >> $target_folder/${crid}.sql
    echo "Approver"                                                                       >> $target_folder/${crid}.sql
    echo "Idempotent     YES"                                                             >> $target_folder/${crid}.sql
    echo "Notes          Use --single-transactin on execute!"                             >> $target_folder/${crid}.sql
    echo "***************************************************************************/"   >> $target_folder/${crid}.sql
    echo ""                                                                               >> $target_folder/${crid}.sql
    echo "set client_encoding = 'UTF8';"                                                  >> $target_folder/${crid}.sql
    echo "set standard_conforming_strings = on;"                                          >> $target_folder/${crid}.sql
    echo "set client_min_messages to warning;"                                            >> $target_folder/${crid}.sql

    if [ "$on_schema_exists" == "drop" ]; then
        echo ""                                                                           >> $target_folder/${crid}.sql
        echo "drop schema if exists clearing_house cascade;"                              >> $target_folder/${crid}.sql
    fi

    echo ""                                                                                 >> $target_folder/${crid}.sql
    echo "create schema if not exists clearing_house authorization clearinghouse_worker;"   >> $target_folder/${crid}.sql
    echo ""                                                                                 >> $target_folder/${crid}.sql
    echo "set role clearinghouse_worker;"                                                   >> $target_folder/${crid}.sql
    echo ""                                                                                 >> $target_folder/${crid}.sql
    echo "\set autocommit off;"                                                             >> $target_folder/${crid}.sql
    echo ""                                                                                 >> $target_folder/${crid}.sql
    echo "\cd /repo/subsystem/deploy"                                                       >> $target_folder/${crid}.sql
    echo ""                                                                                 >> $target_folder/${crid}.sql
    echo "begin;"                                                                           >> $target_folder/${crid}.sql
    echo ""                                                                                 >> $target_folder/${crid}.sql

    for file in $(ls $g_scripts_folder/0[0,1,2,3,4]*.sql); do
        echo "-- $file"                                                                     >> $target_folder/${crid}.sql
        cat $file                                                                           >> $target_folder/${crid}.sql
        echo ""                                                                             >> $target_folder/${crid}.sql
    done

    echo "call clearing_house.create_clearinghouse_model(false);"                           >> $target_folder/${crid}.sql
    echo "call clearing_house.populate_clearinghouse_model();"                              >> $target_folder/${crid}.sql
    echo "call clearing_house.create_public_model(false, false);"                           >> $target_folder/${crid}.sql

    for file in $(ls src/sql/05*.sql); do
        echo ""                                                                             >> $target_folder/${crid}.sql
        echo "-- $file"                                                                     >> $target_folder/${crid}.sql
        cat $file                                                                           >> $target_folder/${crid}.sql
        echo ""                                                                             >> $target_folder/${crid}.sql
    done

    for file in $(ls $g_scripts_folder/review/*.sql); do
        echo ""                                                                             >> $target_folder/${crid}.sql
        echo "-- $file"                                                                     >> $target_folder/${crid}.sql
        cat $file                                                                           >> $target_folder/${crid}.sql
        echo ""                                                                             >> $target_folder/${crid}.sql
    done

    for file in $(ls $g_scripts_folder/reporting/*.sql); do
        echo ""                                                                             >> $target_folder/${crid}.sql
        echo "-- $file"                                                                     >> $target_folder/${crid}.sql
        cat $file                                                                           >> $target_folder/${crid}.sql
        echo ""                                                                             >> $target_folder/${crid}.sql
    done

	echo "commit;"                                                                          >> $target_folder/${crid}.sql
    echo ""                                                                                 >> $target_folder/${crid}.sql
	echo "reset role;"                                                                      >> $target_folder/${crid}.sql

    echo "notice: change request has been generated to $target_folder"
}

function add_change_request_to_change_control_system()
{
    echo "notice: adding change request to ${sead_ccs_folder}..."
    crid=`get_cr_id`

    if [ ! -f $target_folder/${crid}.sql ]; then
        echo "failure: cannot add change request since $target_folder/${crid}.sql is missing"
        exit 64
    fi

    if [ "$add_to_git_clone" == "YES" ]; then
        echo "warning: cloning temporary git repo"
        rm -rf ./sead_change_control
        git clone https://github.com/humlab-sead/sead_change_control.git
    fi

    if [ ! -d $sead_ccs_folder ]; then
        echo "failure: cannot add change request since default CCS project folder $sead_ccs_folder is missing"
        exit 64
    fi

    if [ ! -x $sqitch_command ] && [ ! hash $sqitch_command 2>/dev/null ]; then
        echo "failure: command not found: $sqitch_command"
        exit 64
    fi

    current_folder=`pwd`

    cd $sead_ccs_folder

    target_deploy_file=$sead_ccs_folder/${target_project}/deploy/${crid}.sql

    if [ -f $target_deploy_file ]; then
        echo "failure: ccs task ${crid}.sql already exists (cannot resolve conflict)"
        exit 64
    fi

    chmod +x $sqitch_command

    $sqitch_command add --change-name ${crid} --note "Deploy of Clearinghouse Transport System." -C ./${target_project}

    if [ $? -ne 0 ];  then
        echo "fatal: sqitch add command failed." >&2
        exit 64
    fi

    cd $current_folder

    cp -f $target_folder/${crid}.sql $target_deploy_file

    echo "notice: change request ${crid} has been added to SEAD CSS repository!"
    echo "notice: please remember to commit repository!"
}

function check_setup() {

    if [ "$target_folder" == "" ]; then
        target_folder=`get_cr_id`
        echo "notice: storing data in $target_folder"
    fi

    if [ "$target_folder" == "" ]; then
        usage ;
    fi

    if [ "$on_schema_exists" != "abort" ] && [ "$on_schema_exists" != "drop" ] && [ "$on_schema_exists" != "update" ] ; then
        usage
    fi

    if [ "$on_schema_exists" != "abort" ] && [ "$on_schema_exists" != "drop" ] && [ "$on_schema_exists" != "update" ] ; then
        usage
        exit 64
    fi

    # echo "Deploying SEAD Clearinghouse as $dbuser@$dbhost:$dbport/$dbname"
}

if [ -d "$target_folder" ]; then
    if [ "$force" == "1" ]; then
        echo "notice: removing existing folder $target_folder"
        rm -f $target_folder/*.{sql,gz,txt,log}
        rmdir $target_folder
    else
        echo "error: folder exists! remove or use --force flag"
        exit 64
    fi
fi

check_setup

generate_change_request

if [ "$add_change_request" == "YES" ]; then

    add_change_request_to_change_control_system

fi

