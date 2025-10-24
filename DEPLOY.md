# Инструкция по развертыванию на Linux-сервере

## Предварительные требования

### 1. Установка Swift на Linux

```bash
# Ubuntu/Debian
wget https://download.swift.org/swift-6.0.3-release/ubuntu2204/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-6.0.3-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0.3-RELEASE-ubuntu22.04 /usr/share/swift
echo 'export PATH=/usr/share/swift/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Проверка
swift --version
```

### 2. Установка TDLib

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y libtdjson-dev pkg-config

# Проверка
pkg-config --modversion tdjson
```

### 3. Установка зависимостей для сборки

```bash
sudo apt install -y build-essential libssl-dev libreadline-dev
```

## Клонирование репозитория

```bash
cd ~
git clone <your-repo-url> tg-client
cd tg-client
```

## Настройка переменных окружения

Создайте файл `.env` (он не будет закоммичен благодаря .gitignore):

```bash
cat > .env << 'EOF'
export TELEGRAM_API_ID=REDACTED_API_ID
export TELEGRAM_API_HASH=REDACTED_API_HASH
export TDLIB_STATE_DIR=$HOME/.tdlib
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:$PKG_CONFIG_PATH"
EOF

chmod 600 .env
```

Загрузите переменные:
```bash
source .env
```

## Сборка проекта

```bash
swift build -c release
```

Бинарник будет в `.build/release/tg-client`

## Первый запуск (авторизация)

```bash
source .env
swift run tg-client 2>/dev/null
```

Вам потребуется:
1. Ввести номер телефона
2. Ввести код из SMS/Telegram
3. Ввести пароль 2FA (если включен)

После успешной авторизации сессия сохранится в `~/.tdlib/`

## Запуск на продакшене

### Вариант 1: Прямой запуск

```bash
source .env
.build/release/tg-client 2>app.log
```

### Вариант 2: Через systemd (рекомендуется)

Создайте systemd service:

```bash
sudo tee /etc/systemd/system/tg-client.service > /dev/null << 'EOF'
[Unit]
Description=Telegram Client Service
After=network.target

[Service]
Type=simple
User=<your-username>
WorkingDirectory=/home/<your-username>/tg-client
Environment="TELEGRAM_API_ID=REDACTED_API_ID"
Environment="TELEGRAM_API_HASH=REDACTED_API_HASH"
Environment="TDLIB_STATE_DIR=/home/<your-username>/.tdlib"
Environment="PKG_CONFIG_PATH=/usr/lib/pkgconfig"
ExecStart=/home/<your-username>/tg-client/.build/release/tg-client
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

Замените `<your-username>` на ваше имя пользователя!

Запуск сервиса:

```bash
sudo systemctl daemon-reload
sudo systemctl enable tg-client
sudo systemctl start tg-client

# Проверка статуса
sudo systemctl status tg-client

# Логи
sudo journalctl -u tg-client -f
```

## Обновление на сервере

```bash
cd ~/tg-client
git pull
source .env
swift build -c release
sudo systemctl restart tg-client  # если используете systemd
```

## Отладка

### Проверка версии TDLib

```bash
pkg-config --modversion tdjson
```

### Проверка логов TDLib

```bash
tail -100 ~/.tdlib/tdlib.log
```

### Проверка логов приложения

```bash
tail -100 app.log
# или для systemd
sudo journalctl -u tg-client -n 100
```

### Очистка состояния (при проблемах)

```bash
rm -rf ~/.tdlib
# Потребуется повторная авторизация!
```

## Различия macOS vs Linux

| Аспект | macOS | Linux |
|--------|-------|-------|
| TDLib установка | `brew install tdlib` | `apt install libtdjson-dev` |
| pkg-config путь | `/opt/homebrew/opt/tdlib/lib/pkgconfig` | `/usr/lib/pkgconfig` |
| Swift установка | Xcode | Ручная установка tar.gz |
| Systemd | ❌ | ✅ |
| Homebrew | ✅ | ❌ |

## Безопасность

1. **НЕ коммитьте** `.env` файл в git!
2. **НЕ коммитьте** директорию `.tdlib/` - там хранится сессия
3. Установите права на .env: `chmod 600 .env`
4. На продакшене используйте secrets management (Vault, AWS Secrets Manager, etc.)

## Мониторинг

### Проверка работы через cron

```bash
# Добавить в crontab -e
*/5 * * * * systemctl is-active --quiet tg-client || systemctl restart tg-client
```

### Алерты при падении

```bash
# Отправка в Telegram при перезапуске
# Добавить в ExecStartPre в systemd:
ExecStartPre=/usr/bin/curl -s "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage?chat_id=<CHAT_ID>&text=TG-Client restarting"
```
