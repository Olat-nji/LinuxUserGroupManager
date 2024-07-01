#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if the file is passed as an argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

# Define the filename from the argument
FILE=$1

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "File $FILE does not exist."
    exit 1
fi

# Check if the file is empty
if [[ ! -s "$1" ]]; then
    echo "File $FILE is empty."
    exit 1
fi

# Check if file ends with a newline to ensure IFS works well
if [[ $(tail -c 1 "$1") != "" ]]; then
    echo >>"$1"
fi

# Define log and password files
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Create log and password file if they do not exist
touch $LOG_FILE

# Check if the directory /var/secure exists
if [[ ! -d "/var/secure" ]]; then
    # If it doesn't exist, create the directory
    mkdir -p /var/secure
fi

# Create password file if it does not exist and set permissions
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Function to log actions
logger() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>$LOG_FILE
}

# Function to create a user
create_user() {
    local username=$1
    local password=$(openssl rand -base64 12)

    if id -u "$username" >/dev/null 2>&1; then
        logger "User $username already exists, skipping creation."
        return 1
    fi

    useradd -m "$username"
    if [[ $? -ne 0 ]]; then
        logger "Failed to add user $username"
        return 1
    fi

    echo "$username:$password" | chpasswd
    if [[ $? -ne 0 ]]; then
        logger "Failed to set password for user $username"
        return 1
    fi

    echo "$username,$password" >>$PASSWORD_FILE
    logger "User $username created successfully with password stored."
    return 0
}

# Function to create a group if it doesn't exist
create_group() {
    local group=$1

    if ! getent group "$group" >/dev/null; then
        groupadd "$group"
        if [[ $? -ne 0 ]]; then
            logger "Failed to create group $group"
            return 1
        fi
        logger "Group $group created."
    else
        logger "Group $group already exists, skipping creation."
    fi
    return 0
}

# Read the file line by line
while IFS=';' read -r username groups; do

    # Trim leading and trailing whitespace from username and groups
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    if [[ -z "$username" ]]; then
        logger "No username specified, skipping line."
        continue
    fi

    # Create the user and skip to the next iteration if failed
    create_user "$username"

    # Create and add the user to their personal group
    create_group "$username"
    usermod -a -G "$username" "$username"

    logger "User $username added to personal group $username."

    if [[ -n "$groups" ]]; then
        # Split groups by comma and iterate over them
        IFS=',' read -r -a group_array <<<"$groups"
        for group in "${group_array[@]}"; do
            group=$(echo "$group" | xargs)
            create_group "$group"
            usermod -a -G "$group" "$username"
            logger "User $username added to group $group."
        done
    fi

done <"$FILE"
