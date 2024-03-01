#!/bin/sh

# Скрипт для запуска команд на локальном хосте через бота Telegram
# Для работы требуется:
#   - создать бота - https://sitogon.ru/blog/252-kak-sozdat-telegram-bot-poluchit-ego-token-i-chat-id
#   - установить скрипт


# Telegram bot token and chat ID, как получить - https://sitogon.ru/blog/252-kak-sozdat-telegram-bot-poluchit-ego-token-i-chat-id
BOT_TOKEN=
BOT_CHAT_ID=

# MODE - режим работы скрипта с ботом. По-умолчанию - RESTRICTED.
#   - FULL - разрешены все команды. Все, что присылает бот - запускается на выполнение!!!
#   - RESTRICTED - разрешены команды из списка в файле cmd_list.txt.
#   - KVAS - разрешены только команды, начинающиеся на слово "kvas ...".
#            Если указанного слова в начале сообщения нет, то считается, что сообщение - название домена и нужно выполнить команду: kvas add <*домен>.
#            Имя домена может быть как в чистом виде (типа, youtube.com), так и ввиде ссылки (типа, https://www.youtube.com/watch?v=cqJNRlp34C68&t=12s) из которой имя домена (типа, youtube.com) будет выделено автоматически.
#            Так же перед доменом автоматически добавляется символ "*" (станет *youtube.com).
MODE=RESTRICTED

# Частота опроса бота. По-умолчанию - каждые 5 сек.
READ_FREQ=5



#------- Не редактировать! ---------------------------------------------------------------------------------------------------

# Проверка наличия BOT_TOKEN и BOT_CHAT_ID
if [ -z "$BOT_TOKEN" ] || [ -z "$BOT_CHAT_ID" ]; then
    echo
    echo "Отсутсвует BOT_TOKEN или BOT_CHAT_ID в переменных файла t_control.sh!"
    echo "Завршение работы скрипта."
    echo
    exit 1
fi

# Telegram API
SEND_MSG_URL=https://api.telegram.org/bot$BOT_TOKEN/sendMessage
GET_MSG_URL=https://api.telegram.org/bot$BOT_TOKEN/getUpdates

# Регулярное выражение для определения названия домена
DOMAIN_VALIDATE="([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,6})($|/)"

# Последнее прочитанное сообщение
MESSAGE_OFFSET=""

# Отключаем случайный запуск псевдографических программ (типа, Midnight Commander)
export TERM=dumb

# Отключаем лишнее взаимодейстивие с пользователем
export DEBIAN_FRONTEND=noninteractive

# Макросы
. ./cmd_macro.lib
CMD_MACRO=$(grep "^_" ./cmd_macro.lib | grep "()" | tr -d '()')

# Alias
. ./cmd_alias.lib


