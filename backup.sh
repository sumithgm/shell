#!/bin/bash

# Script Name: remove_service.sh
# Description: Disables, stops, and removes a systemd service.
# Author: Your Name
# Date: YYYY-MM-DD
# Version: 1.0

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the log file location and maximum size (5MB in bytes)
LOG_FILE="/var/log/remove_service.log"
MAX_LOG_SIZE=$((5 * 1024 * 1024))  # 5MB
MAX_BACKUPS=5  # Number of backup files to keep

# Check if the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Trap any script errors and call the error handler.
trap 'error_handler' ERR

# Error handler function
error_handler() {
    log "Error occurred in ${FUNCNAME[1]} on line ${BASH_LINENO[0]}"
    exit 1
}

# Function to rotate the log file if it exceeds the maximum size
rotate_log() {
    if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -ge $MAX_LOG_SIZE ]]; then
        log "Rotating log file: $LOG_FILE has reached or exceeded $MAX_LOG_SIZE bytes."

        # Rename and compress the log file with a timestamp
        timestamp=$(date +'%Y%m%d%H%M%S')
        mv "$LOG_FILE" "$LOG_FILE.$timestamp"
        gzip "$LOG_FILE.$timestamp"

        # Remove old backups, keeping only the most recent $MAX_BACKUPS
        log "Removing old backups, keeping the last $MAX_BACKUPS"
        ls -1tr "$LOG_FILE".*.gz | head -n -"$MAX_BACKUPS" | xargs -r rm -f
    fi
}

# Log function: prints messages to console and appends to a log file
log() {
    local msg="$1"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Rotate the log if needed
    rotate_log
    
    # Print to console
    echo "$timestamp - $msg"
    
    # Append to log file
    echo "$timestamp - $msg" >> "$LOG_FILE"
}

# Function to disable, stop, and remove a systemd service file
remove_service() {
    local service_file="$1"
    local target_path="/etc/systemd/system/$service_file"

    # Check if the service file exists in the systemd directory
    if [[ ! -f "$target_path" ]]; then
        log "Service file $service_file does not exist in $target_path."
        exit 1
    fi

    # Stop the service if it’s running
    log "Stopping service $service_file"
    systemctl stop "$service_file"

    # Disable the service to prevent it from starting on boot
    log "Disabling service $service_file"
    systemctl disable "$service_file"

    # Remove the service file
    log "Removing $target_path"
    rm -f "$target_path"

    # Reload systemd to recognize the removal
    log "Reloading systemd daemon..."
    systemctl daemon-reload
}

# Main script logic
main() {
    log "Starting script..."

    # Example: specify the service file directly in the script
    service_file="example.service"

    # Remove the service
    remove_service "$service_file"

    log "Script completed successfully."
}

# Run the main function
main
