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

# Display styled "WibuCrypto" and run Glacier Verifier
function run_wibucrypto_validator() {
    clear
    toilet -f future "WibuCrypto" --gay
    echo
    echo "Welcome to WibuCrypto Validator Setup!"
    echo

    # Check if files exist
    if [ ! -f "privatekeys.txt" ]; then
        echo "Error: privatekeys.txt not found."
        exit 1
    fi
    if [ ! -f "proxy.txt" ]; then
        echo "Error: proxy.txt not found."
        exit 1
    fi

    # Read private keys and proxies
    PRIVATE_KEYS=($(cat privatekeys.txt))
    PROXIES=($(cat proxy.txt))
    
    # Ensure matching number of proxies and private keys
    if [ "${#PRIVATE_KEYS[@]}" -ne "${#PROXIES[@]}" ]; then
        echo "Error: The number of private keys does not match the number of proxies."
        exit 1
    fi

    # Pull Docker image
    echo "Pulling the latest Docker image for glaciernetwork/glacier-verifier:v0.0.1..."
    docker pull docker.io/glaciernetwork/glacier-verifier:v0.0.1

    # Run Docker containers
    for i in "${!PRIVATE_KEYS[@]}"; do
        PRIVATE_KEY=${PRIVATE_KEYS[$i]}
        PROXY=${PROXIES[$i]}
        CONTAINER_NAME="glacier-verifier-$((i+1))"
        echo "Starting node $((i+1)) with container name: $CONTAINER_NAME using proxy: $PROXY..."
        
        docker run -d \
            -e PRIVATE_KEY="$PRIVATE_KEY" \
            -e HTTP_PROXY="$PROXY" \
            -e HTTPS_PROXY="$PROXY" \
            --name "$CONTAINER_NAME" \
            docker.io/glaciernetwork/glacier-verifier:v0.0.1
    done

    echo "${#PRIVATE_KEYS[@]} Glacier Verifier containers started successfully with the provided private keys and proxies."
}

# Execute script
setup_environment
run_wibucrypto_validator
