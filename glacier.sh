#!/bin/bash

# Ensure script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script needs to be run with root user privileges."
    echo "Please try using 'sudo -i' to switch to the root user, and then run this script again."
    exit 1
fi

# Check and install required tools (figlet and toilet) and Docker
function setup_environment() {
    echo "Checking and installing required tools..."
    
    if ! command -v figlet &> /dev/null; then
        echo "Installing figlet..."
        sudo apt-get update
        sudo apt-get install -y figlet
    fi
    if ! command -v toilet &> /dev/null; then
        echo "Installing toilet..."
        sudo apt-get install -y toilet
    fi

    if ! command -v docker &> /dev/null; then
        echo "Docker not detected, installing..."
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce
    fi
}

# Display styled "WibuCrypto" banner
function display_banner() {
    clear
    toilet -f future "WibuCrypto" --gay
    echo
    echo "Welcome to WibuCrypto Validator Setup!"
    echo
}

# Install multiple Glacier Verifier nodes from files
function install_multiple_nodes_from_files() {
    PRIVATE_KEYS_FILE="/home/private_keys.txt"
    PROXY_FILE="/home/proxy.txt"

    # Check if files exist
    if [[ ! -f "$PRIVATE_KEYS_FILE" ]]; then
        echo "Error: $PRIVATE_KEYS_FILE not found!"
        return
    fi
    if [[ ! -f "$PROXY_FILE" ]]; then
        echo "Error: $PROXY_FILE not found!"
        return
    fi

    echo "Reading private keys and proxies from files..."
    PRIVATE_KEYS=( $(cat "$PRIVATE_KEYS_FILE") )
    RAW_PROXIES=( $(cat "$PROXY_FILE") )
    
    # Convert RAW_PROXIES to formatted proxies
    PROXIES=()
    for raw_proxy in "${RAW_PROXIES[@]}"; do
        IFS=':' read -r ip port user pass <<< "$raw_proxy"
        formatted_proxy="http://${user}:${pass}@${ip}:${port}"
        PROXIES+=("$formatted_proxy")
    done

    # Ensure both files have the same number of lines
    if [[ ${#PRIVATE_KEYS[@]} -ne ${#PROXIES[@]} ]]; then
        echo "Error: The number of private keys and proxies must match!"
        return
    fi

    echo "Installing ${#PRIVATE_KEYS[@]} nodes..."
    for i in "${!PRIVATE_KEYS[@]}"; do
        PRIVATE_KEY=${PRIVATE_KEYS[i]}
        PROXY=${PROXIES[i]}
        CONTAINER_NAME="glacier-verifier-$((i + 1))"

        echo "Starting node $CONTAINER_NAME with private key and proxy..."
        docker run -d \
            -e PRIVATE_KEY=$PRIVATE_KEY \
            -e HTTP_PROXY=$PROXY \
            -e HTTPS_PROXY=$PROXY \
            --name $CONTAINER_NAME \
            docker.io/glaciernetwork/glacier-verifier:v0.0.1
        echo "Started container: $CONTAINER_NAME"
    done

    echo "All Glacier Verifier nodes have been installed successfully!"
}

# Display menu and handle user selection
function show_menu() {
    while true; do
        display_banner
        echo "Please choose an option:"
        echo "1. Install a single validator node"
        echo "2. Install multiple validator nodes (from files)"
        echo "3. Delete all nodes"
        echo "4. Exit script"
        read -p "Enter your choice: " choice

        case $choice in
            1)
                install_single_node
                ;;
            2)
                install_multiple_nodes_from_files
                ;;
            3)
                delete_all_nodes
                ;;
            4)
                echo "Exiting script. Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
    done
}

# Delete all running Glacier Verifier nodes
function delete_all_nodes() {
    echo "Stopping and removing all Glacier Verifier containers..."
    docker ps -a --filter "name=glacier-verifier" --format "{{.ID}}" | while read -r container_id; do
        docker stop $container_id
        docker rm $container_id
        echo "Removed container: $container_id"
    done
    echo "All Glacier Verifier nodes have been deleted."
}

# Main execution flow
setup_environment
show_menu
