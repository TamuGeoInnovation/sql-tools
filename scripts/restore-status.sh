#!/bin/bash

# mssql-tools doesn't report the status of an ongoing restore operation even if the STATS option is used in the query.
# To overcome this, this script is designed to poll the sys.dm_exec_requests DMV to get the status of the restore operation.
#
# The script requires the following parameters:
#
# - Database host: Hostname of the SQL Server
# - Login username: Username to connect to the SQL Server. Optional, default is 'sa'
# - Password: Password for the username
# - Query interval: Interval in seconds to poll the DMV. Optional, default is 30 seconds. Set to 0 to run once.

# Function to print usage
print_usage() {
    echo
    echo "Usage: restore-status.sh -h <Database host> -p <Password> [-i <Query interval> -u <Login username>]"
    echo
    echo "Options:"
    echo "  -h: Database host"
    echo "  -u: Login username (default: sa)"
    echo "  -p: Password"
    echo "  -i: Query interval in seconds (default: 30)"
}

# Parse command line options
while getopts ":h:u:p:i:" opt; do
    case ${opt} in
    h)
        database_host=$OPTARG
        ;;
    u)
        username=$OPTARG
        ;;
    p)
        password=$OPTARG
        ;;
    i)
        interval=$OPTARG
        ;;
    \?)
        echo "Invalid option: $OPTARG" 1>&2
        print_usage
        exit 1
        ;;
    :)
        echo "Invalid option: $OPTARG requires an argument" 1>&2
        print_usage
        exit 1
        ;;
    esac
done

# Check if required parameters are provided
if [ -z "$database_host" ] || [ -z "$password" ]; then
    echo "Database host, and password are required."
    print_usage
    exit 1
fi

# Set the default interval to 30 seconds
interval=${interval:-30}
username=${username:-"sa"}

# Function to get the status of the restore operation
get_restore_status() {
    # Query to get the status of the restore operation
    query="SELECT command, text AS Query, percent_complete FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a WHERE r.command IN ('RESTORE DATABASE')"

    # Execute the query and display the results

    #Execute the query and store the results for pretty-printing
    results=$(sqlcmd -S "$database_host" -U "$username" -P "$password" -W -s"|" -Q "$query")

    # Pretty-print the results: current date and time, query, and percent complete
    echo
    echo "Date: $(date)"
    echo

    echo "$results" | awk -F'|' '
        BEGIN {
            print "Command\t\t\tDB Name\t\t\tPercent Complete"
            print "-------\t\t\t-------\t\t\t---------------"
        }
        NR > 2 && $1 ~ /RESTORE DATABASE/ {  # Skip header lines and filter by RESTORE DATABASE
            gsub(/^[ \t]+|[ \t]+$/, "", $1)  # Trim spaces
            gsub(/^[ \t]+|[ \t]+$/, "", $2)
            gsub(/^[ \t]+|[ \t]+$/, "", $3)
            match($2, /\[([^\]]+)\]/)  # Extract database name between brackets
            dbName = substr($2, RSTART + 1, RLENGTH - 2)
            printf "%-15s\t%-20s\t%-16s\n", $1, dbName, $3
        }
    '
    echo
    echo

}

# Poll the DMV at the specified interval
while true; do
    get_restore_status

    if [ "$interval" -eq 0 ]; then
        break
    fi

    sleep $interval
done
