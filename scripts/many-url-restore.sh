#!/bin/bash

# Usage function to display help
usage() {
    echo "Usage: $0 -j '<json_blob>' -p '<db_password>' -s '<sas_key>'"
    echo "  -j: JSON blob containing the configuration"
    echo "  -p: Database password (optional if provided in JSON)"
    echo "  -s: SAS key (optional if provided in JSON)"
    exit 1
}

# Parse command-line arguments
while getopts "j:p:s:" opt; do
    case ${opt} in
        j ) json_blob=$OPTARG ;;
        p ) db_password=$OPTARG ;;
        s ) sas_key=$OPTARG ;;
        * ) usage ;;
    esac
done

# Check if JSON blob is provided
if [ -z "$json_blob" ]; then
    echo "JSON blob is required."
    usage
fi

# Parse the JSON blob using jq
configs=$(echo "$json_blob" | jq -c '.[]')

# Check if JSON is valid
if [ -z "$configs" ]; then
    echo "Invalid JSON or empty configuration."
    exit 1
fi

# Path to the restore script
RESTORE_SCRIPT="./your_restore_script.sh"

# Process each entry in the JSON blob
echo "$configs" | while read -r config; do
    # Extract values from JSON or use command-line values if provided
    local_sas_key=${sas_key:-$(echo "$config" | jq -r '.sas_key')}
    local_password=${db_password:-$(echo "$config" | jq -r '.password')}
    container_url=$(echo "$config" | jq -r '.container_url')
    backup_urls=$(echo "$config" | jq -r '.backup_urls')
    database_name=$(echo "$config" | jq -r '.database_name')
    restore_options=$(echo "$config" | jq -r '.restore_options')

    echo "Restoring $database_name..."

    # Construct the command line for the restore script
    CMD="$RESTORE_SCRIPT -s \"$local_sas_key\" -c \"$container_url\" -b \"$backup_urls\" -d \"$database_name\" -p \"$local_password\""
    
    if [ "$restore_options" != "null" ]; then
        CMD+=" -o \"$restore_options\""
    fi

    # Execute the restore script
    eval $CMD
done
