#!/bin/bash

################################################################################
# MYSQL Maintainance, including Setup, Backup, Restore                         #
#                                                                              #
# Copyright (c) Gui Chen <gui.g.chen@gmail.com>. All Rights Reserved.          #
#                                                                              #
# The MIT License (MIT)                                                        #
# Permission is hereby granted, free of charge, to any person obtaining        #
# a copy of this software and associated documentation files (the              #
# “Software”), to deal in the Software without restriction, including          #
# without limitation the rights to use, copy, modify, merge, publish,          #
# distribute, sublicense, and/or sell copies of the Software, and to           #
# permit persons to whom the Software is furnished to do so, subject to        #
# the following conditions:                                                    #
#                                                                              #
# The above copyright notice and this permission notice shall be               #
# included in all copies or substantial portions of the Software.              #
#                                                                              #
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,              #
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF           #
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.       #
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY         #
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,         #
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE            #
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                       #
################################################################################

########################################
# MYSQL SERVER CONFIGURATION           #
#                                      #
# Use as default if not specified in   #
# command line options                 #
########################################
DB_HOST="127.0.0.1"
DB_PORT=3306
DB_USER="root"
DB_PASS=
DB_SOCK=

########################################
# DATABASE COMMON CONFIGURATION        #
########################################
DATABASES=

########################################
# MYSQL BACKUP CONFIGURATION           #
########################################
BACKUP_DIR=`pwd`
BACKUP_DAYS=30
AUTO_TIMEDETECT=

########################################
# MYSQL MAINTAINANCE CONFIGURATION     #
########################################

########################################
# MYSQL BUILDING UP CONFIGURATION      #
########################################

########################################
# GLOBAL VARIABLES                     #
########################################
# Indicates if table using partitions or not
USE_PARTITION=
# Indicates if table using MAXVALUE or not if parition enabled
USE_MAXVALUE=
# Indicates if using group operation when query dates in table
USE_DATEGROUP=
# Indicates column name for datetime field
TIME_COLOMN="time"

########################################
# MYSQL BACKUP CONFIGURATION           #
########################################
MYSQL="mysql"
MYSQLDUMP="mysqldump"

################################################################################
# DATE RELATED ROUTINES                                                        #
#                                                                              #
# The equivalent alternative in shell codes for the same name mysql functions  #
################################################################################

########################################
# Convert from timestamp to datetime   #
# $1: timestamp                        #
# retval: datetime, '%Y-%m-%d'         #
########################################
function from_days()
{
    echo $(date -d @$((($1 - 719528) * 86400)) +%Y-%m-%d)
    return 0
}

########################################
# Convert from datetime to timestamp   #
# $1: datetime, any valid format       #
# retval: timestamp                    #
########################################
function to_days()
{
    echo $(($(date -d "$1" +%s) / 86400 + 719529))
    return 0
}

########################################
# Calculate instance of two dates      #
# $1: datetime 1, any valid format     #
# $2: datetime 2, any valid format     #
# retval: instance by days             #
########################################
function date_diff()
{
    echo $(( ($(date +%s -d "$1") - $(date +%s -d "$2")) / 86400 ))
    return 0
}

########################################
# Get a new date by plus an instance   #
# $1: datetime, '%Y-%m-%d'             #
# $2: instance, like '1 days'          #
# retval: datetime, '%Y-%m-%d'         #
########################################
function date_add()
{
    echo $(date -d "$1 + $2" +%Y-%m-%d)
    return 0
}

########################################
# Get a new date by minus an instance  #
# $1: datetime, '%Y-%m-%d'             #
# $2: instance, like '1 days'          #
# retval: datetime, '%Y-%m-%d'         #
########################################
function date_sub()
{
    echo $(date -d "$1 - $2" +%Y-%m-%d)
    return 0
}

################################################################################
# MYSQL AND MYSQLDUMP OPERATIONS                                               #
#                                                                              #
# Perform query operations via mysql and mysqldump command                     #
################################################################################

