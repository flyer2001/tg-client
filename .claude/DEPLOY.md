# Развёртывание и настройка

## Переменные окружения

**Telegram API credentials:** https://my.telegram.org/apps → создать приложение → скопировать `api_id` и `api_hash`

**Формат:** см. `.env.example` в корне проекта. Копировать и заполнить:
```bash
cp .env.example .env
chmod 600 .env
```

**Загрузка переменных:**
```bash
# Рекомендуемый способ
set -a && source .env && set +a && swift run tg-client

# Для запуска бинарника напрямую
export $(cat .env | xargs) && .build/debug/tg-client
```

**Безопасность:** `.env` и `.tdlib/` в `.gitignore` — НЕ коммитить.

---

## macOS (локальная разработка)

```bash
# Установка зависимостей
brew install tdlib pkg-config

# PKG_CONFIG_PATH (добавить в ~/.zshrc)
export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"

# Сборка и запуск
swift build
swift test --filter MyTest --verbose 2>&1
```

---

## Linux сервер

### Установка Swift

```bash
# Ubuntu 22.04/24.04
wget https://download.swift.org/swift-6.0.3-release/ubuntu2204/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-6.0.3-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0.3-RELEASE-ubuntu22.04 /usr/share/swift
echo 'export PATH=/usr/share/swift/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### Сборка TDLib

> Ubuntu 24.04: готовых пакетов нет, сборка из исходников (~20-40 мин)

```bash
# Зависимости
sudo apt install -y build-essential cmake gperf libssl-dev zlib1g-dev pkg-config tmux git

# Клонирование и сборка (в tmux!)
tmux new-session -s tdlib
cd ~ && git clone https://github.com/tdlib/td.git && cd td
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
cmake --build . -j$(nproc)
sudo cmake --install .
sudo ldconfig
```

**OOM при сборке (1GB RAM):** добавить swap 2GB:
```bash
sudo dd if=/dev/zero of=/swapfile2 bs=1M count=2048
sudo chmod 600 /swapfile2 && sudo mkswap /swapfile2 && sudo swapon /swapfile2
```

### SwiftPM на Linux

> SwiftPM 6.2 зависает при инкрементальных сборках. Workaround: полная пересборка.

```bash
# Единственный рабочий вариант (~50-60 сек)
./scripts/build-clean.sh
```

### Systemd (production)

```bash
sudo tee /etc/systemd/system/tg-client.service > /dev/null << 'SERVICE'
[Unit]
Description=Telegram Client Service
After=network.target

[Service]
Type=simple
User=<username>
WorkingDirectory=/home/<username>/tg-client
EnvironmentFile=/home/<username>/tg-client/.env
ExecStart=/home/<username>/tg-client/.build/release/tg-client
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now tg-client
```

---

## Удалённая разработка (iPhone + SSH)

Workflow: iPhone (Blink Shell) → SSH → Linux VPS с Claude CLI.

```bash
# На VPS: установка Claude CLI
npm install -g @anthropic-ai/claude-code
claude auth login

# Подключение с iPhone
ssh user@vps
cd ~/tg-client && claude
```

**Мобильная конфигурация:** `.claude/settings.mobile.json` — отключает spinner tips.

**tmux для длительных операций:**
```bash
tmux new -s dev    # создать сессию
# Ctrl+B, D         # отключиться
tmux attach -s dev  # подключиться
```

---

## GitHub Actions CI

**Workflow:** `.github/workflows/linux-build.yml` (Ubuntu 24.04, Swift 6.2)

**Кэширование:**
- Swift toolchain: `swift-6.2-ubuntu24.04`
- TDLib build: `tdlib-1.8.29-ubuntu24.04-release` (первая сборка ~30 мин, далее ~2-3 мин)

**Пропуск CI:** изменения только в `.claude/**` или `*.md` не запускают сборку.

**Обновление TDLib:**
1. Изменить версию в workflow: `git clone --branch v1.8.30 ...`
2. Обновить ключ кэша: `tdlib-1.8.30-ubuntu24.04-release`

**Локальная проверка:**
```bash
rm -rf .build && swift build 2>&1 | tail -20
swift test --verbose 2>&1
```

---

## SSH доступ к серверу

```bash
# Алиас в ~/.ssh/config
ssh ufohosting

# Или напрямую
ssh root@45.8.145.191
```

SSH-ключ: `~/.ssh/ufohosting` (настроен UseKeychain для автозагрузки на macOS)
