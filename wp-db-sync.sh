#!/bin/bash

# Скрипт для синхронизации базы данных WordPress с продакшен-сервера на локальную среду
# Используется WP-CLI для экспорта/импорта и замены URL

# ======= НАСТРОЙКИ =======

# Продакшен-сервер
PROD_SSH_USER="username"
PROD_SSH_HOST="example.com"
PROD_SSH_PORT="22"
PROD_WP_PATH="/path/to/wordpress"  # Путь к WordPress на продакшен-сервере
PROD_URL="https://example.com"     # URL продакшен-сайта

# Локальная среда
LOCAL_WP_PATH="/path/to/local/wordpress"  # Путь к локальной установке WordPress
LOCAL_URL="http://localhost/wordpress"     # URL локального сайта

# Временные файлы
DUMP_FILE="wp_database_dump.sql"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="local_db_backup_${TIMESTAMP}.sql"

# ======= ФУНКЦИИ =======

# Функция для вывода сообщений с форматированием
log_message() {
    echo -e "\n\033[1;34m===> $1\033[0m"
}

# Функция для обработки ошибок
handle_error() {
    echo -e "\n\033[1;31mОШИБКА: $1\033[0m"
    exit 1
}

# ======= НАЧАЛО СКРИПТА =======

log_message "Начинаем синхронизацию базы данных WordPress"

# Проверяем наличие WP-CLI
if ! command -v wp &> /dev/null; then
    handle_error "WP-CLI не установлен. Установите WP-CLI для продолжения: https://wp-cli.org/"
fi

# Создаем резервную копию локальной базы данных
log_message "Создание резервной копии локальной базы данных"
cd "$LOCAL_WP_PATH" || handle_error "Не удалось перейти в локальную директорию WordPress: $LOCAL_WP_PATH"
wp db export "$BACKUP_FILE" --allow-root || handle_error "Не удалось создать резервную копию локальной базы данных"
log_message "Резервная копия локальной базы данных создана: $BACKUP_FILE"

# Экспортируем базу данных с продакшен-сервера
log_message "Экспортируем базу данных с продакшен-сервера"
ssh -p "$PROD_SSH_PORT" "$PROD_SSH_USER@$PROD_SSH_HOST" "cd $PROD_WP_PATH && wp db export - --allow-root" > "$DUMP_FILE" || handle_error "Не удалось экспортировать базу данных с продакшен-сервера"
log_message "База данных с продакшен-сервера успешно экспортирована в $DUMP_FILE"

# Импортируем дамп в локальную базу данных
log_message "Импортируем базу данных в локальную среду"
wp db import "$DUMP_FILE" --allow-root || handle_error "Не удалось импортировать базу данных в локальную среду"
log_message "База данных успешно импортирована в локальную среду"

# Заменяем URL продакшен-сайта на URL локального сайта
log_message "Заменяем URL продакшен-сайта на URL локального сайта"
wp search-replace "$PROD_URL" "$LOCAL_URL" --all-tables --allow-root || handle_error "Не удалось заменить URL"

# Также заменяем URL без https:// и http://
PROD_DOMAIN=$(echo "$PROD_URL" | sed -E 's/https?:\/\///')
LOCAL_DOMAIN=$(echo "$LOCAL_URL" | sed -E 's/https?:\/\///')
log_message "Заменяем домен $PROD_DOMAIN на $LOCAL_DOMAIN"
wp search-replace "$PROD_DOMAIN" "$LOCAL_DOMAIN" --all-tables --allow-root || handle_error "Не удалось заменить домен"

# Очищаем кэш
log_message "Очищаем кэш WordPress"
wp cache flush --allow-root || echo "Предупреждение: Не удалось очистить кэш WordPress"

# Обновляем опции permalink_structure для правильной работы ЧПУ
log_message "Обновляем структуру постоянных ссылок"
PERMALINK_STRUCTURE=$(wp option get permalink_structure --allow-root)
wp rewrite flush --allow-root || echo "Предупреждение: Не удалось обновить правила перезаписи"

# Удаляем временный файл дампа
log_message "Удаляем временный файл дампа"
rm "$DUMP_FILE" || echo "Предупреждение: Не удалось удалить временный файл дампа"

log_message "Синхронизация базы данных WordPress успешно завершена!"
log_message "Локальный сайт доступен по адресу: $LOCAL_URL"
log_message "Резервная копия локальной БД перед синхронизацией: $BACKUP_FILE"

exit 0
