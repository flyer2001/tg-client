# Установка и настройка окружения

> Эта инструкция для локальной разработки на macOS и удалённой разработки через SSH. Для развертывания на Linux см. [DEPLOY.md](DEPLOY.md)

## Локальная разработка на macOS

### Установка зависимостей

```bash
brew install tdlib pkg-config
```

## Настройка переменных окружения

```bash
# ВАЖНО для macOS: указываем путь к pkg-config файлам TDLib
export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"
```

**Для постоянной настройки** добавьте в `~/.zshrc` или `~/.bash_profile`:
```bash
echo 'export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"' >> ~/.zshrc
source ~/.zshrc
```

### API Credentials

См. [CREDENTIALS.md](CREDENTIALS.md) для получения и настройки Telegram API credentials.

---

## Удалённая разработка с iPhone/iPad (Claude CLI + SSH)

Этот workflow позволяет разрабатывать проект на Linux VPS, управляя им с мобильного устройства через Claude Code CLI.

### Требования

- Linux VPS с установленным Swift и TDLib (см. [DEPLOY.md](DEPLOY.md))
- SSH-клиент на iOS: **Blink Shell** (рекомендуется) или **Termius**
- Node.js на VPS (для Claude CLI)

### Установка Claude CLI на Linux VPS

```bash
# Установка Node.js (если не установлен)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Установка Claude Code CLI
npm install -g @anthropic-ai/claude-code-cli

# Проверка установки
claude --version
```

### Авторизация Claude CLI

```bash
# Получить токен на https://claude.ai/settings
claude setup-token

# Ввести токен из веб-интерфейса
```

### Настройка SSH с iPhone/iPad

1. **Установить Blink Shell** из App Store
2. **Создать SSH-ключ** (если ещё нет):
   ```bash
   # На iPhone в Blink Shell
   ssh-keygen -t ed25519 -C "iphone"

   # Скопировать публичный ключ
   cat ~/.ssh/id_ed25519.pub
   ```

3. **Добавить ключ на VPS**:
   ```bash
   # На VPS
   echo "публичный_ключ" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

4. **Подключиться с iPhone**:
   ```bash
   ssh user@your-vps-ip
   cd ~/tg-client
   ```

### Настройка мобильной конфигурации Claude

Для удобной работы в мобильном терминале (Termius/Blink Shell) используйте оптимизированные настройки:

```bash
# На VPS создать alias для мобильной конфигурации
echo "alias claude-mobile='claude --config ~/tg-client/.claude/settings.mobile.json'" >> ~/.bashrc
source ~/.bashrc
```

**Мобильная конфигурация** (`.claude/settings.mobile.json`):
- `spinnerTipsEnabled: false` — отключает spinner tips (предотвращает "дёргание" экрана)
- `alwaysThinkingEnabled: false` — скрывает процесс размышлений (экономия места)

### Workflow разработки

```bash
# 1. Подключиться к VPS
ssh user@vps

# 2. Перейти в проект
cd ~/tg-client

# 3. Запустить Claude CLI (мобильная версия)
claude-mobile

# 4. Дать задачу Claude (примеры):
# - "проверь что swift build работает"
# - "добавь unit-тест для TDLibRequestEncoder"
# - "запусти тесты и покажи результат"
```

**Альтернативно** (без alias):
```bash
claude --config ~/tg-client/.claude/settings.mobile.json
```

### Troubleshooting: Зависший SwiftPM

При работе через SSH часто возникает проблема зависания `swift build` из-за некорректно завершённых процессов.

**Симптомы**:
- `swift build` висит на "Planning build"
- Сообщение: "Another instance of SwiftPM is already running..."

**Быстрое решение**:
```bash
# Удалить .build и пересобрать (20-30 секунд)
rm -rf .build && swift build 2>&1 | tail -20
```

**Подробности** см. в [DEPLOY.md](DEPLOY.md) → "Known Issue: SwiftPM Build Hangs"

### Рекомендации

1. **Используйте tmux** для длительных операций:
   ```bash
   # Создать сессию
   tmux new -s dev

   # Запустить длительную команду (тесты, сборка)
   swift test

   # Отключиться: Ctrl+B, затем D
   # Подключиться обратно: tmux attach -s dev
   ```

2. **Ограничивайте вывод** длинных команд:
   ```bash
   swift build 2>&1 | tail -20  # Показать только последние 20 строк
   swift test 2>&1 | head -50   # Показать только первые 50 строк
   ```

3. **Проверяйте зависшие процессы** перед сборкой:
   ```bash
   ps aux | grep swift-build
   ```

---

## Дополнительные команды

### Продакшен-сборка
```bash
swift build -c release
```

### Запуск конкретного теста
```bash
swift test --filter TelegramCoreTests
```

### Проверка Linux-совместимости через Docker
```bash
docker run --rm -v $(pwd):/code swift:6.0 bash -c "cd /code && swift build"
```

### Запуск с сохранением логов
```bash
swift run tg-client 2>app.log
```
