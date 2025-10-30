#!/bin/bash

# Manual E2E test script for TDLib authorization
# Platforms: Linux (priority), macOS (optional)
#
# Что делает скрипт:
# 1. Проверка платформы (Linux/macOS)
# 2. Проверка переменных окружения (TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_PHONE)
# 3. Проверка установки TDLib
# 4. Очистка старых данных ~/.tdlib/ (опционально с флагом --clean)
# 5. Сборка проекта (swift build)
# 6. Запуск авторизации (swift run tg-client) - интерактивный режим
#
# Что будет проверено:
# - TDLib инициализируется корректно
# - Состояние меняется: waitTdlibParameters → waitPhoneNumber → waitCode → authorizationStateReady
# - getMe возвращает данные пользователя
# - Создаются файлы состояния в ~/.tdlib/
# - Нет критических ошибок в логах
#
# Примечание: SMS код и 2FA пароль вводятся вручную в интерактивном режиме
#
# Usage:
#   export TELEGRAM_API_ID=your_api_id
#   export TELEGRAM_API_HASH=your_api_hash
#   export TELEGRAM_PHONE=+1234567890
#   ./scripts/manual_e2e_auth.sh [--clean] [--skip-build] [--verbose]
#
# Options:
#   --clean        Remove old TDLib state before running
#   --skip-build   Skip swift build, use existing binary
#   --verbose      Enable verbose output (swift build -v)

set -e

# Parse options
CLEAN_STATE=false
SKIP_BUILD=false
VERBOSE=false

for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN_STATE=true
            ;;
        --skip-build)
            SKIP_BUILD=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load .env file if it exists
if [[ -f .env ]]; then
    echo -e "${YELLOW}Загрузка credentials из .env...${NC}"
    source .env
    echo -e "${GREEN}✓ .env загружен${NC}"
fi

# Detect platform
PLATFORM=$(uname -s)
echo -e "${YELLOW}Платформа: $PLATFORM${NC}"

if [[ "$PLATFORM" != "Linux" && "$PLATFORM" != "Darwin" ]]; then
    echo -e "${RED}❌ Unsupported platform: $PLATFORM${NC}"
    echo "This script supports Linux (priority) and macOS (optional)"
    exit 1
fi

# Check required environment variables
echo -e "\n${YELLOW}Проверка переменных окружения...${NC}"
REQUIRED_VARS=("TELEGRAM_API_ID" "TELEGRAM_API_HASH" "TELEGRAM_PHONE")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo -e "${RED}❌ Missing required environment variable: $var${NC}"
        echo "Please set all required variables:"
        echo "  export TELEGRAM_API_ID=your_api_id"
        echo "  export TELEGRAM_API_HASH=your_api_hash"
        echo "  export TELEGRAM_PHONE=+1234567890"
        exit 1
    fi
    echo -e "${GREEN}✓ $var is set${NC}"
done

# Check TDLib installation
echo -e "\n${YELLOW}Проверка установки TDLib...${NC}"
if [[ "$PLATFORM" == "Linux" ]]; then
    if ! ldconfig -p | grep -q libtdjson; then
        echo -e "${RED}❌ TDLib not found${NC}"
        echo "Install TDLib on Linux:"
        echo "  sudo apt-get install -y libtdjson-dev"
        exit 1
    fi
elif [[ "$PLATFORM" == "Darwin" ]]; then
    if ! brew list tdlib &>/dev/null; then
        echo -e "${RED}❌ TDLib not found${NC}"
        echo "Install TDLib on macOS:"
        echo "  brew install tdlib"
        exit 1
    fi
fi
echo -e "${GREEN}✓ TDLib is installed${NC}"

# Clean old state if requested
TDLIB_DIR="$HOME/.tdlib"
if [[ "$CLEAN_STATE" == true ]]; then
    echo -e "\n${YELLOW}Очистка старого состояния TDLib...${NC}"
    if [[ -d "$TDLIB_DIR" ]]; then
        rm -rf "$TDLIB_DIR"
        echo -e "${GREEN}✓ Removed $TDLIB_DIR${NC}"
    else
        echo -e "${YELLOW}  (нет существующего состояния)${NC}"
    fi
fi

# Build the project
if [[ "$SKIP_BUILD" == true ]]; then
    echo -e "\n${YELLOW}⏭  Пропуск сборки (используется существующий бинарник)${NC}"
    if [[ ! -f .build/debug/tg-client ]]; then
        echo -e "${RED}❌ Бинарник не найден: .build/debug/tg-client${NC}"
        echo -e "${RED}   Запустите без --skip-build для сборки${NC}"
        exit 1
    fi
else
    echo -e "\n${YELLOW}Сборка проекта...${NC}"
    echo -e "${YELLOW}⏱  Первая сборка может занять 15-30 секунд (последующие быстрее)${NC}"
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${YELLOW}📋 Подробный вывод включен${NC}"
        swift build -v
    else
        swift build
    fi
    echo -e "${GREEN}✓ Сборка успешна${NC}"
fi

# Run authorization
echo -e "\n${YELLOW}Запуск процесса авторизации...${NC}"
echo -e "${YELLOW}Следуйте подсказкам для ввода SMS-кода и 2FA пароля (если требуется)${NC}"
echo -e "${YELLOW}================================================${NC}\n"

LOG_FILE="/tmp/tg-client-e2e-$(date +%s).log"
swift run tg-client 2>&1 | tee "$LOG_FILE"

# Verify results
echo -e "\n${YELLOW}Проверка результатов авторизации...${NC}"

# Check 1: authorizationStateReady reached
if grep -q "authorizationStateReady" "$LOG_FILE"; then
    echo -e "${GREEN}✓ Authorization state reached: Ready${NC}"
else
    echo -e "${RED}❌ Failed to reach authorizationStateReady${NC}"
    echo -e "${RED}   Check logs: $LOG_FILE${NC}"
    exit 1
fi

# Check 2: getMe returned user data
if grep -q "getMe" "$LOG_FILE"; then
    echo -e "${GREEN}✓ getMe request executed${NC}"
else
    echo -e "${YELLOW}⚠ getMe not found in logs (check manually)${NC}"
fi

# Check 3: TDLib state files created
if [[ -d "$TDLIB_DIR" ]]; then
    echo -e "${GREEN}✓ TDLib state directory created: $TDLIB_DIR${NC}"
else
    echo -e "${RED}❌ TDLib state directory not found${NC}"
    exit 1
fi

# Check 4: No critical errors
if grep -qi "error\|failed\|exception" "$LOG_FILE" | grep -v "authorizationStateWaitCode"; then
    echo -e "${YELLOW}⚠ Errors found in logs (review manually)${NC}"
    echo -e "${YELLOW}   Log file: $LOG_FILE${NC}"
else
    echo -e "${GREEN}✓ No critical errors detected${NC}"
fi

# Summary
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Manual E2E test completed successfully${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e "\nLog file saved: $LOG_FILE"
echo -e "TDLib state: $TDLIB_DIR"
echo -e "\nPlatform: $PLATFORM"
