#!/bin/bash

set -e  # Exit script on any error

if [ -f ~/vault/.default.sead.server ]; then
    dbhost=$(head -n 1 ~/vault/.default.sead.server)
fi

script_name=`basename "$0"`
dbuser=humlab_admin
dbport=5432
dbname=sead_staging
submission_id=0
target_folder=
force=0
do_add_change_request=NO
do_deploy_change_request=NO
deploy_target=
change_request_repository=$HOME/source/sead_change_control
#change_request_repository=`pwd`/sead_change_control
sqitch_command=./docker-sqitch.sh
target_project=submissions

function usage() {
    echo "usage: $script_name [--dbhost=target-server] [--port=port] [--dbname=target-database] --id=x [--force] [--add-change-request] "
    echo "       advanced option: [--target-folder=dir]  [--deploy-change-request --deploy-target=target]"
    echo ""
    echo "       --force                    Force overwrite of existing target folder if exists"
    echo "       --target-folder=dir        Override default target dir (not recommended)"
    echo "       --deploy-change-request    Deploy change request to server and database specified by --deploy-target via the CCS system "
    echo "       --deploy-target=target     Target database as defined in sqitch.conf"
    exit 64
}

for i in "$@"; do
    case $i in
        -h=*|--dbhost=*)
            dbhost="${i#*=}"; shift;;
        -p=*|--port=*)
            dbport="${i#*=}"; shift ;;
        -d=*|--dbname=*)
            dbname="${i#*=}"; shift ;;
        -U=*|--dbuser=*)
            dbuser="${i#*=}"; shift ;;
        -s=*|--id=*|--submission-id=*)
            submission_id="${i#*=}"; shift ;;
        -t=*|--target-folder=*)
            target_folder="${i#*=}"; shift ;;
        -f|--force)
            force=1; shift ;;
        -a|--add-change-request)
            do_add_change_request="YES"; shift ;;
        -x|--deploy-change-request)
            do_deploy_change_request="YES"; shift ;;
        --deploy-target=*)
            deploy_target="${i#*=}"; shift ;;
       *)
        echo "unknown option: $i"
        usage
       ;;
    esac
done

function dbexec() {
    opt=$1
    sql="$2"
    psql --host=$dbhost --username=$dbuser --no-password --dbname=$dbname --single-transaction -q -X -1 -v ON_ERROR_STOP=1 $opt "$sql"
    if [ $? -ne 0 ];  then
        echo "fatal: psql command failed, deploy aborted." >&2
        echo "$sql" >&2
        exit 64
    fi
}

function get_datatype() {
    dt_sql="select min(data_types) from clearing_house.tbl_clearinghouse_submissions where submission_id = $submission_id"
    dt_x=`psql -X -A -d $dbname -U $dbuser -h $dbhost -p 5432 -t -c "$dt_sql"`
    dt_x=${dt_x/ /_}
    echo "$dt_x"
}
function get_cr_id() {
    day=$(date +%Y%m%d)
    zid=`printf "%03d" ${submission_id}`
    dt_y=`get_datatype`
    cr_x="${day}_DML_SUBMISSION_${dt_y^^}_${zid}_COMMIT"
    echo "${cr_x^^}"
}

function generate_data() {

    sql="
        do \$\$
        begin
            perform clearing_house_commit.resolve_primary_keys(${submission_id}, 'public', FALSE);
        end \$\$ language plpgsql;
";

    echo $sql | psql --host=$dbhost --username=$dbuser --no-password --dbname=$dbname -q -X -1 -v ON_ERROR_STOP=1

    dbexec -c "\copy (select * from clearing_house_commit.generate_resolved_submission_copy_script($submission_id, '$target_folder', true)) to STDOUT;" \
        | sed  -e 's/\\n/\n/g' -e 's/\\r/\r/g' -e 's/\\\\/\\/g' >> "$target_folder/copy_out.sql"

    dbexec -f "$target_folder/copy_out.sql"

 }

