#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Path to the HIDS Keys CSV file
CSV_PATH="$SCRIPT_DIR/HIDS Keys.csv"

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

    LICENSE_KEY=$(awk -F, -v hostname="$HOSTNAME" '$1 == hostname {print $2}' "$CSV_PATH")

    if [ -z "$LICENSE_KEY" ]; then
        echo "System is not licensed for CloudWave HIDS Agent. Installation aborted."
        exit 1
    else
        echo "System is licensed for CloudWave HIDS Agent. License Key: $LICENSE_KEY"
    fi
}

# Function to install dependencies and CloudWave HIDS Agent (OSSEC) on Debian-based systems
install_debian() {
    echo "Installing CloudWave HIDS Agent on a Debian-based system..."

    apt-get update
    apt-get install -y build-essential inotify-tools zlib1g-dev libpcre2-dev libevent-dev

    wget https://github.com/ossec/ossec-hids/archive/master.tar.gz -O ossec.tar.gz
    tar -zxvf ossec.tar.gz

    cd ossec-hids-master
    ./install.sh

    /var/ossec/bin/ossec-control start

    echo "CloudWave HIDS Agent installation completed on Debian-based system."
}

# Function to install dependencies and CloudWave HIDS Agent (OSSEC) on Red Hat-based systems
install_rhel_based() {
    echo "Installing CloudWave HIDS Agent on a Red Hat-based system..."

    yum update -y
    yum install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel

    wget https://github.com/ossec/ossec-hids/archive/master.tar.gz -O ossec.tar.gz
    tar -zxvf ossec.tar.gz

    cd ossec-hids-master
    ./install.sh

    /var/ossec/bin/ossec-control start

    echo "CloudWave HIDS Agent installation completed on Red Hat-based system."
}

# Function to install dependencies and CloudWave HIDS Agent (OSSEC) on Fedora systems
install_fedora() {
    echo "Installing CloudWave HIDS Agent on a Fedora system..."

    dnf update -y
    dnf install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel

    wget https://github.com/ossec/ossec-hids/archive/master.tar.gz -O ossec.tar.gz
    tar -zxvf ossec.tar.gz

    cd ossec-hids-master
    ./install.sh

    /var/ossec/bin/ossec-control start

    echo "CloudWave HIDS Agent installation completed on Fedora system."
}

# Function to install dependencies and CloudWave HIDS Agent (OSSEC) on SUSE systems
install_suse() {
    echo "Installing CloudWave HIDS Agent on a SUSE-based system..."

    zypper refresh
    zypper install -y gcc make inotify-tools zlib-devel pcre2-devel libevent-devel

    wget https://github.com/ossec/ossec-hids/archive/master.tar.gz -O ossec.tar.gz
    tar -zxvf ossec.tar.gz

    cd ossec-hids-master
    ./install.sh

    /var/ossec/bin/ossec-control start

    echo "CloudWave HIDS Agent installation completed on SUSE-based system."
}

# Main script execution
get_system_name
check_license
detect_distro

case "$DISTRO" in
    debian|ubuntu)
        install_debian
        ;;
    centos|rhel|fedora|oracle)
        install_rhel_based
        ;;
    suse|opensuse)
        install_suse
        ;;
    *)
        echo "Unsupported distribution: $DISTRO $VERSION"
        exit 1
        ;;
esac

echo "CloudWave HIDS Agent installation script finished."