########################################
# Get a new date by plus an instance   #
# $1: where condition                  #
# $2: opt, pipe statement              #
########################################
function mysql_exec()
{
    local MYSQL_OPTS="${MYSQL} -s -r -N -u ${DB_USER}"
    if [ -n "${DB_SOCK}" ]; then
        MYSQL_OPTS="${MYSQL_OPTS} -S ${DB_SOCK}"
    else
        MYSQL_OPTS="${MYSQL_OPTS} -h ${DB_HOST}"
    fi
    if [ -n "${DB_PASS}" ]; then
        MYSQL_OPTS="${MYSQL_OPTS} -p${DB_PASS}"
    fi
    if [ "x$2" != "x" ]; then
        echo $(${MYSQL_OPTS} -e "$1\g" | eval "$2")
    else
        echo $(${MYSQL_OPTS} -e "$1\g")
    fi
    return 0
}

########################################
# Get a new date by plus an instance   #
# $1: datetime, '%Y-%m-%d'             #
# $2: instance, like '1 days'          #
# retval: datetime, '%Y-%m-%d'         #
########################################
function mysqldump_exec()
{
    local MYSQLDUMP_OPTS="${MYSQLDUMP} -t -u ${DB_USER}"
    if [ -n "${DB_SOCK}" ]; then
        MYSQLDUMP_OPTS="${MYSQLDUMP_OPTS} -S ${DB_SOCK}"
    else
        MYSQLDUMP_OPTS="${MYSQLDUMP_OPTS} -h ${DB_HOST}"
    fi
    if [ -n "${DB_PASS}" ]; then
        MYSQLDUMP_OPTS="${MYSQLDUMP_OPTS} -p${DB_PASS}"
    fi
    if [ "x$3" != "x" ]; then
        MYSQLDUMP_OPTS="${MYSQLDUMP_OPTS} -w \"$3\""
    fi
    echo $(${MYSQLDUMP_OPTS} $1 $2)
    return 0
}

########################################
# Show all tables of database          #
# $1: database name                    #
########################################
function show_tables()
{
    echo $(mysql_exec "USE $1;SHOW TABLES")
    return 0
}

########################################
# Show table structures                #
# $1: database name                    #
# $2: table name                       #
########################################
function desc_table()
{
    echo $(mysql_exec "DESC $1.$2")
    return 0
}

########################################
# Show table partition names           #
# $1: database name                    #
# $2: table name                       #
########################################
function show_partitions()
{
    local sql="SELECT PARTITION_NAME FROM INFORMATION_SCHEMA.PARTITIONS \
         WHERE TABLE_SCHEMA='$1' AND TABLE_NAME='$2' \
         ORDER BY PARTITION_DESCRIPTION DESC"
    echo $(mysql_exec "$sql")
    return 0
}

########################################
# Check if specified partition existed #
# $1: database name                    #
# $2: table name                       #
# $3: partition name                   #
########################################
function exist_part()
{
    if mysql_exec "SHOW CREATE TABLE $1.$2" | grep -i "PARTITION $3"; then
        return 0
    else
        return 1
    fi
}

########################################
# Try to detect the datetime field     #
# $1: database name                    #
# $2: table name                       #
########################################
function detect_time_column()
{
    echo $(mysql_exec "DESC $1.$2" "grep -i \"time\" | cut -f1")
    return 0
}

################################################################################
# DATABASE BACKUP OPERATIONS                                                   #
#                                                                              #
# Backup by date and backup by partition                                       #
################################################################################

########################################
# Backup partition by given date       #
# $1: date time, %Y-%m-%d              #
# $2: database name                    #
# $3: table name                       #
# $4: opt, use partition or not        #
########################################
function backup_part_by_day()
{
    if [ ! -d "${BACKUP_DIR}/$2/$3" ]; then
        return 1
    fi
    local part_name=$(date -d "$1" +%Y%m%d)
    local bak_file=${BACKUP_DIR}/$2/$3/$3_${part_name}.sql.gz
    if [ -e "${bak_file}" ]; then
        return 1
    fi
    mysqldump_exec $2 $3 "TO_DAYS(${TIME_COLOMN})=$(to_days $1)" | gzip > ${bak_file}
    if [ -n "${USE_PARTITION}" -o "x$4" != "x" ]; then
        mysql_exec "ALTER TABLE $2.$3 DROP PARTITION P${part_name}"
    else
        mysql_exec "DELETE FROM $2.$3 WHERE TO_DAYS(${TIME_COLOMN})=$(to_days $1)"
    fi
    return 0
}

