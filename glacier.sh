#!/bin/bash

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
    echo "Please run this script with root privileges."
    exit 1
fi

# Read the proxy list from the file
function read_proxy() {
    if [ ! -f "proxy.txt" ]; then
        echo "proxy.txt file not found. Please create this file before running the script."
        exit 1
    fi

    PROXIES=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove leading and trailing whitespace and carriage return characters
        line=$(echo "$line" | tr -d '\r' | xargs)
        if [ -n "$line" ]; then
            PROXIES+=("$line")
        fi
    done < "proxy.txt"
    
    if [ "${#PROXIES[@]}" -eq 0 ]; then
        echo "Proxy list is empty in proxy.txt."
        exit 1
    fi
}

# Read the private key list from the file
function read_private_keys() {
    if [ ! -f "privatekeys.txt" ]; then
        echo "privatekeys.txt file not found. Please create this file before running the script."
        exit 1
    fi

    PRIVATE_KEYS=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove leading and trailing whitespace and carriage return characters
        line=$(echo "$line" | tr -d '\r' | xargs)
        if [ -n "$line" ]; then
            PRIVATE_KEYS+=("$line")
        fi
    done < "privatekeys.txt"
    
    if [ "${#PRIVATE_KEYS[@]}" -eq 0 ]; then
        echo "Private key list is empty in privatekeys.txt."
        exit 1
    fi
}

# Function to delete all containers
function delete_all_nodes() {
    echo "Removing all running containers..."
    docker ps -q --filter "name=glacier-verifier-node-" | xargs -r docker rm -f
    echo "All containers removed successfully."
}

# Create and run nodes
function create_nodes() {
    echo "Starting node creation..."

    # Check the number of private keys and proxies
    KEY_COUNT=${#PRIVATE_KEYS[@]}
    PROXY_COUNT=${#PROXIES[@]}
    
    if [ "$KEY_COUNT" -eq 0 ] || [ "$PROXY_COUNT" -eq 0 ]; then
        echo "The private key or proxy list is empty. Please check your input files."
        exit 1
    fi

    echo "Total private keys: $KEY_COUNT"
    echo "Total proxies: $PROXY_COUNT"

    # Create a node for each private key
    for (( i=0; i<KEY_COUNT; i++ )); do
        PRIVATE_KEY="${PRIVATE_KEYS[$i]}"
        PROXY="${PROXIES[$((i % PROXY_COUNT))]}" # Rotate proxies if not enough

        # Extract information from proxy
        PROXY_IP=$(echo $PROXY | cut -d':' -f1)
        PROXY_PORT=$(echo $PROXY | cut -d':' -f2)
        PROXY_USER=$(echo $PROXY | cut -d':' -f3)
        PROXY_PASS=$(echo $PROXY | cut -d':' -f4)
        PROXY_AUTH="http://$PROXY_USER:$PROXY_PASS@$PROXY_IP:$PROXY_PORT"

        # Container name
        CONTAINER_NAME="glacier-verifier-node-$((i+1))"

        # Remove container if it already exists
        if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
            echo "Container $CONTAINER_NAME already exists. Removing..."
            docker rm -f $CONTAINER_NAME
        fi

        # Run Docker container
        echo "Creating node $((i+1)) with private key: $PRIVATE_KEY and proxy: $PROXY_IP:$PROXY_PORT"
        docker run -d \
            --name "$CONTAINER_NAME" \
            -e PRIVATE_KEY="$PRIVATE_KEY" \
            -e HTTP_PROXY="$PROXY_AUTH" \
            -e HTTPS_PROXY="$PROXY_AUTH" \
            glaciernetwork/glacier-verifier:v0.0.1 || {
                echo "Failed to create container $CONTAINER_NAME. Please check the details."
                continue
            }

        echo "Node $((i+1)) created successfully."
    done
}

# Main menu
function main_menu() {
    echo
    echo "1. Read the list of private keys and proxies"
    echo "2. Create nodes"
    echo "3. Delete all containers"
    echo "4. Exit"
    echo
    read -p "Select an option: " CHOICE

    case $CHOICE in
        1)
            read_private_keys
            read_proxy
            echo "Successfully read the private key and proxy lists."
            ;;
        2)
            read_private_keys
            read_proxy
            create_nodes
            ;;
        3)
            delete_all_nodes
            ;;
        4)
            echo "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
}

# Start the script
main_menu
