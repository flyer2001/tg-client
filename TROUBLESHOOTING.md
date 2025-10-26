# Решение частых проблем

## Ошибка: 'td/telegram/td_json_client.h' file not found

**Причина**: Swift Package Manager не может найти заголовочные файлы TDLib.

**Решение**:
1. Убедитесь, что TDLib установлен: `brew list tdlib` (macOS) или `ldconfig -p | grep tdjson` (Linux)
2. Установите pkg-config: `brew install pkg-config` (macOS)
3. Установите переменную окружения:
   ```bash
   # macOS
   export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"

   # Linux
   export PKG_CONFIG_PATH="/usr/lib/pkgconfig:$PKG_CONFIG_PATH"
   ```

## Ошибка: argument 'dependencies' must precede argument 'path'

**Причина**: Неправильный порядок параметров в Package.swift для `.testTarget()`.

**Решение**: В Package.swift параметр `dependencies` должен идти перед `path`:
```swift
.testTarget(
    name: "TelegramCoreTests",
    dependencies: ["TelegramCore"],  // dependencies первым
    path: "Tests/TelegramCoreTests"
)
```

## Предупреждения о Sendable в Swift 6

**Причина**: Swift 6 включает строгую проверку concurrency.

**Решение**:
- Структуры данных должны соответствовать `Sendable` протоколу
- Closures, передаваемые между потоками, должны быть помечены как `@Sendable`
- Классы с mutable state используют `@unchecked Sendable` с ручным управлением синхронизацией

## Проблемы на Linux-сервере

**См. [DEPLOY.md](DEPLOY.md)** для решения проблем специфичных для Linux:
- Out of Memory (OOM) при сборке TDLib
- Различия в установке TDLib (apt vs brew)
- Различия в pkg-config путях
- Настройка systemd для автозапуска
- Мониторинг и логирование на продакшене

## Проблемы с авторизацией

### Приложение зависает при запросе кода

**Причина**: TDLib ожидает ввода, но receive loop не обрабатывает обновления.

**Решение**: См. `Sources/TDLibAdapter/TDLibClient.swift:authorize()` - проверьте что receive loop корректно обрабатывает `updateAuthorizationState`.

### Сессия не сохраняется

**Причина**: Некорректный путь к `TDLIB_STATE_DIR` или отсутствие прав записи.

**Решение**:
```bash
# Проверить директорию
ls -la ~/.tdlib

# Пересоздать с правильными правами
rm -rf ~/.tdlib
mkdir -p ~/.tdlib
chmod 700 ~/.tdlib
```

### Очистка состояния при проблемах

```bash
rm -rf ~/.tdlib
# Потребуется повторная авторизация!
```

## Проблемы со сборкой

### Linux: libtdjson.so не найдена при запуске

**Причина**: Системный загрузчик не знает о библиотеке.

**Решение**:
```bash
sudo ldconfig
ldconfig -p | grep tdjson  # Проверка
```

### Docker: сборка падает с ошибкой

**Причина**: Возможно отличается версия Swift или отсутствуют зависимости.

**Решение**: Используйте официальный образ `swift:6.0` и установите TDLib:
```bash
docker run --rm -v $(pwd):/code swift:6.0 bash -c "
  apt-get update &&
  apt-get install -y libtdjson-dev pkg-config &&
  cd /code &&
  swift build
"
```
