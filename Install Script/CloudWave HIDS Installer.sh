#!/bin/bash

# URL to the HIDS Keys CSV file in the GitHub repository
CSV_URL="https://raw.githubusercontent.com/Sensato-CW/HIDS-Agent/main/Install%20Script/HIDS%20Keys.csv"

# Path to download the HIDS Keys CSV file
CSV_PATH="/tmp/HIDS_Keys.csv"
OSSEC_DIR="/var/ossec"

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
    local key=""
    local server_ip=""

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

# Function to install dependencies
install_dependencies() {
    echo "Installing required packages..."
    case "$DISTRO" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y build-essential inotify-tools zlib1g-dev libpcre2-dev libevent-dev
            ;;
        centos|rhel|oracle)
            sudo yum install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel
            ;;
        fedora)
            sudo dnf install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel
            ;;
        suse|opensuse)
            sudo zypper install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Function to create the preloaded-vars.conf for unattended installation
create_preloaded_vars() {
    local server_ip="$1"
    local key="$2"
    cat << EOF > preloaded-vars.conf
USER_LANGUAGE="en"
USER_NO_STOP="y"
USER_INSTALL_TYPE="agent"
USER_DIR="$OSSEC_DIR"
USER_ENABLE_ACTIVE_RESPONSE="y"
USER_ENABLE_SYSCHECK="y"
USER_ENABLE_ROOTCHECK="y"
USER_AGENT_SERVER_IP="$server_ip"
USER_AGENT_KEY="$key"
USER_UPDATE="n"
USER_WHITE_LIST="127.0.0.1"
EOF
}

# Function to install OSSEC (CloudWave HIDS Agent)
install_ossec() {
    echo "Installing CloudWave HIDS Agent (OSSEC)..."

    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/ossec/ossec-hids/releases/latest | grep "tarball_url" | cut -d '"' -f 4)
    wget $LATEST_RELEASE_URL -O ossec.tar.gz
    tar -zxvf ossec.tar.gz
    OSSEC_FOLDER=$(tar -tf ossec.tar.gz | head -n 1 | cut -d "/" -f 1)

    cd $OSSEC_FOLDER

    # Get server IP and key from the license check
    IFS=',' read -r server_ip key <<< $(check_license)

    # Create preloaded-vars.conf for unattended installation
    create_preloaded_vars "$server_ip" "$key"

    # Run the install script using the preconfigured variables
    sudo ./install.sh -q -f preloaded-vars.conf

    sudo /var/ossec/bin/ossec-control start

    echo "CloudWave HIDS Agent installation completed."
}

# Main script execution
download_csv
get_system_name
detect_distro
install_dependencies
install_ossec

echo "CloudWave HIDS Agent installation script finished."