# Главный цикл скрипта - читаем сообщения от бота каждые <READ_FREQ> секунд.
while true
do
    # Читаем всю пачку непрочитанных сообщений и сохраняем в переменную в формате json
    MESSAGE_FROM_BOT=$(curl -s -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "allowed_updates": "message", "offset": "'"$MESSAGE_OFFSET"'"}' "$GET_MSG_URL" | jq -r '.result[]')
    
    # Если сообщения есть (переменная не пуста) ...
    if [ ! -z "$MESSAGE_FROM_BOT" ]; then
        
        # Список ID сообщений
        MESSAGE_ID_LIST=$(echo $MESSAGE_FROM_BOT | jq -r '.update_id')
        
        # Обрабатываем по одному сообщению из списка
        for MESSAGE_ID in $MESSAGE_ID_LIST
        do
        
            # Получаем текст сообщения.
            # В одном сообщении может быть несколько комманд, разделенных переносом строки или символом ";"
            # Поэтому приводим их к общему виду (cmd1;cmd2;cmd3;...) убирая лишние пробелы
            MESSAGE_TEXT=$(echo $MESSAGE_FROM_BOT | jq -r 'select(.update_id == '$MESSAGE_ID')' | jq -r '.message.text' | sed 'N;s/\n/;/' | sed -E 's/; +/;/g')
            
            # Обрабатываем каждую команду из текста сообщения
            IFS=$'\n'
            for COMMAND in $(echo $MESSAGE_TEXT | tr ';' '\n')
            do
                
                export MODE=$(grep -m 1 "^MODE=" ./t_control.sh | cut -d '=' -f 2 | grep -E "(FULL|RESTRICTED|KVAS)" || echo "RESTRICTED")
                
                # Выполняем макрос, если необходимо
                if [ ! -z "$(echo $CMD_MACRO | sed -E "s/^_| _/ \//g" | grep -P "$COMMAND( |$)")" ]; then
                    curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "text": "Выполняем ['"$COMMAND"'] ...", "disable_notification": true}' "$SEND_MSG_URL"
                    CMD_RESULT=$(eval $(echo "$COMMAND" | sed "s/^\//_/g") 2>&1 | head -c 4096 | \
                             sed -E -e 's/\[[0-9;]*m|\[[0-9]+D//g' | \
                             grep -v "sh: bad number" | \
                             sed -E "s/^-+/-----------------------------------------/g" | \
                             sed -E "s/\.\/t_control.sh: eval: line [0-9]+:/Command/g")
                    curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "text": "'"$CMD_RESULT"'", "disable_notification": true}' "$SEND_MSG_URL"
                    continue
                fi
                                
                # Если команда начинается на слово "kvas", то для простоты дальнейшей обработки переводим ее всю в нижний регистр
                if [ ! -z "$(echo $COMMAND | grep -E ^[Kk][Vv][Aa][Ss])" ]; then
                    export COMMAND="$(echo $COMMAND | tr '[:upper:]' '[:lower:]')"
                fi
                
                # Если в команде первая буква большая, а остальные маленькие (из-за автозамены на клавиатуре мобильных устройств) то конвертируем первую букву в нижний регистр
                if [ ! -z "$(echo $COMMAND | grep -E "^[A-Z][0-9a-z\-_]*")" ]; then
                    FIRST_CHAR=$(echo $COMMAND | grep -E -o "^[A-Z]" | tr '[:upper:]' '[:lower:]')
                    export COMMAND="$(echo $COMMAND | sed -E "s/^[A-Z]/$FIRST_CHAR/")"
                fi
                                
                # Если установлен режим RESTRICTED, но команды нет в списке cmd_list.txt, то прерываем выполнение и переходим к следующей команде
                if [ "$MODE" = "RESTRICTED" ] && [ -z "$(echo $COMMAND | grep "$(cat ./cmd_list.txt)")" ]; then
                    curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "text": "Команда ['"$COMMAND"'] запрещена в режиме RESTRICTED. При необходимости, добавьте эту команду в список разрешенных (cmd_list.txt).", "disable_notification": true}' "$SEND_MSG_URL"
                    continue
                fi
                
                # Если установлен режим KVAS ...
                if [ "$MODE" = "KVAS" ]; then
                    # Если режим KVAS, но команда НЕ начинается на "kvas ...", то считаем, что сообщение - это название домена
                    if [ -z "$(echo $COMMAND | grep -E ^kvas)" ]; then
                        DOMAIN_NAME="$(echo $COMMAND | grep -v " " | grep -E -o "$DOMAIN_VALIDATE" | tr -d '/' | sed '1p;d')"
                        # Если название домена не найдено, то прерываем выполнение и переходим к следующей команде
                        # Если найдено - создаем команду вида "kvas add <*домен>"
                        if [ -z "$DOMAIN_NAME" ]; then
                            CMD_RESULT=$(echo "Команда ['"$COMMAND"'] запрещена в режиме KVAS.")
                            curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "text": "'"$CMD_RESULT"'", "disable_notification": true}' "$SEND_MSG_URL"
                            continue
                        else
                            export COMMAND="kvas add *$DOMAIN_NAME"
                        fi
                    fi
                fi

                # Выполняем команду.
                # Обрезаем вывод результата команды до 4096 символов (ограничение ботов в Telegram), а так же убираем "красивости" kvas, т.к. они некорректно отображаются в Telegram
                curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "text": "Выполняем ['"$COMMAND"'] ...", "disable_notification": true}' "$SEND_MSG_URL"
                CMD_RESULT=$(eval "$COMMAND" 2>&1 | head -c 4096 | \
                             sed -E -e 's/\[[0-9;]*m|\[[0-9]+D//g' | \
                             grep -v "sh: bad number" | \
                             sed -E "s/^-+/-----------------------------------------/g" | \
                             sed -E "s/\.\/t_control.sh: eval: line [0-9]+:/Command/g")
                [ -z "$CMD_RESULT" ] && CMD_RESULT="Вывод команды [$COMMAND] отсутствует."
                curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "text": "'"$CMD_RESULT"'", "disable_notification": true}' "$SEND_MSG_URL"
            done
            unset IFS
            
        done
        
        # В завершении помечаем все сообщения бота как "прочитанные"
        MESSAGE_OFFSET=$((MESSAGE_ID + 1))
        curl -s -X POST -H 'Content-Type: application/json' -d '{"chat_id": "'"$BOT_CHAT_ID"'", "allowed_updates": "message", "offset": "'"$MESSAGE_OFFSET"'"}' "$GET_MSG_URL"
    fi

    # Пауза длительностью <READ_FREQ> секунд ...
    sleep $READ_FREQ
done
