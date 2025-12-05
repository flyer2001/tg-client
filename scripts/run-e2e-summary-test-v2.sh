#!/bin/bash
set -e

echo "🧪 Запуск E2E теста: SummaryGenerationE2ETests (вариант 2)"
echo ""

# Clean + test в одной команде (без промежуточного build)
pkill -9 swift-frontend swift-build swift-test sourcekit-lsp || true
swift package purge-cache
swift package reset

echo "▶️  Запуск теста напрямую (без предварительного build)..."
swift test --filter SummaryGenerationE2ETests --verbose 2>&1
