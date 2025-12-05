#!/bin/bash
set -e

echo "🧪 Запуск E2E теста: SummaryGenerationE2ETests"
echo ""

# 1. Clean build
./scripts/build-e2e-tests.sh

# 2. Запуск теста (БЕЗ повторной сборки - используем уже собранные артефакты)
echo ""
echo "▶️  Запуск теста..."
swift test --skip-build --filter SummaryGenerationE2ETests --verbose 2>&1
