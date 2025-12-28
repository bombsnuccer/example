#!/bin/bash

# --- 1. Проверка прав суперпользователя (Root) ---
if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт должен быть запущен с правами root (используйте sudo)."
   exit 1
fi

# --- 2. Присвоение аргументов переменным ---
PREFIX="${1:-NOT_SET}"
INTERFACE="${2:-NOT_SET}"
ARG_SUBNET="$3"
ARG_HOST="$4"

# --- 3. Функция сканирования (чтобы избежать дублирования кода) ---
scan_host() {
    local target_ip="$1"
    local iface="$2"

    echo "[*] Scanning IP: $target_ip"
    # Используем -c 1 для ускорения демонстрации, или -c 3 как в оригинале
    # grep нужен, чтобы выводить только успешные ответы (опционально для чистоты)
    if arping -c 3 -i "$iface" "$target_ip" 2> /dev/null; then
        echo ">>> Host $target_ip is UP"
    fi
}

# --- 4. Валидация обязательных параметров ---

# Проверка PREFIX (формат XXX.XXX)
if [[ "$PREFIX" == "NOT_SET" ]]; then
    echo "Ошибка: PREFIX (первый аргумент) не задан."
    echo "Использование: $0 <PREFIX> <INTERFACE> [SUBNET] [HOST]"
    exit 1
fi

if [[ ! "$PREFIX" =~ ^[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Ошибка: Неверный формат PREFIX. Ожидается формат 'xxx.xxx' (например, 192.168)."
    exit 1
fi

# Проверка INTERFACE
if [[ "$INTERFACE" == "NOT_SET" ]]; then
    echo "Ошибка: INTERFACE (второй аргумент) не задан."
    exit 1
fi

# Проверка существования интерфейса (дополнительная проверка)
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "Ошибка: Интерфейс $INTERFACE не найден в системе."
    exit 1
fi


# --- 5. Определение диапазонов для циклов ---

# Логика для SUBNET (3-й октет)
if [[ -n "$ARG_SUBNET" ]]; then
    # Если аргумент передан, проверяем регулярным выражением (число 1-3 цифры)
    if [[ ! "$ARG_SUBNET" =~ ^[0-9]{1,3}$ ]]; then
        echo "Ошибка: SUBNET должен быть числом."
        exit 1
    fi
    # Диапазон - только одно число
    SUBNET_RANGE="$ARG_SUBNET"
else
    # Если не передан - сканируем от 1 до 255
    SUBNET_RANGE=$(seq 1 255)
fi

# Логика для HOST (4-й октет)
if [[ -n "$ARG_HOST" ]]; then
    # Если аргумент передан, проверяем регулярным выражением
    if [[ ! "$ARG_HOST" =~ ^[0-9]{1,3}$ ]]; then
        echo "Ошибка: HOST должен быть числом."
        exit 1
    fi
    # Диапазон - только одно число
    HOST_RANGE="$ARG_HOST"
else
    # Если не передан - сканируем от 1 до 255
    HOST_RANGE=$(seq 1 255)
fi

# --- 6. Основной цикл сканирования ---
echo "--- Запуск сканирования сети: $PREFIX.$SUBNET_RANGE.$HOST_RANGE на интерфейсе $INTERFACE ---"

for SUBNET in $SUBNET_RANGE; do
    for HOST in $HOST_RANGE; do
        # Формируем IP адрес
        CURRENT_IP="${PREFIX}.${SUBNET}.${HOST}"

        # Вызов функции
        scan_host "$CURRENT_IP" "$INTERFACE"
    done
done

echo "--- Сканирование завершено ---"