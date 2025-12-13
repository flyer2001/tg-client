#!/bin/bash
# Генерация DoCC документации из тестовых файлов
#
# Скрипт парсит Swift Test файлы (*Tests.swift) и генерирует DoCC markdown articles:
# - @Suite doc comments → Overview секция
# - @Suite name → Title
# - @Test doc comments → Test Scenarios
# - @Test names → Scenario titles
#
# Использование:
#   ./scripts/generate-docc-from-tests.sh
#
# Требования:
#   - Swift Testing framework (@Suite, @Test syntax)
#   - Doc comments в формате Swift (///)
#
# Результат:
#   - Генерирует .md файлы в Sources/TgClient/TgClient.docc/Tests/
#   - Структура: Unit-Tests/, Component-Tests/

set -e

# Проверка что мы в корне проекта
if [ ! -f "Package.swift" ]; then
    echo "ERROR: Package.swift не найден. Запустите скрипт из корня проекта." >&2
    exit 1
fi

# Создание директорий для документации
DOCC_BASE="Sources/TgClient/TgClient.docc"
UNIT_TESTS_DIR="$DOCC_BASE/Tests/Unit-Tests"
COMPONENT_TESTS_DIR="$DOCC_BASE/Tests/Component-Tests"
E2E_TESTS_DIR="$DOCC_BASE/Tests/E2E-Tests"

mkdir -p "$UNIT_TESTS_DIR"
mkdir -p "$COMPONENT_TESTS_DIR"
mkdir -p "$E2E_TESTS_DIR"

