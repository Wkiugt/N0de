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

    # Install figlet and toilet for styled text
    if ! command -v figlet &> /dev/null; then
        echo "Installing figlet..."
        sudo apt-get update
        sudo apt-get install -y figlet
    fi
    if ! command -v toilet &> /dev/null; then
        echo "Installing toilet..."
        sudo apt-get install -y toilet
    fi

    # Install Docker
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

# Read proxies from file
function read_proxy() {
    if [ ! -f "proxy.txt" ]; then
        echo "proxy.txt file not found! Please make sure the proxy.txt file exists."
        exit 1
    fi

    # Read proxies into an array
    PROXIES=()
    while IFS= read -r line; do
        PROXIES+=("$line")
    done < "proxy.txt"
}

# Read private keys from file
function read_private_keys() {
    if [ ! -f "privatekeys.txt" ]; then
        echo "privatekeys.txt file not found! Please make sure the privatekeys.txt file exists."
        exit 1
    fi

    # Read private keys into an array
    PRIVATE_KEYS=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim leading/trailing whitespace
        key=$(echo "$line" | xargs)
        if [[ "$key" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
            PRIVATE_KEYS+=("$key")
        else
            echo "Invalid private key format: $key"
        fi
    done < "privatekeys.txt"

    if [ "${#PRIVATE_KEYS[@]}" -eq 0 ]; then
        echo "No valid private keys found in privatekeys.txt."
        exit 1
    fi

    echo "Loaded ${#PRIVATE_KEYS[@]} private keys."
}

# Delete all nodes
function delete_all_nodes() {
    echo "Deleting all running nodes..."
    docker ps -q --filter "name=glacier-verifier-node-" | xargs -r docker rm -f
    echo "All nodes have been deleted."
}

# Display styled "WibuCrypto" and run Glacier Verifier
function run_wibucrypto_validator() {
    clear
    toilet -f future "WibuCrypto" --gay
    echo
    echo "Welcome to WibuCrypto Validator Setup!"
    echo

    # Prompt for the number of nodes
    read -p "Enter the number of nodes you want to create: " NODE_COUNT
    if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -le 0 ]; then
        echo "Please enter a valid number of nodes."
        exit 1
    fi

    if [ "$NODE_COUNT" -gt "${#PRIVATE_KEYS[@]}" ]; then
        echo "Requested $NODE_COUNT nodes, but only ${#PRIVATE_KEYS[@]} private keys are available in privatekeys.txt."
        exit 1
    fi

    # Loop through each node creation
    for (( i=1; i<=NODE_COUNT; i++ )); do
        echo "Creating node $i..."

        # Get private key
        YOUR_PRIVATE_KEY=${PRIVATE_KEYS[$((i-1))]}
        echo "Using private key: $YOUR_PRIVATE_KEY"

        # Pull Docker image
        echo "Pulling the latest Docker image for glaciernetwork/glacier-verifier:v0.0.1..."
        docker pull docker.io/glaciernetwork/glacier-verifier:v0.0.1

        # Get proxy for the node
        PROXY_INDEX=$(( (i - 1) % ${#PROXIES[@]} ))
        PROXY=${PROXIES[$PROXY_INDEX]}
        PROXY_IP=$(echo $PROXY | cut -d':' -f1)
        PROXY_PORT=$(echo $PROXY | cut -d':' -f2)
        PROXY_USER=$(echo $PROXY | cut -d':' -f3)
        PROXY_PASS=$(echo $PROXY | cut -d':' -f4)
        echo "Using proxy: $PROXY_IP:$PROXY_PORT"

        # Set up proxy environment variables for Docker
        export HTTP_PROXY="http://$PROXY_USER:$PROXY_PASS@$PROXY_IP:$PROXY_PORT"
        export HTTPS_PROXY="http://$PROXY_USER:$PROXY_PASS@$PROXY_IP:$PROXY_PORT"

        # Check for existing container and remove if exists
        CONTAINER_NAME="glacier-verifier-node-$i"
        if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
            echo "Container name $CONTAINER_NAME already exists. Removing it..."
            docker rm -f $CONTAINER_NAME
        fi

        # Run Docker container for the node
        docker run -d \
            -e PRIVATE_KEY=$YOUR_PRIVATE_KEY \
            -e HTTP_PROXY=$HTTP_PROXY \
            -e HTTPS_PROXY=$HTTPS_PROXY \
            --name $CONTAINER_NAME \
            docker.io/glaciernetwork/glacier-verifier:v0.0.1

        echo "Glacier Verifier node $i started successfully."
    done
}

# Main menu
function main_menu() {
    while true; do
        echo
        echo "1. Setup environment"
        echo "2. Run WibuCrypto Validator"
        echo "3. Delete all nodes"
        echo "4. Exit"
        echo
        read -p "Choose an option: " CHOICE

        case $CHOICE in
            1) setup_environment ;;
            2) read_private_keys; read_proxy; run_wibucrypto_validator ;;
            3) delete_all_nodes ;;
            4) exit 0 ;;
            *) echo "Invalid option, please try again." ;;
        esac
    done
}

# Execute script
main_menu