########################################
# Add a new partition by given date    #
# $1: date time, %Y-%m-%d              #
# $2: database name                    #
# $3: table name                       #
# $4: opt, use MAXVALUE or not         #
########################################
function add_part_by_day()
{
    local part_name=$(date -d "$1" +%Y%m%d)
    local part_date=$(( 1 + $(to_days $1) ))
    if [ -n "${USE_MAXVALUE}" -o "x$4" != "x" ]; then
        mysql_exec "ALTER TABLE $2.$3 REORGANIZE PARTITION PFUTURE INTO (\
            PARTITION P${part_name} VALUES LESS THAN (${part_date}),\
            PARTITION PFUTURE VALUES LESS THAN MAXVALUE)"
    else
        mysql_exec "ALTER TABLE $2.$3 ADD PARTITION (\
            PARTITION P${part_name} VALUES LESS THAN (${part_date}))"
    fi
    return 0
}

########################################
# Perform backup by partition          #
# $1: database name                    #
# $2: table name                       #
########################################
function backup_by_partition()
{
    # Make dirs
    mkdir -p ${BACKUP_DIR}/$1/$2

    local today=$(date +%Y-%m-%d)

    local parts=$(show_partitions $1 $2)
    declare -a arr_parts=($(echo ${parts} | tr '\n' ' '))

    local last_date=
    for part in ${arr_parts[@]}
    do
        if [ "$part" = "PFUTURE" ]; then
            USE_MAXVALUE="true"
            continue
        fi

        local diff_date=$(date_diff ${today} ${part/[Pp]/})
        if [ -z "${last_date}" ]; then
            last_date=${part/P/}
            for ((i = 1; i <= ${diff_date}; i++))
            do
                add_part_by_day $(date_add ${last_date} "$i days") $1 $2
            done
        fi

        if [ ${BACKUP_DAYS} -lt ${diff_date} ]; then
            backup_part_by_day ${part/[Pp]/} $1 $2
        fi
    done
    return 0
}

########################################
# Get dates which should be backed up  #
# $1: date time                        #
# $2: database name                    #
# $3: table name                       #
########################################
function show_days_before()
{
    if [ -n "${USE_DATEGROUP}" ]; then
        local that_day=$(date -d "$1" +"%Y-%m-%d %H:%M:%S")
        local sql="SELECT DATE_FORMAT(${TIME_COLOMN}, '%Y-%m-%d') FROM $2.$3 \
            WHERE ${TIME_COLOMN} < '${that_day}' GROUP BY TO_DAYS(${TIME_COLOMN})"
        echo $(mysql_exec "$sql" "tr '\n' ' '")
    else
        local first_day=$(mysql_exec "SELECT DATE_FORMAT(${TIME_COLOMN}, '%Y-%m-%d') FROM $2.$3 LIMIT 1")
        local diff_date=$(date_diff "$1" "${first_day}")
        declare -a arr_days
        for ((i = 0; i < ${diff_date}; i++))
        do
            arr_days[$i]=$(date_add "${first_day}" "$i days")
        done
        echo ${arr_days[@]}
    fi
    return 0
}

########################################
# Perform backup by datetime           #
# $1: database name                    #
# $2: table name                       #
########################################
function backup_by_datetime()
{
    # Make dirs
    mkdir -p ${BACKUP_DIR}/$1/$2

    local today=$(date +%Y-%m-%d)
    local backup_day=$(date_sub ${today} " ${BACKUP_DAYS} days")

    declare -a arr_days=($(show_days_before ${backup_day} $1 $2))

    for day in ${arr_days[@]}
    do
        local part_name=$(date -d "$day" +%Y%m%d)
        local bak_file=${BACKUP_DIR}/$1/$2/$2_${part_name}.sql.gz
        mysqldump_exec $1 $2 "TO_DAYS(${TIME_COLOMN})=$(to_days ${day})" | gzip > ${bak_file}
    done

    local that_day=$(date -d "${backup_day}" +"%Y-%m-%d %H:%M:%S")
    mysql_exec "DELETE FROM $1.$2 WHERE ${TIME_COLOMN} < '${that_day}'"
    return 0
}

