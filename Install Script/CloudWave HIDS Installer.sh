#!/bin/bash

# URL to the HIDS Keys CSV file in the GitHub repository
CSV_URL="https://raw.githubusercontent.com/Sensato-CW/HIDS-Agent/main/Install%20Script/HIDS%20Keys.csv"

# Path to download the HIDS Keys CSV file
CSV_PATH="/tmp/HIDS_Keys.csv"

# Function to download the HIDS Keys CSV file using available tools
download_csv() {
    echo "Downloading HIDS Keys CSV file..."

    # Remove existing file if it exists to ensure a fresh download
    if [ -f "$CSV_PATH" ]; then
        sudo rm -f "$CSV_PATH"
    fi

    # Download using available tools
    if command -v wget > /dev/null; then
        sudo wget -q -O "$CSV_PATH" "$CSV_URL" || { echo "Failed to download HIDS Keys CSV file with wget. Installation aborted."; exit 1; }
    elif command -v curl > /dev/null; then
        sudo curl -sS -o "$CSV_PATH" "$CSV_URL" || { echo "Failed to download HIDS Keys CSV file with curl. Installation aborted."; exit 1; }
    elif command -v python3 > /dev/null || command -v python > /dev/null; then
        python_version=$(command -v python3 > /dev/null && echo "python3" || echo "python")
        sudo $python_version -c "
import urllib.request
try:
    urllib.request.urlretrieve('$CSV_URL', '$CSV_PATH')
    print('HIDS Keys CSV file downloaded successfully.')
except Exception as e:
    print(f'Failed to download HIDS Keys CSV file with Python. Installation aborted: {e}')
    exit(1)
" || exit 1
    else
        echo "No suitable download tool available (wget, curl, python). Installation aborted."
        exit 1
    fi

    echo "HIDS Keys CSV file downloaded successfully."
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        DISTRO="centos"
        VERSION=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
    else
        echo "Unsupported distribution"
        exit 1
    fi
}

# Function to get the hostname without the domain
get_system_name() {
    HOSTNAME=$(hostname -s)
    echo "System name: $HOSTNAME"
}

# Function to check if the system is licensed
check_license() {
    if [ ! -f "$CSV_PATH" ]; then
        echo "License file not found at $CSV_PATH"
        exit 1
    fi

    local found=0

    # Read the CSV file and check for the system name
    while IFS=, read -r id asset_name asset_type source_ip key; do
        # Skip empty lines or headers
        if [[ -z "$id" || "$id" == "ID" ]]; then
            continue
        fi

        # Check if the asset name matches the hostname
        if [[ "$asset_name" == "$HOSTNAME" ]]; then
            echo "System is licensed for CloudWave HIDS Agent. License Key: $key"
            found=1
            break
        fi
    done < "$CSV_PATH"

    # If not found, abort installation
    if [[ $found -ne 1 ]]; then
        echo "System is not licensed for CloudWave HIDS Agent. Installation aborted."
        exit 1
    fi
}

# Function to run the OSSEC install script with simulated input
run_install() {
    echo "Running OSSEC installer with simulated input..."

    # Expect the script to provide the required inputs
    {
        echo "agent"   # Answer for "What kind of installation do you want?"
        echo "y"       # Answer for "Do you want to run the integrity check daemon?"
        echo "y"       # Answer for "Do you want to enable active response?"
        echo "y"       # Answer for "Do you want to start OSSEC HIDS after the installation?"
    } | sudo ./install.sh
}

# Function to install OSSEC (CloudWave HIDS Agent)
install_ossec() {
    echo "Installing CloudWave HIDS Agent..."

    wget https://github.com/ossec/ossec-hids/archive/master.tar.gz -O ossec.tar.gz
    tar -zxvf ossec.tar.gz

    cd ossec-hids-master

    # Run the modified install script with automated input
    run_install

    sudo /var/ossec/bin/ossec-control start

    echo "CloudWave HIDS Agent installation completed."
}

# Main script execution
download_csv
get_system_name
check_license
detect_distro

install_ossec

echo "CloudWave HIDS Agent installation script finished."
