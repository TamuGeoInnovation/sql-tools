#!/bin/bash
set -e

#
# This script is designed to retore a MSSQL database from a URL(s) using a Shared Access Signature (SAS) key.
# The script requires the following parameters:
# - SAS key for the Azure container: Required to access the backup file(s)
# - Azure container URL: Required to create the scoped blob container credential
# - Backup URL(s): Comma separated list of backup URLs. Many URL's are supported for striped backups.
# - Database name: Name of database that will be created/overwritten
# - Password: Password for the 'sa' user

# The script will:
# - Drop the existing credential if it exists
# - Create a new credential with the provided SAS key
# - Execute RESTORE FILELISTONLY to extract logical file names
# - Construct the RESTORE DATABASE command
# - Execute the RESTORE DATABASE command
#

# Function to print usage
print_usage() {
    echo
    echo "Usage: single-url-restore.sh -s <SAS key> -c <Container URL> -b <Backup URL(s)> -d <Database name> -p <Password> 
[-h <Hostname>] [-i <Progress interval poll (seconds)>] [-o <Misc SQL RESTORE options>] [-v <Verbose level>]"

    echo
    echo "Options:"
    echo "  -s: SAS key for the Azure container"
    echo "  -c: Azure container URL"
    echo "  -b: Backup URL(s) (comma separated)"
    echo "  -d: Database name"
    echo "  -h: Hostname of the SQL Server (default: localhost)"
    echo "  -i: Progress interval poll in seconds (default: 30)"
    echo "  -p: Password for the 'sa' user"
    echo "  -o: Additional SQL RESTORE options (optional)"
    echo "  -v: Verbosity level (default: None)"

}

# Parse command line options
while getopts ":s:c:b:d:h:i:p:o:v:" opt; do
    case ${opt} in
    s)
        sas_key=$OPTARG
        ;;
    c)
        container_url=$OPTARG
        ;;
    b)
        backup_urls=$OPTARG
        ;;
    d)
        database_name=$OPTARG
        ;;
    h)
        database_host=$OPTARG
        ;;
    i)
        poll_interval=$OPTARG
        ;;
    p)
        password=$OPTARG
        ;;
    o)
        restore_options=$OPTARG
        ;;
    v)
        verbose_level=$OPTARG
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
shift $((OPTIND - 1))

green=$(tput -T xterm setaf 2)
red=$(tput -T xterm setaf 1)
reset=$(tput -T xterm sgr0)

# Check if required options are provided
if [[ -z $sas_key || -z $container_url || -z $backup_urls || -z $database_name || -z $password ]]; then
    echo "Missing required options"
    print_usage
    exit 1
fi

# Set the default verbosity level to 'None'
verbose_level=${verbose_level:-"None"}
echo
echo "Verbosity: $verbose_level"

# If verbose level is set to 'Verbose', print the parameters
if [[ $verbose_level == "Verbose" ]]; then
    echo
    echo "SAS key: $sas_key"
    echo "Container URL: $container_url"
    echo "Backup URLs: $backup_urls"
    echo "Database name: $database_name"
    echo "Password: $password"
    echo
    echo "Restore options: $restore_options"
    echo
fi

echo
echo "${reset}Starting database restore..."
echo

host="localhost"

# If host is provided, use it
if [[ ! -z $database_host ]]; then
    host=$database_host
    echo "Using host: $host"
    echo
else
    echo "Using default host: $host"
    echo
fi

# Drop the credential if it exists
sqlcmd -S $host -U sa -P "$password" -b -Q "IF EXISTS (SELECT * FROM sys.credentials WHERE name = '$container_url') DROP CREDENTIAL [$container_url];"

# Create credential with new SAS key
sqlcmd -S $host -U sa -P "$password" -b -Q "CREATE CREDENTIAL [$container_url] WITH IDENTITY = 'SHARED ACCESS SIGNATURE', SECRET = '$sas_key';"

# Split multiple URLs into an array
IFS=',' read -r -a url_array <<<"$backup_urls"

# Construct URL list for FILELISTONLY
url_list=""
for url in "${url_array[@]}"; do
    url_list+="URL = '$url',"
done

# Remove the trailing comma
url_list="${url_list%,}"

echo "Using URLs:"
echo "$url_list"
echo

# Execute FILELISTONLY and extract logical file names
filelist_output=$(sqlcmd -S $host -U sa -P "$password" -Q "RESTORE FILELISTONLY FROM ${url_list};")

# Extract logical file names from FILELISTONLY output
data_logical_name=$(echo "$filelist_output" | awk 'NR==3 {print $1}')
log_logical_name=$(echo "$filelist_output" | awk 'NR==4 {print $1}')

echo "Data logical name: $data_logical_name"
echo "Log logical name: $log_logical_name"

# Construct the RESTORE DATABASE command
restore_command="RESTORE DATABASE [$database_name] FROM ${url_list} WITH MOVE N'$data_logical_name' TO N'/var/opt/mssql/data/$data_logical_name.mdf', MOVE N'$log_logical_name' TO N'/var/opt/mssql/data/$log_logical_name.ldf'"

# Append restore options if provided
if [[ ! -z $restore_options ]]; then
    restore_command+=",$restore_options"
fi

echo
echo "Attempting database restore..."
echo

echo "$restore_command"
echo

# Set the default poll interval to 30 seconds
poll_interval=${poll_interval:-30}

# Execute the RESTORE DATABASE command
sqlcmd -S $host -U sa -P "$password" -b -Q "$restore_command" >/var/log/restore.log &
pid=$!

while kill -0 $pid &>/dev/null; do
    # Call restore-status.sh
    ./restore-status.sh -h $host -p $password -i 0

    sleep $poll_interval
done

if [ $? -eq 0 ]; then
    echo
    echo "${green}Database '$database_name' has been restored :)${reset}"
    echo
else
    echo
    echo "${red}!!! FAILED to restore database '$database_name' !!!${reset}"
    echo
fi
