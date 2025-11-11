#!/bin/bash

# Скрипт для установки Git hooks
# Запускает SwiftLint перед каждым коммитом

set -e

HOOKS_DIR=".git/hooks"
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

echo "📦 Установка Git hooks..."

# Проверить, что мы в корне Git репозитория
if [ ! -d ".git" ]; then
    echo "❌ Ошибка: этот скрипт должен запускаться из корня Git репозитория"
    exit 1
fi

# Проверить, установлен ли SwiftLint
if ! command -v swiftlint &> /dev/null; then
    echo "⚠️  SwiftLint не установлен. Установите через:"
    echo "   macOS: brew install swiftlint"
    echo "   Linux: см. инструкции в .claude/DEPLOY.md"
    echo ""
    echo "❓ Продолжить установку hook без SwiftLint? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "❌ Установка отменена"
        exit 1
    fi
fi

# Создать директорию hooks если её нет
mkdir -p "$HOOKS_DIR"

# Создать pre-commit hook
cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash

# Pre-commit hook для проверки качества кода через SwiftLint
# Устанавливается через: ./scripts/install-git-hooks.sh

# Цвета для вывода
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Запуск SwiftLint..."

# Проверить, установлен ли SwiftLint
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint не установлен. Пропускаем проверку.${NC}"
    echo -e "${YELLOW}💡 Установите SwiftLint для автоматической проверки кода:${NC}"
    echo -e "${YELLOW}   macOS: brew install swiftlint${NC}"
    echo -e "${YELLOW}   Linux: см. .claude/DEPLOY.md${NC}"
    exit 0
fi

# Запустить SwiftLint только на staged файлах
git diff --cached --name-only --diff-filter=d | grep -E "\.swift$" | while read -r file; do
    swiftlint lint --path "$file" --quiet
done

LINT_EXIT_CODE=$?

if [ $LINT_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}❌ SwiftLint нашёл проблемы в коде!${NC}"
    echo -e "${YELLOW}💡 Исправьте ошибки или запустите 'swiftlint --fix' для автоматического исправления${NC}"
    echo -e "${YELLOW}⚠️  Чтобы пропустить проверку, используйте: git commit --no-verify${NC}"
    exit 1
fi

echo -e "${GREEN}✅ SwiftLint проверка пройдена${NC}"
exit 0
EOF

# Сделать hook исполняемым
chmod +x "$PRE_COMMIT_HOOK"

echo "✅ Git hooks установлены успешно!"
echo ""
echo "📝 Установлены hooks:"
echo "   - pre-commit: Проверка SwiftLint перед каждым коммитом"
echo ""
echo "💡 Чтобы пропустить проверку в конкретном коммите:"
echo "   git commit --no-verify"
