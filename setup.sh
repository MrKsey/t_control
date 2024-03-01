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
#   - Выполните команду "curl -sOfL "$GIT_URL/setup.sh?$(date +%s)" && sh setup.sh"


GIT_URL="https://raw.githubusercontent.com/MrKsey/t_control/main"

# Определяем каталог для автозапуска скрипта
STARTUP="/etc/init.d"
[ ! -z "$(ls /opt/etc/init.d | grep "^S")" ] && export STARTUP="/opt/etc/init.d"


# -------------  Взаимодействие с пользователем -----------------------------------------------------------

echo
echo "Установить или удалить скрипт?: "
echo "1. Установить / Изменить <-"
echo "2. Удалить"
echo "3. Выход"
echo -n "Введите [1-3]: "

read choice

if [ "$choice" = "3" ]; then
    exit 3
fi

if [ "$choice" = "2" ]; then
    echo
    echo "Удаляем $STARTUP/S97t_control ..."
    $STARTUP/S97t_control stop
    rm $STARTUP/S97t_control
    echo "Удаляем /opt/apps/t_control ..."
    rm -rf /opt/apps/t_control
    echo "Удаление завершено."
    echo
    exit 2
fi

echo
echo "Перед продолжением необходмио создать бота Telegram, получить bot token и chat ID."
echo "Как это сделать см. пример:"
echo "https://sitogon.ru/blog/252-kak-sozdat-telegram-bot-poluchit-ego-token-i-chat-id"
echo
read -p  "Для продолжения нажмите Enter ..." ANS
echo
read -p  "Введите Bot Token и нажмите Enter: " TOKEN
read -p  "Введите Chat ID и нажмите Enter: " CHAT_ID
echo

# ---------------------------------------------------------------------------------------------------------

# Проверка наличия BOT_TOKEN и BOT_CHAT_ID
if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo
    echo "Отсутсвует TOKEN или CHAT ID !"
    echo "Установка не выполнена. Завершение работы скрипта."
    echo
    exit 1
fi

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

# Загрузка файлов
cd $STARTUP
curl -sO "$GIT_URL/S97t_control" && chmod a+x ./S97t_control

mkdir -p /opt/apps/t_control && cd /opt/apps/t_control
curl -sO "$GIT_URL/t_control.sh" && chmod a+x ./t_control.sh
[ ! -f ./cmd_alias.lib ] && curl -sO "$GIT_URL/cmd_alias.lib"
[ ! -f ./cmd_macro.lib ] && curl -sO "$GIT_URL/cmd_macro.lib"
[ ! -f ./cmd_list.txt ] && curl -sO "$GIT_URL/cmd_list.txt"

# Прописать в файле t_control.sh переменные BOT_TOKEN и BOT_CHAT_ID
sed -i "/^BOT_TOKEN=/{h;s/=.*/=${TOKEN}/};\${x;/^$/{s//BOT_TOKEN=${TOKEN}/;H};x}" ./t_control.sh
sed -i "/^BOT_CHAT_ID=/{h;s/=.*/=${CHAT_ID}/};\${x;/^$/{s//BOT_CHAT_ID=${CHAT_ID}/;H};x}" ./t_control.sh

# Запуск ...
$STARTUP/S97t_control restart &

echo
echo "Установка успешно завершена!"
echo "Для справки введите /help в вашем Telegram-боте"
echo

exit 0
