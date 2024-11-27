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

# Read proxy from file
function read_proxy() {
    if [ ! -f "proxy.txt" ]; then
        echo "proxy.txt file not found! Please make sure the proxy.txt file exists."
        exit 1
    fi
    
    # Read proxy from file
    PROXIES=()
    while IFS= read -r line; do
        PROXIES+=("$line")
    done < "proxy.txt"
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

    # Loop through each node creation
    for (( i=1; i<=NODE_COUNT; i++ )); do
        echo "Creating node $i..."

        # Prompt for Private Key for each node
        read -p "Input PrivateKey for node $i (EVM): " YOUR_PRIVATE_KEY
        if [ -z "$YOUR_PRIVATE_KEY" ]; then
            echo "Private Key cannot be empty. Skipping node $i."
            continue
        fi

        # Pull Docker image
        echo "Pulling the latest Docker image for glaciernetwork/glacier-verifier:v0.0.1..."
        docker pull docker.io/glaciernetwork/glacier-verifier:v0.0.1

        # Read proxy for this node from proxy.txt
        PROXY_INDEX=$(( (i - 1) % ${#PROXIES[@]} ))
        PROXY=${PROXIES[$PROXY_INDEX]}
        PROXY_IP=$(echo $PROXY | cut -d':' -f1)
        PROXY_PORT=$(echo $PROXY | cut -d':' -f2)
        PROXY_USER=$(echo $PROXY | cut -d':' -f3)
        PROXY_PASS=$(echo $PROXY | cut -d':' -f4)

        # Set up proxy environment variables for Docker
        echo "Setting up proxy for node $i with proxy $PROXY_IP:$PROXY_PORT"
        export HTTP_PROXY="http://$PROXY_USER:$PROXY_PASS@$PROXY_IP:$PROXY_PORT"
        export HTTPS_PROXY="http://$PROXY_USER:$PROXY_PASS@$PROXY_IP:$PROXY_PORT"

        # Run Docker container for the node
        CONTAINER_NAME="glacier-verifier-node-$i"
        docker run -d \
            -e PRIVATE_KEY=$YOUR_PRIVATE_KEY \
            -e HTTP_PROXY=$HTTP_PROXY \
            -e HTTPS_PROXY=$HTTPS_PROXY \
            --name $CONTAINER_NAME \
            docker.io/glaciernetwork/glacier-verifier:v0.0.1

        echo "Glacier Verifier node $i started successfully with the provided private key and proxy."
    done
}

# Execute script
setup_environment
read_proxy
run_wibucrypto_validator
