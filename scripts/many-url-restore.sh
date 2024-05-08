#!/bin/bash
set -e

# Usage function to display help
usage() {
    echo "Usage: $0 -j '<json_blob>' -p '<db_password>' -s '<sas_key>' -v '<verbosity>'"
    echo "  -j: JSON blob containing the configuration"
    echo "  -o: Additional restore options (optional)"
    echo "  -p: Database password (optional if provided in JSON)"
    echo "  -s: SAS key (optional if provided in JSON)"
    echo "  -v: Verbosity level (optional, default: Default, options: None, Verbose)"
    exit 1
}

# Parse command-line arguments
while getopts "j:o:p:s:v:" opt; do
    case ${opt} in
        j ) json_blob=$OPTARG ;;
        o ) restore_options=$OPTARG ;;
        p ) db_password=$OPTARG ;;
        s ) sas_key=$OPTARG ;;
        v ) verbosity=$OPTARG ;;
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
RESTORE_SCRIPT="./single-url-restore.sh"

# Process each entry in the JSON blob
echo "$configs" | while read -r config; do
    # Extract values from JSON or use command-line values if provided
    local_sas_key=${sas_key:-$(echo "$config" | jq -r '.sasKey')}
    local_password=${db_password:-$(echo "$config" | jq -r '.pwd')}
    container_url=$(echo "$config" | jq -r '.containerUrl')
    backup_urls=$(echo "$config" | jq -r '.urls')
    database_host=$(echo "$config" | jq -r '.host')
    database_name=$(echo "$config" | jq -r '.db')
    verbosity=${verbosity:-"None"}

    echo
    echo "Restoring $database_name..."

    cmd=(
        $RESTORE_SCRIPT                    # This should be the actual command you want to execute
        -s "$local_sas_key"
        -c "$container_url"
        -b "$backup_urls"
        -d "$database_name"
        -p "$local_password"
        -h "$database_host"
        -v "$verbosity"
    )
    
    if [ -n "$restore_options" ]; then
        cmd+=(-o "$restore_options")
    fi

    # If sas_key or password are null, skip the entry
    if [ "$local_sas_key" == "null" ] || [ "$local_password" == "null" ]; then
        echo "Skipping entry due to missing SAS key or password."
        continue
    fi

    # Execute the restore script
    "${cmd[@]}"

done