# Функция для извлечения doc comment (многострочные /// комментарии)
extract_doc_comment() {
    local file="$1"
    local line_number="$2"
    local doc_lines=""

    # Читаем строки ПЕРЕД указанной (line_number - 1, line_number - 2, ...)
    local current_line=$((line_number - 1))

    while [ $current_line -gt 0 ]; do
        local line=$(sed -n "${current_line}p" "$file")

        # Если строка начинается с ///, добавляем её (без ///)
        if [[ "$line" =~ ^[[:space:]]*/// ]]; then
            local content=$(echo "$line" | sed 's/^[[:space:]]*\/\/\/[[:space:]]*//')
            # Добавляем в начало (так как читаем снизу вверх)
            doc_lines="${content}"$'\n'"${doc_lines}"
        else
            # Если строка НЕ doc comment, останавливаемся
            break
        fi

        current_line=$((current_line - 1))
    done

    echo "$doc_lines"
}

# Функция для извлечения комментариев из тела функции теста
extract_test_body_comments() {
    local file="$1"
    local test_line="$2"
    local comments=""

    # Найти строку с func (следующая после @Test)
    local func_line=$((test_line + 1))

    # Читать строки до следующего @Test или MARK
    local current_line=$((func_line + 1))
    local max_lines=$(wc -l < "$file")

    while [ $current_line -le $max_lines ]; do
        local line=$(sed -n "${current_line}p" "$file")

        # Остановиться если встретили @Test или MARK
        if [[ "$line" =~ @Test ]] || [[ "$line" =~ "// MARK:" ]]; then
            break
        fi

        # Извлечь комментарии (// но не ///)
        if [[ "$line" =~ ^[[:space:]]*//[^/] ]]; then
            local comment=$(echo "$line" | sed 's/^[[:space:]]*\/\/[[:space:]]*//')
            comments="${comments}${comment}"$'\n\n'
        fi

        current_line=$((current_line + 1))
    done

    echo "$comments"
}

# Функция для извлечения используемых Request/Response моделей и хелперов из кода теста
extract_model_references() {
    local file="$1"
    local models=""

    # Ищем типы *Request (например, SetAuthenticationPhoneNumberRequest)
    local requests=$(grep -o '\b[A-Z][a-zA-Z]*Request\b' "$file" | sort | uniq)

    # Ищем типы *Response (например, AuthorizationStateUpdateResponse, TDLibErrorResponse)
    local responses=$(grep -o '\b[A-Z][a-zA-Z]*Response\b' "$file" | sort | uniq)

    # Ищем хелперы тестирования (конкретные имена классов)
    local helpers=$(grep -oE '\b(MockTDLibFFI|ResponseWaiters|TDLibClient|Update)\b' "$file" | sort | uniq)

    # Объединяем все типы и добавляем суффикс Tests
    for model in $requests $responses $helpers; do
        # Добавляем Tests к имени модели
        models="${models}${model}Tests"$'\n'
    done

    echo "$models" | grep -v '^$' | sort | uniq
}

# Функция для замены упоминаний моделей и хелперов в комментариях на DoCC ссылки
# Пример: "SetAuthenticationPhoneNumberRequest" -> "<doc:SetAuthenticationPhoneNumberRequestTests>"
# Пример: "MockTDLibFFI" -> "<doc:MockTDLibFFITests>"
add_doc_links_to_models() {
    local text="$1"

    # Заменяем *Request на ссылки (например, SetAuthenticationPhoneNumberRequest)
    # Используем [[:<:]] и [[:>:]] для word boundaries (BSD sed в macOS)
    text=$(printf '%s\n' "$text" | sed -E 's/[[:<:]]([A-Z][a-zA-Z]*Request)[[:>:]]/<doc:\1Tests>/g')

    # Заменяем *Response на ссылки (например, AuthorizationStateUpdateResponse)
    text=$(printf '%s\n' "$text" | sed -E 's/[[:<:]]([A-Z][a-zA-Z]*Response)[[:>:]]/<doc:\1Tests>/g')

    # Заменяем хелперы тестирования на ссылки (MockTDLibFFI, ResponseWaiters, TDLibClient, Update)
    text=$(printf '%s\n' "$text" | sed -E 's/\b(MockTDLibFFI|ResponseWaiters|TDLibClient|Update)\b/<doc:\1Tests>/g')

    printf '%s' "$text"
}

# Функция для генерации DoCC markdown из тестового файла
generate_docc_from_test() {
    local test_file="$1"
    local output_dir="$2"
    local test_type="$3"  # "Unit" или "Component"
    local test_type_ru=""

    if [ "$test_type" == "Unit" ]; then
        test_type_ru="Юнит"
    elif [ "$test_type" == "E2E" ]; then
        test_type_ru="E2E"
    else
        test_type_ru="Компонентный"
    fi

    # Извлечение имени файла без расширения
    local filename=$(basename "$test_file" .swift)
    local output_file="$output_dir/${filename}.md"

    # GitHub URL для исходника
    local github_url="https://github.com/flyer2001/tg-client/blob/main/${test_file}"

    # Извлечение @Suite doc comment и названия
    local suite_line=$(grep -n "@Suite" "$test_file" | head -1 | cut -d: -f1)
    if [ -z "$suite_line" ]; then
        return
    fi

    # Извлечение названия Suite (в кавычках после @Suite)
    local suite_name=$(sed -n "${suite_line}p" "$test_file" | sed -n 's/.*@Suite("\(.*\)").*/\1/p')
    if [ -z "$suite_name" ]; then
        # Fallback: используем имя struct/class
        suite_name=$(grep -A1 "@Suite" "$test_file" | grep "struct\|class" | sed 's/.*struct \|.*class \|{//g' | xargs)
    fi

    # Извлечение doc comment для Suite
    local suite_doc=$(extract_doc_comment "$test_file" "$suite_line")

    # Начало генерации markdown
    cat > "$output_file" <<EOF
# ${suite_name}

## Описание

${suite_doc}

**Тип теста:** ${test_type_ru}

**Исходный код:** [\`${test_file}\`](${github_url})

## Тестовые сценарии

EOF

    # Извлечение всех @Test методов с doc comments
    local test_lines=$(grep -n "@Test" "$test_file" | cut -d: -f1)

    for test_line in $test_lines; do
        # Извлечение названия теста (в кавычках или скобках после @Test)
        local test_name=$(sed -n "${test_line}p" "$test_file" | sed -n 's/.*@Test("\(.*\)").*/\1/p')

        # Если название не найдено, пробуем извлечь из имени функции
        if [ -z "$test_name" ]; then
            local next_line=$((test_line + 1))
            test_name=$(sed -n "${next_line}p" "$test_file" | sed 's/.*func \([^(]*\).*/\1/' | sed 's/\([A-Z]\)/ \1/g' | xargs)
        fi

        # Извлечение doc comment для теста (///)
        local test_doc=$(extract_doc_comment "$test_file" "$test_line")

        # Извлечение комментариев из тела функции (//)
        local test_body_comments=$(extract_test_body_comments "$test_file" "$test_line")

        # Добавляем DoCC ссылки на модели в комментариях
        test_body_comments=$(add_doc_links_to_models "$test_body_comments")

        # Добавление в markdown
        cat >> "$output_file" <<EOF
### ${test_name}

${test_doc}

${test_body_comments}

---

EOF
    done

    # Добавление Topics секции (для навигации)
    cat >> "$output_file" <<EOF

## Topics

### Связанная документация

- <doc:TgClient>
EOF

    # Добавление backlink на E2E сценарий (если это компонентный тест авторизации)
    if [[ "$filename" == *"Authentication"* ]] && [[ "$test_type" == "Component" ]]; then
        cat >> "$output_file" <<EOF
- <doc:Authentication>
EOF
    fi

    # Для component-тестов: добавляем ссылки на unit-тесты Request/Response моделей
    if [[ "$test_type" == "Component" ]]; then
        local model_refs=$(extract_model_references "$test_file")

        if [ -n "$model_refs" ]; then
            cat >> "$output_file" <<EOF

### Unit-тесты используемых моделей

EOF
            # Добавляем ссылку на каждую модель
            while IFS= read -r model_test; do
                if [ -n "$model_test" ]; then
                    cat >> "$output_file" <<EOF
- <doc:${model_test}>
EOF
                fi
            done <<< "$model_refs"
        fi
    fi
}

# Обработка Unit тестов
while IFS= read -r test_file; do
    generate_docc_from_test "$test_file" "$UNIT_TESTS_DIR" "Unit"
done < <(find Tests/TgClientUnitTests -name "*Tests.swift" -type f)

# Обработка Component тестов
while IFS= read -r test_file; do
    # Пропускаем Mocks (они не тесты)
    if [[ "$test_file" != *"Mock"* ]]; then
        generate_docc_from_test "$test_file" "$COMPONENT_TESTS_DIR" "Component"
    fi
done < <(find Tests/TgClientComponentTests -name "*Tests.swift" -type f)

# Обработка E2E тестов
while IFS= read -r test_file; do
    generate_docc_from_test "$test_file" "$E2E_TESTS_DIR" "E2E"
done < <(find Tests/TgClientE2ETests -name "*Tests.swift" -type f)

echo "✅ DoCC документация успешно сгенерирована"
