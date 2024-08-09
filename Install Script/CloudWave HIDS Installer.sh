#!/bin/bash

# Variables
OSSEC_DIR="/var/ossec"
CSV_URL="https://raw.githubusercontent.com/Sensato-CW/HIDS-Agent/main/Install%20Script/HIDS%20Keys.csv"
CSV_PATH="/tmp/HIDS_Keys.csv"
OSSEC_BASE_DIR="./ossec-hids-master"
SERVER_IP="10.0.3.126"

# Function to ensure all dependencies are installed
ensure_dependencies() {
    echo "Installing required packages..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y build-essential zlib1g-dev libpcre2-dev libevent-dev libssl-dev autoconf automake libtool \
                libsqlite3-dev libsystemd-dev libcurl4-openssl-dev curl wget
                ;;
            centos|rhel)
                if ! sudo subscription-manager status >/dev/null 2>&1; then
                    echo "System is not registered with a Red Hat subscription. Attempting to install EPEL manually."
                    sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || {
                        echo "Failed to install EPEL manually. Installation aborted."
                        exit 1
                    }
                fi
                sudo subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms || echo "Failed to enable repositories, trying to install EPEL manually."
                sudo yum install -y gcc make zlib-devel pcre2-devel libevent-devel curl wget systemd-devel openssl-devel || {
                    echo "Some packages could not be installed via yum."
                    exit 1
                }
                ;;
            fedora)
                sudo dnf install -y gcc make zlib-devel pcre2-devel libevent-devel curl wget systemd-devel openssl-devel
                ;;
            opensuse|suse|sles)
                echo "Installing required packages for SUSE..."

                # Refresh repositories
                sudo zypper refresh

                # Install specific packages for OSSEC
                sudo zypper install -y gcc make zlib-devel pcre2-devel libevent-devel curl wget libopenssl-devel systemd-devel sqlite3-devel autoconf automake libtool inotify-tools || {
                    echo "Some packages could not be installed via zypper."
                    exit 1
                }

                echo "Installation of dependencies completed for SUSE."
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

    sleep 2
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
    sleep 2
}

# Function to get the hostname without the domain
get_system_name() {
    HOSTNAME=$(hostname -s)
    echo "System name: $HOSTNAME"
    sleep 2
}

# Function to check if the system is licensed and retrieve the key
check_license() {
    if [ ! -f "$CSV_PATH" ]; then
        echo "License file not found at $CSV_PATH"
        exit 1
    fi

    local found=0
    local license_key=""

    # Read the CSV file and check for the system name
    while IFS=, read -r id asset_name asset_type source_ip key; do
        # Skip empty lines or headers
        if [[ -z "$id" || "$id" == "ID" ]]; then
            continue
        fi

        # Check if the asset name matches the hostname
        if [[ "$asset_name" == "$HOSTNAME" ]]; then
            license_key="$key"
            found=1
            break
        fi
    done < "$CSV_PATH"

    # If not found, set an error message
    if [[ $found -ne 1 ]]; then
        license_key="System is not licensed for CloudWave HIDS Agent. Installation aborted."
    fi

    # Return the key
    echo "$license_key"
}

# Function to create the preloaded-vars.conf for unattended installation
create_preloaded_vars() {
    echo "Creating preloaded-vars.conf..."
    cat << EOF > "$OSSEC_BASE_DIR/etc/preloaded-vars.conf"
USER_LANGUAGE="en"
USER_NO_STOP="y"
USER_INSTALL_TYPE="agent"
USER_DIR="$OSSEC_DIR"
USER_ENABLE_ACTIVE_RESPONSE="n"
USER_ENABLE_SYSCHECK="y"
USER_ENABLE_ROOTCHECK="y"
USER_AGENT_SERVER_IP="$SERVER_IP"
USER_UPDATE="n"
EOF

    # Ensure the configuration file is readable
    sudo chmod 644 "$OSSEC_BASE_DIR/etc/preloaded-vars.conf"
    echo "Preloaded vars file content:"
    cat "$OSSEC_BASE_DIR/etc/preloaded-vars.conf"
    sleep 3
}

# Function to download and extract the latest OSSEC version
download_and_extract_ossec() {
    echo echo
    echo "Downloading the latest HIDS agent..."
    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/ossec/ossec-hids/releases/latest | grep "tarball_url" | cut -d '"' -f 4)
    wget $LATEST_RELEASE_URL -O ossec.tar.gz
    mkdir -p "$OSSEC_BASE_DIR"
    tar -zxvf ossec.tar.gz -C "$OSSEC_BASE_DIR" --strip-components=1
    sleep 3
}

# Function to create the client.keys file for agent authentication
create_client_keys() {
    local encoded_key="$1"

    echo "Creating client.keys file..."
    echo "Encoded key received: '$encoded_key'"  # Debug line to show the received key

    # Trim any whitespace or newlines from the key
    encoded_key=$(echo -n "$encoded_key" | tr -d '[:space:]')

    # Decode the base64 key and write directly to the client.keys file
    decoded_key=$(echo -n "$encoded_key" | base64 --decode)
    echo $decoded_key
    if [ $? -eq 0 ]; then
        echo "$decoded_key" | sudo tee /var/ossec/etc/client.keys > /dev/null
        echo "client.keys file created successfully."
    else
        echo "Failed to decode the key. Please check the key format."
        exit 1
    fi

    sleep 4
}

# Function to install OSSEC using the preloaded-vars.conf for unattended installation
install_ossec() {
    echo "Installing CloudWave HIDS..."
    (cd "$OSSEC_BASE_DIR" && sudo ./install.sh -q)
    echo "CloudWave HIDS installation completed. Licensing application"
    sleep 4
}

# Main script execution
ensure_dependencies
download_csv
get_system_name

# Retrieve the license key
license_key=$(check_license)

# Halt if the license key was not found or is set to the error message
if [ -z "$license_key" ] || [ "$license_key" == "System is not licensed for CloudWave HIDS Agent. Installation aborted." ]; then
    echo "No valid license key found. Installation aborted."
    exit 1
fi

# Debugging: Print the license key before using it
echo "License key before creating client.keys: $license_key"

# Clean build directory on Ubuntu to avoid conflicts
if [ "$ID" == "ubuntu" ] || [ "$ID" == "debian" ]; then
    echo "Cleaning previous build files for Ubuntu/Debian..."
    sudo rm -rf "$OSSEC_BASE_DIR"
fi

download_and_extract_ossec
create_preloaded_vars
install_ossec
create_client_keys "$license_key"

sudo /var/ossec/bin/ossec-control start
sudo rm /tmp/HIDS_Keys.csv

echo "Automated CloudWave HIDS installation script finished."
