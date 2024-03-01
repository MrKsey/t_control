#!/bin/sh

# Установщик скрипта для запуска команд на локальном хосте через бота Telegram
# Что делает:
#   - устанволивает необходимые для работы пакеты curl и jq
#   - скачивает скрипт t_control.sh и сопутствующие файлы в локальный каталог /opt/apps/t_control
#   - создает ссылку в каталое /opt/etc/inti.d для автозапуска скритпа t_control.sh
#   - запускает скрипт t_control.sh

# Как использовать:
#   - Подключитесь по ssh к своему роутеру или серверу Linux.
#   - Установите пакет curl командой "opkg install curl" (роутер) или "apt install curl" (сервер)
#   - Выполните команду "curl -sOfL http://kvas.zeleza.ru/upgrade && sh upgrade"

# Отключаем случайный запуск псевдографических программ (типа, Midnight Commander)
export TERM=dumb

# Отключаем лишнее взаимодейстивие с пользователем
export DEBIAN_FRONTEND=noninteractive


# Система управления пакетами
PKG=""
if [ ! -z "$(which opkg)" ]; then
    PKG="opkg"
elif [ ! -z "$(which apt)" ]; then
    PKG="apt --no-install-recommends -y"
fi

if [ -z "$(echo $PKG)" ]; then
    echo "Автоматическая установка не поддерживается"
    exit 1
fi

# Установка необходимых пакетов
$PKG install jq