########################################
# Perform backup on database           #
# $1: database name                    #
########################################
function db_backup()
{
    local tables=$(show_tables $1)
    for t in ${tables}
    do
        if [ -n "${AUTO_TIMEDETECT}" ]; then
            TIME_COLOMN=$(detect_time_column $1 $t)
        fi
        if [ -z "${TIME_COLOMN}" ]; then
            continue
        fi
        if [ "$(show_partitions $1 $t)" = "NULL" ]; then
            USE_PARTITION=
            backup_by_datetime $1 $t
        else
            USE_PARTITION="true"
            backup_by_partition $1 $t
        fi
    done
}


########################################
# Perform backup on all databases      #
########################################
function do_backup()
{
    for db in ${DATABASES}
    do
        echo "========= Backing up on database ${db} ========="
        db_backup ${db}
    done
    return 0
}

################################################################################
# DATABASE BUILDING UP OPERATIONS                                              #
#                                                                              #
# Build up a database                                                          #
################################################################################

function db_setup()
{
    return 0
}

function do_setup()
{
    for db in ${DATABASES}
    do
        echo "========= Setting up on database ${db} ========="
        db_setup ${db}
    done
    return 0
}

################################################################################
# DATABASE MAINTAINANCE OPERATIONS                                             #
#                                                                              #
# Maintain database by check, repair, optimize, analyze, etc                   #
################################################################################

########################################
# $1: database name                    #
# $2: table name                       #
########################################
function maintain_by_table()
{
    mysql_exec "CHECK TABLE $1.$2"

    mysql_exec "REPAIR TABLE $1.$2"

    mysql_exec "OPTIMIZE TABLE $1.$2"

    mysql_exec "ANALYZe TABLE $1.$2"
}

function db_maintain()
{
    local tables=$(show_tables $1)
    for t in ${tables}
    do
        maintain_by_table $1 $t
    done
    return 0
}

function do_maintain()
{
    for db in ${DATABASES}
    do
        echo "========= Maintainance started on database ${db} ========="
        db_maintain ${db}
    done
    return 0
}

################################################################################
# Parse comman-line arguments and options                                      #
#                                                                              #
# Program entry parse arguments and options, and print usage, version          #
################################################################################

########################################
# Print version of this tool and mysql #
########################################
function print_version()
{
    echo "`basename $0` version: ${VERSION}"
    echo "$(mysql --version)"
    return 0
}

########################################
# Print usage of this tool             #
########################################
function print_usage()
{
    echo "Usage: `basename $0` <backup|setup|maintain> [options]"
    echo ""
    echo "  -H|--host [HOST]    ip address of mysql server (default: 127.0.0.1)"
    echo "  -P|--port [PORT]    port of mysql server (default: 3306)"
    echo "  -u|--user [USER]    login username (default: root)"
    echo "  -p|--pass [PASS]    login password (default: '')"
    echo "  -S|--socket [SOCK]  socket file of mysql deamon (default: UNDEFINED)"
    echo "  -o|--outdir [DIR]   backup folder (default: `pwd`)"
    echo "  -d|--databases [DB] database names to perform (default: aem)"
    return 0
}

########################################
# Parse command-line options           #
# override the default setting         #
########################################
function parse_options()
{
    while [ -n "$1" ];
    do
        case "$1" in
            -H|--host)
                DB_HOST="$2"
                shift
                ;;
            -P|--port)
                DB_PORT=$2
                shift
                ;;
            -u|--user)
                DB_USER="$2"
                shift
                ;;
            -p|--pass)
                DB_PASS="$2"
                shift
                ;;
            -o|--outdir)
                BACKUP_DIR="$2"
                shift
                ;;
            -d|--databases)
                DATABASES="$2"
                shift
                ;;
            *)
                ;;
        esac
        shift
    done
}

########################################
# Parse sub-command in command-line    #
########################################
case "$1" in
    backup)
        shift
        parse_options "$@"
        do_backup
        ;;
    maintain)
        shift
        parse_options "$@"
        do_maintainace
        ;;
    setup)
        shift
        parse_options "$@"
        do_setup
        ;;
    -v|--version)
        print_version
        ;;
    *)
        print_usage
        ;;
esac
