# CloudWave HIDS Agent Installation Script

This script automates the installation and configuration of the CloudWave HIDS (Host Intrusion Detection System) Agent across multiple Linux distributions. The script ensures that all necessary dependencies are installed, downloads the required files, and configures the system to run the HIDS Agent.

## Supported Linux Distributions

- Ubuntu
- Debian
- CentOS
- RHEL (Red Hat Enterprise Linux)
- Fedora
- openSUSE
- SUSE Linux Enterprise Server (SLES)

## Prerequisites

Ensure your system is updated before running the script:

```bash
sudo apt-get update   # For Debian/Ubuntu
sudo yum update       # For CentOS/RHEL
sudo dnf update       # For Fedora
sudo zypper update    # For openSUSE/SLES

**Clone the Repository**
Clone this repository to your local machine:
git clone https://github.com/YourUsername/HIDS-Agent.git
cd HIDS-Agent

**Run the Installation Script**
You can run the installation script directly using curl or download it and run locally:

**Run via curl**
curl -sS https://raw.githubusercontent.com/YourUsername/HIDS-Agent/main/Install%20Script/CloudWave%20HIDS%20Installer.sh | sudo bash

Run Locally

Download the script:
wget https://raw.githubusercontent.com/YourUsername/HIDS-Agent/main/Install%20Script/CloudWave%20HIDS%20Installer.sh

Make the script executable:
chmod +x CloudWave%20HIDS%20Installer.sh

Run the script:
sudo ./CloudWave%20HIDS%20Installer.sh

**Script Overview**
This script performs the following actions:

Installs necessary dependencies: The script ensures that all required packages are installed based on the Linux distribution in use.

Downloads the HIDS Keys CSV file: The script downloads a CSV file that contains the license keys required for the HIDS Agent.

Retrieves the system hostname: The script determines the hostname of the system to match it against the CSV file.

Validates the license key: The script checks if the system is licensed for the CloudWave HIDS Agent.

Creates configuration files: If licensed, the script creates the necessary configuration files for unattended installation.

Downloads and extracts the OSSEC HIDS: The script downloads and extracts the latest version of OSSEC HIDS.

Installs the OSSEC HIDS Agent: The script installs the agent using preloaded variables for an unattended installation.

Starts the OSSEC HIDS Agent: Finally, the script starts the HIDS Agent.

Troubleshooting
Common Issues and Solutions
Unsupported Distribution Error: Ensure that your distribution is supported and that the necessary repositories are enabled.

Missing Package Errors: If you encounter errors related to missing packages, verify that the repositories for your distribution are correctly configured.

Installation Aborted Due to Missing License Key: Make sure that the CSV file with license keys is correctly downloaded and includes the license key for your system's hostname.

Logs
If the installation fails, check the terminal output for errors. The script provides verbose output for easy troubleshooting.

Contributing
Contributions are welcome! Please fork this repository and submit a pull request.
