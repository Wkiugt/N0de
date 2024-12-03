#!/bin/bash

# Kiểm tra quyền root
if [ "$(id -u)" != "0" ]; then
    echo "Vui lòng chạy script với quyền root."
    exit 1
fi

# Đọc danh sách proxy từ file
function read_proxy() {
    if [ ! -f "proxy.txt" ]; then
        echo "Không tìm thấy file proxy.txt. Vui lòng tạo file này trước khi chạy script."
        exit 1
    fi

    PROXIES=()
    while IFS= read -r line || [ -n "$line" ]; do
        PROXIES+=("$line")
    done < "proxy.txt"
    
    if [ "${#PROXIES[@]}" -eq 0 ]; then
        echo "Danh sách proxy trống trong proxy.txt."
        exit 1
    fi
}

# Đọc danh sách private key từ file
function read_private_keys() {
    if [ ! -f "privatekeys.txt" ]; then
        echo "Không tìm thấy file privatekeys.txt. Vui lòng tạo file này trước khi chạy script."
        exit 1
    fi

    PRIVATE_KEYS=()
    while IFS= read -r line || [ -n "$line" ]; do
        PRIVATE_KEYS+=("$line")
    done < "privatekeys.txt"
    
    if [ "${#PRIVATE_KEYS[@]}" -eq 0 ]; then
        echo "Danh sách private keys trống trong privatekeys.txt."
        exit 1
    fi
}

# Hàm xóa tất cả container
function delete_all_nodes() {
    echo "Đang xóa tất cả container đang chạy..."
    docker ps -q --filter "name=glacier-verifier-node-" | xargs -r docker rm -f
    echo "Hoàn thành việc xóa container."
}

# Tạo và chạy các node
function create_nodes() {
    echo "Bắt đầu tạo các node..."

    # Kiểm tra số lượng private keys và proxies
    KEY_COUNT=${#PRIVATE_KEYS[@]}
    PROXY_COUNT=${#PROXIES[@]}
    
    if [ "$KEY_COUNT" -eq 0 ] || [ "$PROXY_COUNT" -eq 0 ]; then
        echo "Danh sách private keys hoặc proxies trống. Kiểm tra lại file input."
        exit 1
    fi

    echo "Tổng số private keys: $KEY_COUNT"
    echo "Tổng số proxies: $PROXY_COUNT"

    # Tạo node cho từng private key
    for (( i=0; i<KEY_COUNT; i++ )); do
        PRIVATE_KEY="${PRIVATE_KEYS[$i]}"
        PROXY="${PROXIES[$((i % PROXY_COUNT))]}" # Xoay vòng proxy nếu thiếu

        # Lấy thông tin từ proxy
        PROXY_IP=$(echo $PROXY | cut -d':' -f1)
        PROXY_PORT=$(echo $PROXY | cut -d':' -f2)
        PROXY_USER=$(echo $PROXY | cut -d':' -f3)
        PROXY_PASS=$(echo $PROXY | cut -d':' -f4)
        PROXY_AUTH="http://$PROXY_USER:$PROXY_PASS@$PROXY_IP:$PROXY_PORT"

        # Tên container
        CONTAINER_NAME="glacier-verifier-node-$((i+1))"

        # Xóa container nếu tồn tại
        if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
            echo "Container $CONTAINER_NAME đã tồn tại. Đang xóa..."
            docker rm -f $CONTAINER_NAME
        fi

        # Chạy container Docker
        echo "Đang tạo node $((i+1)) với private key: $PRIVATE_KEY và proxy: $PROXY_IP:$PROXY_PORT"
        docker run -d \
            --name "$CONTAINER_NAME" \
            -e PRIVATE_KEY="$PRIVATE_KEY" \
            -e HTTP_PROXY="$PROXY_AUTH" \
            -e HTTPS_PROXY="$PROXY_AUTH" \
            glaciernetwork/glacier-verifier:v0.0.1 || {
                echo "Không thể tạo container $CONTAINER_NAME. Kiểm tra lại thông tin."
                continue
            }

        echo "Node $((i+1)) đã được tạo thành công."
    done
}

# Menu chính
function main_menu() {
    echo
    echo "1. Đọc danh sách private keys và proxies"
    echo "2. Tạo các node"
    echo "3. Xóa tất cả container"
    echo "4. Thoát"
    echo
    read -p "Chọn một tùy chọn: " CHOICE

    case $CHOICE in
        1)
            read_private_keys
            read_proxy
            echo "Đã đọc danh sách private keys và proxies thành công."
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
            echo "Thoát script. Tạm biệt!"
            exit 0
            ;;
        *)
            echo "Tùy chọn không hợp lệ. Vui lòng thử lại."
            ;;
    esac
}

# Bắt đầu script
main_menu
