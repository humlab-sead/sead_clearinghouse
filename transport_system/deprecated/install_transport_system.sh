#!/bin/bash

set -e

if [ -f ~/vault/.default.sead.server ]; then
    dbhost=$(head -n 1 ~/vault/.default.sead.server)
fi

script_name=`basename "$0"`
dbuser=humlab_admin
dbport=5432
dbname=

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
    echo "usage: $script_name [--dbhost=target-server] [--port=port] [--dbname=target-database]"
    echo ""
    echo "       Please note that this script deploys the system  directly to the target DB."
    echo "       Use this only for testing. Proper install should be carried out by the SEAD CCS."
    echo "       Use ./deploy_transport_system.sh to create a change request in SEAD CCS."
    echo ""
    exit 64
}

function check_install_options() {

    if [ "$dbuser" != "humlab_admin" ]; then
        echo "fatal: script must be rub by user humlab_admin." >&2
        exit 64
    fi
    if [ "$dbhost" == "" ] || [ "$dbname" == "" ]; then
        usage
    fi
}

function install_transport_system() {
    psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --no-password -q -1 -v ON_ERROR_STOP=1 --file ./05_install_transport_system.sql
}

echo "Deploying SEAD Clearinghouse transport system using URI $dbuser@$dbhost:$dbport/$dbname"

check_install_options

echo -n " Running install..."
install_transport_system

echo "done!"
