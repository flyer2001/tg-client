#!/usr/bin/env bash
set -euo pipefail

# Скрипт для ЧИСТОЙ сборки проекта на Linux
#
# КОГДА ИСПОЛЬЗОВАТЬ:
# - SwiftPM зависает несмотря на pkill (редко)
# - Странные ошибки компиляции после git pull
# - После изменения Package.swift
# - Перед важным коммитом (проверка чистой сборки)
#
# ЧТО ДЕЛАЕТ:
# - Убивает все Swift процессы
# - УДАЛЯЕТ .build (пересборка всех зависимостей)
# - Резолвит зависимости заново
# - Собирает проект с нуля (~40-50 сек)
#
# ВНИМАНИЕ:
# На ubuntu-home (Swift 6.4) инкрементальная `swift build` работает — этот скрипт только для зависаний SwiftPM

echo "🧹 Убиваем зависшие процессы Swift..."
pkill -9 swift 2>/dev/null || true
sleep 1

echo "🗑️  Очищаем глобальный кеш SwiftPM (решает зависания)..."
swift package purge-cache

echo "🗑️  Сбрасываем локальный .build..."
swift package reset

echo "📦 Резолвим зависимости..."
swift package resolve

echo "🔨 Собираем проект..."
swift build

echo "✅ Сборка завершена!"
