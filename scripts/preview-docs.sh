#!/bin/bash
# Скрипт для локального просмотра Swift-DocC документации
# Запускает web-сервер с live preview на localhost:8000
#
# Использование:
#   ./scripts/preview-docs.sh
#
# Требования:
#   - macOS (Swift-DocC лучше работает на macOS)
#   - Swift 6.0+
#
# После запуска откроется браузер:
#   http://localhost:8000/documentation/tgclient

set -e

echo "🔨 Запуск Swift-DocC preview сервера..."
echo ""
echo "📖 Документация будет доступна по адресу:"
echo "   http://localhost:8000/documentation/tgclient"
echo ""
echo "⚠️  Для остановки нажмите Ctrl+C"
echo ""

# Проверка что мы в корне проекта
if [ ! -f "Package.swift" ]; then
    echo "❌ Ошибка: Package.swift не найден"
    echo "   Запустите скрипт из корня проекта"
    exit 1
fi

# Проверка что структура .docc существует
if [ ! -d "Sources/TgClient/TgClient.docc" ]; then
    echo "⚠️  Предупреждение: Папка Sources/TgClient/TgClient.docc не найдена"
    echo "   Документация может быть пустой"
    echo ""
fi

# Запуск preview с автоматическим открытием браузера
swift package --disable-sandbox preview-documentation --target TgClient