function generate_deploy() {

    crid=`get_cr_id`

    echo "/***************************************************************************" >> $target_folder/${crid}.sql
    echo "Author         $USER"                                                         >> $target_folder/${crid}.sql
    echo "Date           $day"                                                          >> $target_folder/${crid}.sql
    echo "Description    "                                                              >> $target_folder/${crid}.sql
    echo "Prerequisites  "                                                              >> $target_folder/${crid}.sql
    echo "Reviewer"                                                                     >> $target_folder/${crid}.sql
    echo "Approver"                                                                     >> $target_folder/${crid}.sql
    echo "Idempotent     NO!"                                                           >> $target_folder/${crid}.sql
    echo "Notes          Use --single-transaction on execute!"                          >> $target_folder/${crid}.sql
    echo "***************************************************************************/" >> $target_folder/${crid}.sql

    #echo "BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;"                             >> $target_folder/${crid}.sql
    echo "set constraints all deferred;"                                                >> $target_folder/${crid}.sql
    echo "set client_min_messages to warning;"                                          >> $target_folder/${crid}.sql
    echo "\set autocommit off;"                                                         >> $target_folder/${crid}.sql
    echo "begin;"                                                                       >> $target_folder/${crid}.sql

    # FIXME: relative cd should be enough /repo assumes docker-sqitch
    echo "\cd /repo/submissions/deploy"                                                 >> $target_folder/${crid}.sql

    dbexec -c "\copy (select * from clearing_house_commit.generate_resolved_submission_copy_script($submission_id, '$target_folder', false)) to STDOUT; " \
        | sed  -e 's/\\n/\n/g' -e 's/\\r/\r/g' -e 's/\\\\/\\/g'                         >> $target_folder/${crid}.sql

	echo "select clearing_house_commit.allocate_sequence_ids();"                        >> $target_folder/${crid}.sql
	echo "select clearing_house_commit.commit_submission($submission_id);"              >> $target_folder/${crid}.sql

	echo "commit;"                                                                      >> $target_folder/${crid}.sql
}

function execute_deploy()
{
    crid=`get_cr_id`
    script=$target_folder/${crid}.sql
    if [ ! -f $script ]; then
        echo "notice: nothing is deployed since file $script is missing "
        exit 64
    fi;
    dbexec -f $script
}

function add_change_request_to_repository()
{
    echo "NOTICE: Adding CCS task to ${change_request_repository}..."
    crid=`get_cr_id`

    #echo "WARNING! Cloning temporary git repo"
    #rm -rf ./sead_change_control
    #git clone https://github.com/humlab-sead/sead_change_control.git

    if [ ! -f $target_folder/${crid}.sql ]; then
        echo "failure: cannot add ccs task since $target_folder/${crid}.sql is missing"
        exit 64
    fi

    if [ ! -d $change_request_repository ]; then
        echo "failure: cannot add change request since SEAD change control system folder $change_request_repository is missing."
        echo "         please checkout system to this folder, or change location using."
        exit 64
    fi

    if [ ! -x $sqitch_command ] && [ ! hash $sqitch_command 2>/dev/null ]; then
        echo "failure: sqitch command not found. expected $sqitch_command"
        exit 64
    fi

    current_folder=`pwd`
    #absolute_source_folder=$target_folder
    #if [[ ! "$absolute_source_folder" = /* ]]; then
    #    absolute_source_folder=`pwd`/$absolute_source_folder
    #fi
    #source_deploy_file=$absolute_source_folder/${crid}.sql

    cd $change_request_repository

    #git pull

    # if [ $? -ne 0 ];  then
    #     echo "fatal: git pull of git source failed." >&2
    #     exit 64
    # fi

    deploy_folder=$change_request_repository/${target_project}/deploy
    deploy_file=$deploy_folder/${crid}.sql

    if [ -f $deploy_file ]; then
        echo "failure: ccs task ${crid}.sql already exists (cannot resolve conflict)"
        exit 64
    fi

    chmod +x $sqitch_command

    $sqitch_command add --change-name ${crid} --note "Deploy of Clearinghouse submission {$submission_id}." -C ./${target_project}

    if [ $? -ne 0 ];  then
        echo "fatal: sqitch add command failed." >&2
        exit 64
    fi

    cd $current_folder
    mv -f $target_folder/${crid}.sql $deploy_file
    mv -f $target_folder $deploy_folder/

}

function deploy_change_request_to_staging()
{
    crid=`get_cr_id`
    echo "NOTICE: Adding CCS task ${crid} to ${deploy_target}..."
    $sqitch_command deploy --target $deploy_target -C ./${target_project} ${crid}
}

if [ "$submission_id" == "0" ]; then
    usage ;
fi

if [ "$dbname" == "" ]; then
    usage ;
fi

if [ "`get_datatype`" == "" ]; then
    echo "failure: submission not found or it has no data type specified."
    exit 64
fi

echo "Submission type: `get_datatype` "

if [ "$target_folder" == "" ]; then
    target_folder=`get_cr_id`
    echo "notice: storing data in $target_folder"
fi

if [ "$target_folder" == "" ]; then
    usage ;
fi

if [ "$do_add_change_request" == "NO" ] && [ "$do_deploy_change_request" == "YES" ]; then
    echo "usage: deploy can *only* be done in conjunction with ccs task creation (--add-ccs-task=YES --deploy-ccs-task=YES)"
    usage
fi

if [ "$deploy_target" == "" ] && [ "$do_deploy_change_request" == "YES" ]; then
    echo "usage: sqitch deploy taget must be specified (--deploy-target)"
    usage
fi

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

mkdir -p $target_folder

generate_data
generate_deploy

if [ "$do_add_change_request" == "YES" ]; then

    add_change_request_to_repository

    if [ "$do_deploy_change_request" == "YES" ]; then
        deploy_change_request_to_staging
    fi

fi


