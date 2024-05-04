#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 -s <SAS key> -c <Azure container URL> -b <Backup URL(s)> -d <Database name> -p <Password> [-o <Misc SQL RESTORE options>]"
}

# Parse command line options
while getopts ":s:c:b:d:p:o:" opt; do
    case ${opt} in
        s )
            sas_key=$OPTARG
            ;;
        c )
            container_url=$OPTARG
            ;;
        b )
            backup_urls=$OPTARG
            ;;
        d )
            database_name=$OPTARG
            ;;
        p )
            password=$OPTARG
            ;;
        o )
            restore_options=$OPTARG
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            print_usage
            exit 1
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            print_usage
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Check if required options are provided
if [[ -z $sas_key || -z $container_url || -z $backup_urls || -z $database_name || -z $password ]]; then
    echo "Missing required options"
    print_usage
    exit 1
fi

echo
echo "Starting database restore"
echo

# Drop the credential if it exists
sqlcmd -S localhost -U sa -P "$password" -Q "IF EXISTS (SELECT * FROM sys.credentials WHERE name = '$container_url') DROP CREDENTIAL [$container_url];"

# Create credential with new SAS key
sqlcmd -S localhost -U sa -P "$password" -Q "CREATE CREDENTIAL [$container_url] WITH IDENTITY = 'SHARED ACCESS SIGNATURE', SECRET = '$sas_key';"

# Split multiple URLs into an array
IFS=',' read -r -a url_array <<< "$backup_urls"

# Construct URL list for FILELISTONLY
url_list=""
for url in "${url_array[@]}"; do
    url_list+="URL = '$url',"
done
url_list="${url_list%,}"  # Remove the trailing comma

echo "Using URLs: $url_list"

# Execute FILELISTONLY and extract logical file names
filelist_output=$(sqlcmd -S localhost -U sa -P "$password" -Q "RESTORE FILELISTONLY FROM ${url_list};")

# Extract logical file names from FILELISTONLY output
data_logical_name=$(echo "$filelist_output" | awk 'NR==3 {print $1}')
log_logical_name=$(echo "$filelist_output" | awk 'NR==4 {print $1}')

echo "Data logical name: $data_logical_name"
echo "Log logical name: $log_logical_name"

# Construct the RESTORE DATABASE command
restore_command="RESTORE DATABASE [$database_name] FROM ${url_list} WITH MOVE N'$data_logical_name' TO N'/var/opt/mssql/data/$data_logical_name.mdf', MOVE N'$log_logical_name' TO N'/var/opt/mssql/data/$log_logical_name.ldf'"

echo
echo "RESTORE command: $restore_command"
echo

# Append restore options if provided
if [[ ! -z $restore_options ]]; then
    restore_command+=",$restore_options"
fi

# Execute the RESTORE DATABASE command
sqlcmd -S localhost -U sa -P "$password" -Q "$restore_command"

echo "Database '$database_name' has been restored"