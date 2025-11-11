# Установка и настройка окружения

> Эта инструкция для локальной разработки на macOS и удалённой разработки через SSH. Для развертывания на Linux см. [DEPLOY.md](DEPLOY.md)

## Локальная разработка на macOS

### Установка зависимостей

```bash
brew install tdlib pkg-config swiftlint
```

**SwiftLint** — линтер для проверки качества кода и соблюдения coding style проекта.

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

1. **Получить Telegram API credentials:**
   - Перейти на https://my.telegram.org/apps
   - Создать приложение
   - Скопировать API ID и API Hash

2. **Создать .env файл:**
   ```bash
   cp .env.example .env
   ```

3. **Заполнить .env файл** (без ключевого слова `export`):
   ```bash
   TELEGRAM_API_ID=your_api_id_here
   TELEGRAM_API_HASH=your_api_hash_here
   TELEGRAM_PHONE=+1234567890
   TDLIB_STATE_DIR=$HOME/.tdlib
   ```

   ⚠️ **Важно:** НЕ используйте `export` в .env файле - только формат `KEY=value`

См. также [CREDENTIALS.md](CREDENTIALS.md) для деталей.

### Запуск приложения

**Для загрузки переменных из .env файла используйте:**

```bash
# Вариант 1: set -a экспортирует все переменные при source
set -a && source .env && set +a && swift run tg-client

# Вариант 2: более короткая команда (работает в bash/zsh)
(set -a; source .env; swift run tg-client)
```

**Объяснение:**
- `set -a` — включает автоэкспорт всех переменных при присваивании
- `source .env` — загружает переменные из файла
- `set +a` — отключает автоэкспорт (опционально)

**Альтернатива:** можно добавить `export` перед каждой переменной в `.env`, тогда достаточно `source .env && swift run tg-client`

### Проверка качества кода (SwiftLint)

Проект использует SwiftLint для автоматической проверки coding style и best practices.

**Запуск линтера:**
```bash
# Через Swift Package Manager (рекомендуется)
swift package plugin --allow-writing-to-package-directory swiftlint

# Или через локально установленный SwiftLint (быстрее)
swiftlint lint
```

**Автоматическое исправление проблем:**
```bash
swiftlint --fix
```

**Установка Git pre-commit hook (рекомендуется):**

Чтобы автоматически проверять код перед каждым коммитом:

```bash
./scripts/install-git-hooks.sh
```

После установки SwiftLint будет запускаться перед каждым `git commit`. Чтобы пропустить проверку:

```bash
git commit --no-verify
```

**Важные правила проекта:**
- ❌ Запрещён `import XCTest` — используй `import Testing` (Swift Testing framework)
- ❌ Запрещён `JSONEncoder()` / `JSONDecoder()` напрямую — используй `.tdlib()` методы
- ⚠️ Force unwrap (`!`) требует обоснования — предпочитай `guard`, `if let`, или `#require` в тестах

Конфигурация линтера находится в `.swiftlint.yml` в корне проекта.

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
# На VPS создать скрипт для мобильной конфигурации
sudo tee /usr/local/bin/claude-mobile > /dev/null << 'EOF'
#!/bin/bash
cd ~/tg-client && exec claude --settings .claude/settings.mobile.json "$@"
EOF

sudo chmod +x /usr/local/bin/claude-mobile
```

**Мобильная конфигурация** (`.claude/settings.mobile.json`):
- `spinnerTipsEnabled: false` — отключает spinner tips (предотвращает "дёргание" экрана)
- `alwaysThinkingEnabled: false` — скрывает процесс размышлений (экономия места)
- `permissions.deny` — блокирует чтение `.env`, `.git`, `.build` для безопасности

### Workflow разработки

```bash
# 1. Подключиться к VPS
ssh user@vps

# 2. Запустить Claude CLI (мобильная версия)
claude-mobile

# Можно сразу продолжить последнюю сессию:
claude-mobile -c

# 3. Дать задачу Claude (примеры):
# - "проверь что swift build работает"
# - "добавь unit-тест для TDLibRequestEncoder"
# - "запусти тесты и покажи результат"
```

**Альтернативно** (без скрипта):
```bash
cd ~/tg-client
claude --settings .claude/settings.mobile.json
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
