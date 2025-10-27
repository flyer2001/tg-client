# Установка и настройка окружения (macOS)

> Эта инструкция для локальной разработки на macOS. Для развертывания на Linux см. [DEPLOY.md](DEPLOY.md)

## Установка зависимостей

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

## API Credentials

См. [CREDENTIALS.md](CREDENTIALS.md) для получения и настройки Telegram API credentials.

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
