# Инструкция по развертыванию на Linux-сервере

> ⚠️ **ВНИМАНИЕ:** Документ обновляется для Ubuntu 24.04 и Swift 6.2. Инструкции ниже могут быть неактуальны и будут обновлены после тестирования на реальном сервере.

## SSH доступ к продакшен-серверу

Продакшен-сервер настроен в `~/.ssh/config` для автоматического подключения:

```bash
# Подключение к серверу (используется алиас из SSH config)
ssh ufohosting

# Или напрямую
ssh root@45.8.145.191
```

**Настройка SSH-ключа (уже выполнено):**
- SSH-ключ: `~/.ssh/ufohosting`
- Автозагрузка ключа настроена через `UseKeychain yes` в `~/.ssh/config`
- После перезагрузки macOS ключ загружается автоматически при первом использовании

**Проверка автозагрузки после перезагрузки:**
```bash
# Проверить загруженные ключи
ssh-add -l

# Если ключ не загружен, добавить вручную (современный синтаксис)
ssh-add --apple-use-keychain ~/.ssh/ufohosting
```

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

> 💡 **ВАЖНО:** Для Ubuntu 24.04 готовых пакетов TDLib нет, поэтому нужна сборка из исходников. Процесс занимает 20-40 минут на 1 CPU core.

> ⚠️ **РЕКОМЕНДАЦИЯ:** Используйте `tmux` для запуска длительной сборки, чтобы процесс не прервался при обрыве SSH-соединения!

```bash
# Установка зависимостей для сборки TDLib
sudo apt update
sudo apt install -y build-essential cmake gperf libssl-dev zlib1g-dev pkg-config tmux git

# Клонирование репозитория TDLib
cd ~
git clone https://github.com/tdlib/td.git
cd td

# ВАЖНО: Запускаем сборку в tmux-сессии
tmux new-session -d -s tdlib-build "cd ~/td && mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. && cmake --build . -j\$(nproc) 2>&1 | tee build.log; echo 'Build finished with exit code:' \$?"

# Подключиться к сессии и посмотреть прогресс:
tmux attach -t tdlib-build

# Отключиться от tmux (НЕ останавливая сборку): Ctrl+B, затем D

# Проверить статус сборки (после отключения):
tail -f ~/td/build/build.log

# После завершения сборки: установка
cd ~/td/build
sudo cmake --install .

# Обновить кэш динамических библиотек (чтобы система нашла libtdjson.so)
sudo ldconfig

# Проверка установки
ldconfig -p | grep tdjson  # Должен показать путь к библиотеке
pkg-config --modversion tdjson
```

**Для Ubuntu 22.04 и ниже** (если доступен готовый пакет):
```bash
sudo apt update
sudo apt install -y libtdjson-dev pkg-config
pkg-config --modversion tdjson
```

#### Проблема: Out of Memory (OOM) при сборке

TDLib требует много RAM при компиляции (~700-800MB на один процесс компилятора). На серверах с малым объёмом памяти (1GB) компиляция может прерваться с ошибкой OOM.

**Решение: Увеличить swap**

```bash
# Проверить текущий swap
swapon --show

# Если OOM Killer убивает процессы компиляции:
dmesg | grep -i "killed process"

# Создать дополнительный swap (2GB)
sudo dd if=/dev/zero of=/swapfile2 bs=1M count=2048
sudo chmod 600 /swapfile2
sudo mkswap /swapfile2
sudo swapon /swapfile2

# Проверка
swapon --show
# Должно показать 2 файла swap

# Сделать постоянным (добавить в fstab)
echo '/swapfile2 none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Снизить параллелизм сборки:**

```bash
# Вместо -j$(nproc) использовать -j1 (медленнее, но меньше памяти)
cmake --build . -j1
```

#### План Б: Сборка в Docker (если на сервере не получается)

Если даже со swap сборка не идёт, можно собрать TDLib локально и передать на сервер.

**⚠️ Версия Ubuntu в Docker ДОЛЖНА совпадать с сервером (Ubuntu 24.04)!**

```bash
# На локальной машине (macOS/Linux):

# 1. Собрать TDLib в Docker контейнере Ubuntu 24.04
docker run --rm -v $(pwd)/tdlib-build:/output ubuntu:24.04 bash -c "
  apt-get update &&
  apt-get install -y build-essential cmake gperf libssl-dev zlib1g-dev git &&
  git clone https://github.com/tdlib/td.git /tmp/td &&
  cd /tmp/td && mkdir build && cd build &&
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/output .. &&
  cmake --build . -j\$(nproc) &&
  cmake --install .
"

# 2. Упаковать для передачи
tar czf tdlib-ubuntu24.tar.gz -C tdlib-build .

# 3. Передать на сервер
scp tdlib-ubuntu24.tar.gz ufohosting:~/

# 4. На сервере установить
ssh ufohosting 'sudo tar xzf ~/tdlib-ubuntu24.tar.gz -C /usr/local && rm ~/tdlib-ubuntu24.tar.gz'

# 5. Проверка
ssh ufohosting 'pkg-config --modversion tdjson'
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

> 📖 **Как получить Telegram API credentials:** См. подробные инструкции в [CREDENTIALS.md](CREDENTIALS.md)

```bash
cat > .env << 'EOF'
export TELEGRAM_API_ID=<your_api_id>
export TELEGRAM_API_HASH=<your_api_hash>
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

### ⚠️ Known Issue: SwiftPM Build Hangs on Linux

**Проблема**: На Linux-серверах (проверено на Ubuntu 24.04) команда `swift build` может зависать на этапе "Planning build" даже для инкрементальных сборок без изменений кода. Нагрузка на CPU при этом минимальная (~0%).

**Симптомы**:
- `swift build` висит на "Planning build" без прогресса
- Происходит как для первой сборки, так и для повторных
- Даже если бинарник уже собран и существует в `.build/debug/`

**Рабочий workaround** (если нужна пересборка):
```bash
# Запустить сборку в tmux с verbose режимом
tmux new-session -s build
swift build -v

# Отключиться от tmux: Ctrl+B, затем D
# Подключиться обратно: tmux attach -t build
```

**Время сборки** (когда работает): ~15-20 секунд для полной сборки

**Рекомендация для E2E тестирования**:
- Используйте уже собранный бинарник `.build/debug/tg-client` или `.build/release/tg-client`
- Избегайте лишних пересборок — если бинарник существует и код не менялся, используйте его напрямую

**Сборка в release режиме**:
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
