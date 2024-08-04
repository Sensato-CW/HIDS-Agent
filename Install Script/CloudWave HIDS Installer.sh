#!/bin/bash

# Variables
OSSEC_DIR="/var/ossec"
PRELOADED_VARS_PATH="/tmp/preloaded-vars.conf"
CSV_URL="https://raw.githubusercontent.com/Sensato-CW/HIDS-Agent/main/Install%20Script/HIDS%20Keys.csv"
CSV_PATH="/tmp/HIDS_Keys.csv"
SERVER_IP="10.0.3.126"

# Function to ensure all dependencies are installed
ensure_dependencies() {
    echo "Installing required packages..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y build-essential inotify-tools zlib1g-dev libpcre2-dev libevent-dev curl wget
                ;;
            centos|rhel)
                sudo yum install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel curl wget
                ;;
            fedora)
                sudo dnf install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel curl wget
                ;;
            opensuse|suse)
                sudo zypper install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel curl wget
                ;;
            *)
                echo "Unsupported distribution: $ID"
                exit 1
                ;;
        esac
    else
        echo "Unable to determine OS distribution."
        exit 1
    fi
}

# Function to download the HIDS Keys CSV file
download_csv() {
    echo "Downloading HIDS Keys CSV file..."

    # Remove existing file if it exists
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

# Function to get the hostname without the domain
get_system_name() {
    HOSTNAME=$(hostname -s)
    echo "System name: $HOSTNAME"
}

# Function to check if the system is licensed and retrieve the key and server IP
check_license() {
    if [ ! -f "$CSV_PATH" ]; then
        echo "License file not found at $CSV_PATH"
        exit 1
    fi

    local found=0
    local key=""
    local server_ip=""

    # Read the CSV file and check for the system name
    while IFS=, read -r id asset_name asset_type source_ip key; do
        echo "Checking asset: $asset_name"
        # Skip empty lines or headers
        if [[ -z "$id" || "$id" == "ID" ]]; then
            continue
        fi

        # Check if the asset name matches the hostname
        if [[ "$asset_name" == "$HOSTNAME" ]]; then
            echo "System is licensed for CloudWave HIDS Agent. License Key: $key"
            found=1
            server_ip=$source_ip
            key=$key
            break
        fi
    done < "$CSV_PATH"

    # If not found, abort installation
    if [[ $found -ne 1 ]]; then
        echo "System is not licensed for CloudWave HIDS Agent. Installation aborted."
        exit 1
    fi

    # Return the server_ip and key for use in the preloaded-vars.conf
    echo "$server_ip,$key"
}

# Function to create the preloaded-vars.conf for unattended installation
create_preloaded_vars() {
    local server_ip="$1"
    local key="$2"
    echo "Creating preloaded-vars.conf..."
    cat << EOF > "$PRELOADED_VARS_PATH"
USER_LANGUAGE="en"
USER_NO_STOP="y"
USER_INSTALL_TYPE="agent"
USER_DIR="$OSSEC_DIR"
USER_ENABLE_ACTIVE_RESPONSE="y"
USER_ENABLE_SYSCHECK="y"
USER_ENABLE_ROOTCHECK="y"
USER_AGENT_SERVER_IP="$SERVER_IP"
USER_AGENT_KEY="$key"
USER_UPDATE="n"
EOF

    # Ensure the configuration file is readable
    sudo chmod 644 "$PRELOADED_VARS_PATH"
    echo "Preloaded vars file content:"
    cat "$PRELOADED_VARS_PATH"
}

# Function to download and extract the latest OSSEC version
download_and_extract_ossec() {
    echo "Downloading the latest OSSEC..."
    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/ossec/ossec-hids/releases/latest | grep "tarball_url" | cut -d '"' -f 4)
    wget $LATEST_RELEASE_URL -O ossec.tar.gz
    tar -zxvf ossec.tar.gz
    OSSEC_FOLDER=$(tar -tf ossec.tar.gz | head -n 1 | cut -d "/" -f 1)
    cd $OSSEC_FOLDER
}

# Function to install OSSEC using the preloaded-vars.conf for unattended installation
install_ossec() {
    echo "Installing OSSEC..."
    sudo ./install.sh -q -f "$PRELOADED_VARS_PATH" || { echo "OSSEC installation failed."; exit 1; }
    sudo /var/ossec/bin/ossec-control start
    echo "OSSEC installation completed."
}

# Main script execution
ensure_dependencies
download_csv
get_system_name
IFS=',' read -r server_ip key <<< $(check_license)
create_preloaded_vars "$server_ip" "$key"
download_and_extract_ossec
install_ossec

echo "Automated OSSEC installation script finished."
