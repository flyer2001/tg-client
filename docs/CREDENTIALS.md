# Настройка переменных окружения

## Получение Telegram API Credentials

1. Перейдите на https://my.telegram.org/apps
2. Авторизуйтесь с помощью вашего номера телефона
3. Создайте новое приложение (если еще не создано)
4. Скопируйте `api_id` и `api_hash`

## Настройка переменных окружения

### Разовая настройка (текущая сессия)

```bash
export TELEGRAM_API_ID=<your_api_id>
export TELEGRAM_API_HASH=<your_api_hash>
export TDLIB_STATE_DIR=~/.tdlib  # Опционально, по умолчанию ~/.tdlib
```

### Постоянная настройка

**macOS (zsh):**
```bash
echo 'export TELEGRAM_API_ID=<your_api_id>' >> ~/.zshrc
echo 'export TELEGRAM_API_HASH=<your_api_hash>' >> ~/.zshrc
source ~/.zshrc
```

**Linux (bash):**
```bash
echo 'export TELEGRAM_API_ID=<your_api_id>' >> ~/.bashrc
echo 'export TELEGRAM_API_HASH=<your_api_hash>' >> ~/.bashrc
source ~/.bashrc
```

### Через .env файл (рекомендуется для продакшена)

Создайте файл `.env` в корне проекта:

```bash
cat > .env << 'EOF'
export TELEGRAM_API_ID=<your_api_id>
export TELEGRAM_API_HASH=<your_api_hash>
export TDLIB_STATE_DIR=$HOME/.tdlib
EOF

chmod 600 .env
```

Загрузка перед запуском:
```bash
source .env
swift run tg-client
```

## Безопасность

⚠️ **ВАЖНО:**
- **НЕ коммитьте** `.env` файл в git (уже добавлен в `.gitignore`)
- **НЕ коммитьте** директорию `.tdlib/` - там хранится сессия авторизации
- Установите права на `.env`: `chmod 600 .env`
- На продакшене используйте secrets management (Vault, AWS Secrets Manager и т.д.)
- Для systemd используйте директиву `Environment=` в `.service` файле (см. [DEPLOY.md](DEPLOY.md))
