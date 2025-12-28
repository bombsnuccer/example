#!/bin/bash

# --- 1. Проверка прав суперпользователя (Root) ---
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)."
   exit 1
fi

# --- 2. Присвоение аргументов ---
PREFIX="${1:-NOT_SET}"
INTERFACE="${2:-NOT_SET}"
ARG_SUBNET="$3"
ARG_HOST="$4"

# --- 3. Функция проверки октета (0-255) ---
# Возвращает 0 (true), если число валидно, и 1 (false), если нет.
is_valid_octet() {
    local num=$1
    # Проверка: является ли целым числом И входит ли в диапазон 0-255
    if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 0 && num <= 255)); then
        return 0
    else
        return 1
    fi
}

# --- 4. Функция сканирования ---
scan_host() {
    local target_ip="$1"
    local iface="$2"
    
    echo "[*] Scanning IP: $target_ip"
    if arping -c 3 -i "$iface" "$target_ip" 2> /dev/null; then
        echo ">>> Host $target_ip is UP"
    fi
}

# --- 5. Валидация PREFIX (XXX.XXX) ---
if [[ "$PREFIX" == "NOT_SET" ]]; then
    echo "Error: PREFIX not set. Usage: $0 <PREFIX> <INTERFACE> [SUBNET] [HOST]"
    exit 1
fi

# Проверка формата X.X
if [[ ! "$PREFIX" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid PREFIX format. Expected 'xxx.xxx' (e.g., 192.168)."
    exit 1
fi

# Разбиваем PREFIX на два числа и проверяем каждое
OCTET1=$(echo "$PREFIX" | cut -d'.' -f1)
OCTET2=$(echo "$PREFIX" | cut -d'.' -f2)

if ! is_valid_octet "$OCTET1" || ! is_valid_octet "$OCTET2"; then
    echo "Error: Invalid PREFIX values. Each octet must be between 0 and 255."
    exit 1
fi

# --- 6. Валидация INTERFACE ---
if [[ "$INTERFACE" == "NOT_SET" ]]; then
    echo "Error: INTERFACE not set."
    exit 1
fi
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "Error: Interface $INTERFACE not found."
    exit 1
fi

# --- 7. Определение диапазонов (SUBNET и HOST) ---

# --- SUBNET ---
if [[ -n "$ARG_SUBNET" ]]; then
    if ! is_valid_octet "$ARG_SUBNET"; then
        echo "Error: SUBNET must be a number between 0 and 255."
        exit 1
    fi
    SUBNET_RANGE="$ARG_SUBNET"
else
    SUBNET_RANGE=$(seq 1 255)
fi

# --- HOST ---
if [[ -n "$ARG_HOST" ]]; then
    if ! is_valid_octet "$ARG_HOST"; then
        echo "Error: HOST must be a number between 0 and 255."
        exit 1
    fi
    HOST_RANGE="$ARG_HOST"
else
    HOST_RANGE=$(seq 1 255)
fi

# --- 8. Основной цикл ---
echo "--- Starting scan: $PREFIX.$SUBNET_RANGE.$HOST_RANGE on $INTERFACE ---"

for SUBNET in $SUBNET_RANGE; do
    for HOST in $HOST_RANGE; do
        scan_host "${PREFIX}.${SUBNET}.${HOST}" "$INTERFACE"
    done
done

echo "--- Scan complete ---"
