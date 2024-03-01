#!/bin/sh

# Установщик скрипта для запуска команд на локальном хосте через бота Telegram
# Что делает:
#   - устанавливает необходимые для работы пакеты: jq, sed, grep
#   - скачивает скрипт t_control.sh и сопутствующие файлы в локальный каталог /opt/apps/t_control
#   - создает ссылку в каталое /opt/etc/inti.d для автозапуска скритпа t_control.sh
#   - запускает скрипт t_control.sh

# Как использовать:
#   - Создать бота Telegram, получить bot token и chat ID - https://sitogon.ru/blog/252-kak-sozdat-telegram-bot-poluchit-ego-token-i-chat-id
#   - Подключитсья по ssh к своему роутеру или серверу Linux
#   - Установить пакет curl командой "opkg install curl" (роутер) или "apt install curl" (сервер с debian, ubuntu ...)
#   - Выполните команду "curl -sOfL https://raw.githubusercontent.com/MrKsey/t_control/main/setup.sh?$(date +%s) && sh setup.sh"


STARTUP="/etc/init.d"
[ ! -z "$(ls /opt/etc/init.d | grep "^S")" ] && export STARTUP="/opt/etc/init.d"


# -------------  Взаимодействие с пользователем -----------------------------------------------------------

echo
echo "Установить или удалить скрипт?: "
echo "1. Установить"
echo "2. Удалить"
echo "3. Выход "
echo -n "Введите [1-3]: "

read choice

if [ "$choice" = "3" ]; then
    exit 0
fi

if [ "$choice" = "2" ]; then
    echo
    echo "Удаляем $STARTUP/S97t_control ..."
    rm $STARTUP/S97t_control_2
    echo "Удаляем /opt/apps/t_control ..."
    rm -rf /opt/apps/test
    echo "Удаление завершено."
    echo
    exit 0
fi

echo
echo "Перед продолжением необходмио создать бота Telegram, получить bot token и chat ID."
echo "Как это сделать см. пример:"
echo "https://sitogon.ru/blog/252-kak-sozdat-telegram-bot-poluchit-ego-token-i-chat-id"
echo
read -p  "Для продолжения нажмите Enter ..." ANS
echo
read -p  "Введите Bot Token и нажмите Enter: " BOT_TOKEN
read -p  "Введите Chat ID и нажмите Enter: " BOT_CHAT_ID
echo

# Проверка наличия BOT_TOKEN и BOT_CHAT_ID
if [ -z "$BOT_TOKEN" ] || [ -z "$BOT_CHAT_ID" ]; then
    echo
    echo "Отсутсвует BOT_TOKEN или BOT_CHAT_ID. Установка не выполнена."
    echo "Завршение работы скрипта."
    echo
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------


# Отключаем лишнее взаимодейстивие
export DEBIAN_FRONTEND=noninteractive

# Система управления пакетами
PKG=""
if [ ! -z "$(which opkg)" ]; then
    PKG="opkg"
elif [ ! -z "$(which apt)" ]; then
    PKG="apt --no-install-recommends -y"
fi

if [ -z "$(echo $PKG)" ]; then
    echo "Автоматическая установка пакетов не поддерживается."
    echo "После завершения данного скрипта установите пакеты jq, sed и grep вручную."
else
    # Автоматическая установка необходимых пакетов
    $PKG install jq sed grep
fi
