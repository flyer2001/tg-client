---
version: 2.0.0
bumped: 2026-10-16
bumped_reason: "сборка — на ubuntu-home Swift 6.4 инкрементально (build-clean.sh только при зависании); Research-First: эксперимент до падающего теста; подменяем FFI/HTTP/время, файлы настоящие; ссылки на TESTING.md"
---

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 🎯 Цель проекта

CLI-клиент Telegram: логин → чтение непрочитанных → саммари через внешний AI → отправка результата через бота

---

## 📋 СТАТИЧНЫЕ ПРАВИЛА (кэшируемая секция)

### Неснимаемые правила

- **Пишем код по TDD** (детали в [TESTING.md](.claude/TESTING.md)). Сборка на Linux обязательна.
- Swift 6; зависимости ≤ 6 мес.; минимум внешних библиотек.
- Логи на каждом внешнем вызове (Telegram, AI, Bot). Секреты только из env.
- Изменения > 2 файлов или смена архитектуры — сначала план/RFC.

### Правила для ассистента

- Нужны деплой/SSH/env? Иди в документы ниже. Секреты в код не добавлять.
- Публичные контракты не менять без тестов. Если правок много — сначала план.
- По умолчанию отвечай кратко (6–10 строк); разворачивай детали только по запросу.
- **При правках кода:** НЕ дублируй весь код. Дай 2-3 строки до/после изменения. Несколько блоков — ок.
- **Обращайся как к эксперту:** Без объяснений базовых концепций Swift/TDD. Сразу к сути.
- **Роли**: используй роли из [ROLES.md](.claude/ROLES.md) в зависимости от типа задачи (Architect для проектирования, Testing Architect для тестов, Swift Developer для кода, AI-Assisted Developer для контекста).
- **Git коммиты**: на русском, БЕЗ "Co-Authored-By: Claude", БЕЗ упоминаний AI.
- **Перед коммитом**: раздели коммиты (Sources/, Tests/) отдельно, документация отдельно; актуализируй TASKS.md и предложи добавить запись в CHANGELOG.md (prepend через bash). Если критичный контекст — обнови DEPLOY/ARCHITECTURE/TROUBLESHOOTING.
- **⚠️ КРИТИЧНО: Безопасность работы с git:**
  - **ЗАПРЕЩЕНО** использовать `git reset --hard`, `git clean -fd` или другие деструктивные команды БЕЗ явного предупреждения пользователю
  - Перед деструктивной операцией ОБЯЗАТЕЛЬНО: показать `git status`, перечислить ЧТО ИМЕННО будет потеряно, спросить подтверждение
  - Если есть unstaged/uncommitted изменения → сначала спросить пользователя что с ними делать (stash, commit, discard)
  - Для отката изменений использовать `git stash` вместо `git reset --hard` (stash можно восстановить)
- **⚠️ КРИТИЧНО: Где собирать:**
  - **VDS — не собирать** (2 ядра / 4 ГБ). Сборка и тесты — на **ubuntu-home** (Swift 6.4): rsync (с `--exclude .env`) → `swift build` / `swift test` по ssh; инкрементальная сборка работает
  - `./scripts/build-clean.sh` — только если SwiftPM завис (наследие Swift 6.2)
  - **macOS** → `swift build` напрямую
- **⚠️ КРИТИЧНО: НИКОГДА не используй pipe с swift test:**
  - **ЗАПРЕЩЕНО:** `swift test | head`, `swift test | tail`, `swift test | grep`
  - **Причина:** SIGPIPE убивает swift test и вызывает зависание
  - **Правильно:** `swift test 2>&1` (без pipe) или сохранить в файл: `swift test 2>&1 | tee /tmp/test.log`
- **⚠️ КРИТИЧНО: Чтение GitHub Issues:**
  - **ВСЕГДА** используй `gh issue view <номер> --repo <owner/repo> --comments` для чтения GitHub issues
  - **НИКОГДА** не используй WebFetch для GitHub issues (не видит динамический контент/JavaScript)
  - **Пример:** `gh issue view 9441 --repo swiftlang/swift-package-manager --comments`
  - **Причина:** WebFetch получает только статический HTML, пропускает комментарии загруженные через JavaScript
- **⚠️ КРИТИЧНО: Эффективное использование bash команд:**
  - **Для команд с большим выводом** (swift build, swift test, долгие скрипты):
    - **ВСЕГДА используй `tee`** → пользователь видит полный вывод в реальном времени
    - Claude читает только нужное через отдельную команду → экономия контекста
    - **Паттерн:**
      ```bash
      # Шаг 1: Запуск с tee (пользователь видит ВСЁ)
      swift build 2>&1 | tee /tmp/build.log

      # Шаг 2: Claude читает только нужное (экономия контекста)
      grep -E "warning|error" /tmp/build.log || echo "No warnings/errors"
      ```
  - **Для быстрых проверок** (без tee):
    - `swift build 2>&1 | grep -m 5 -E "warning|error|Build complete"` — только если НЕ нужен полный вывод пользователю
  - **Причина tee:** Пользователь видит прогресс в реальном времени, Claude экономит контекст

#### Workflow при получении задачи (TDD)

**⚠️ Новый API или новый метод существующего API** → Research-First обязателен! См. [TESTING.md#research-first](.claude/TESTING.md#research-first)

**🔴 Правило 0 (ДО начала написания кода) [RETRO-v0.4.0]:**

1. **Grep/Read похожий код:**
   - Ищи похожие компоненты/паттерны в кодебазе (Grep по ключевым словам)
   - Прочитай найденный код (Read) — как уже решена похожая задача?
   - Примеры: RequestHandler? → ищи другие handlers; Actor? → ищи существующие actors

2. **Спроси пользователя:**
   - "Нашёл похожий паттерн в X. Переиспользовать его для Y?"
   - Покажи найденный код (2-3 строки ключевой логики)

3. **Переиспользуй паттерн:**
   - Копируй структуру, не изобретай заново
   - Consistency > novelty

**Почему:** v0.4.0 — переизобретение паттернов вместо переиспользования готовых решений.

**Перед кодом:**
1. Уточни контекст: "На какой модуль ориентироваться?"
2. TDLib метод? → WebFetch документацию `core.telegram.org/tdlib/docs`
3. Определи тип задачи (спроси если сомневаешься):
   - **Новая user story** → E2E сценарий
   - **Техническая деталь** → Component/Unit Test
4. **Прочитай:** [TESTING.md](.claude/TESTING.md), [ROLES.md](.claude/ROLES.md)
5. Новый компонент? → Архитектурный анализ (см. [ARCHITECTURE.md](.claude/ARCHITECTURE.md))

**Правило:** Сначала план/решение кратко (2-3 строки), потом детали по запросу. Паузы между этапами, спрашивай "Продолжаем?"

Детали Outside-In TDD: [TESTING.md](.claude/TESTING.md), паттерны: [TESTING-PATTERNS.md](.claude/TESTING-PATTERNS.md)

### 🔴 КРИТИЧНЫЕ WORKFLOW [RETRO-v0.3.0]

#### External API → Research-First обязателен

**Статистика v0.3.0:** Без Research-First: 100% багов. С Research-First: 0% багов.

```
☐ WebFetch документация (параметры + behaviour + edge cases)
☐ Live эксперимент / спайк (если семантика неочевидна: offset, pagination, async updates, форумы)
☐ Failing test с краевыми сценариями (на реальном JSON из эксперимента)
☐ Только потом реализация
```

Детали: [TESTING.md#research-first](.claude/TESTING.md#research-first)

#### Mock только boundaries

**Правило:** подменяем ТОЛЬКО внешние boundaries (FFI TDLib, HTTP, время), НЕ internal logic. Файлы и сокеты — настоящие во временной папке.

| Что мокаем | Правильно ✅ | Неправильно ❌ |
|------------|-------------|----------------|
| TDLib | MockTDLibFFI | MockTDLibClient |
| HTTP | MockHTTPClient | MockSummaryGenerator |

**Причина:** Переиспользуем реальную логику → меньше дублирования, больше покрытие.

#### Перед созданием типа → Grep

```
☐ Grep "struct TypeName" + "enum TypeName" в модуле
☐ Grep "import.*TypeName" (может быть в другом модуле)
☐ Только если NOT FOUND → создавать новый файл
```

**Причина:** v0.3.0 — дубликат ChatList обнаружен компилятором (16% новых типов).

#### Новый компонент → Architecture-First

**Роль:** Senior Swift Architect ([ROLES.md](.claude/ROLES.md))

Чеклист 7 блоков перед реализацией:
1. **Concurrency:** Sequential/Parallel? Thread-safety? Deadlock риски?
2. **Производительность:** TaskGroup? Bottleneck? Rate limits?
3. **Память:** Пагинация? Unbounded growth?
4. **Отказоустойчивость:** Partial failure? Retry? Timeout?
5. **Pipeline:** Место в pipeline? Зависимости? Parallel→Sequential переход?
6. **Наблюдаемость:** Логи? Метрики? Debugging?
7. **Testing:** TSan для concurrency? Edge cases?

#### Баг-фикс → НЕ завершать без proof

**Дебаг НЕ завершён пока:**
1. Баг НЕ воспроизведён в логах/тестах
2. Фикс НЕ подтверждён на реальных данных
3. Regression test НЕ добавлен
4. Пользователь НЕ подтвердил решение

**Триггеры для продолжения дебага:**
- "removed 0 X" при заявленной проблеме с X
- Отсутствие воспроизведения в логах

### Архитектура MVP

5 core модулей: MessageSource, SummaryGenerator, BotNotifier, StateManager, DigestOrchestrator.

Детали: [MVP.md](.claude/MVP.md), [ARCHITECTURE.md](.claude/ARCHITECTURE.md)

### Быстрые команды (для активной разработки)

```bash
# Сборка/тесты — на ubuntu-home (Swift 6.4, /opt/swift-6.4.0), код синкается с VDS:
rsync -az --delete --exclude .build --exclude .git --exclude .env ./ ubuntu-home:tg-client/
ssh ubuntu-home 'cd ~/tg-client && export PATH=/opt/swift-6.4.0/usr/bin:$PATH && swift build'
# Зависание SwiftPM → ./scripts/build-clean.sh

# Тесты: ⚠️ НЕ pipe (| head/tail/grep) — SIGPIPE зависание. Лог в файл, потом grep
swift test --skip TgClientE2ETests > /tmp/tg-test.log 2>&1
swift test --filter MyTest > /tmp/tg-test.log 2>&1
scripts/test-metrics.sh /tmp/tg-test.log     # метрики тестов

# Запуск приложения
swift run tg-client
```

Подробнее см. [DEPLOY.md#macOS](.claude/DEPLOY.md#macos-локальная-разработка)

---

## 🔄 ДИНАМИЧЕСКИЕ ИНСТРУКЦИИ (в начале сессии)

**🔴 Code Review триггер [RETRO-v0.4.0]:**

**Если промпт содержит "Code Review" → ОБЯЗАТЕЛЬНО выполнить Code Review ПЕРЕД всеми другими задачами.**

- Роль: Senior Code Reviewer ([ROLES.md](.claude/ROLES.md))
- НЕ откладывай на потом, НЕ делай параллельно с другими задачами
- Чек-лист 4 блоков: Безопасность, Тесты/логи, Качество кода, Архитектурные риски

**Почему:** v0.4.0 — Code Review откладывался или игнорировался при наличии других задач.

**🚀 НАЧАЛО НОВОЙ СЕССИИ (Development Flow):**

1. `git fetch && git status` - проверить актуальность кода (разработка идёт на desktop + server)
2. Если origin/main впереди → выполни `git pull`
3. **Первая сессия за день?** → предложить code review:
   - Проверить `git log --since="yesterday" --oneline`
   - Если есть коммиты за вчера → "Предлагаю code review вчерашних изменений"
   - Роль: Senior Code Reviewer ([ROLES.md](.claude/ROLES.md))
4. **Анализ состояния:**
   - **Если staged changes есть** → это WIP (work-in-progress):
     - Прочитай TASKS.md для контекста текущей задачи
     - Предложи: "Вижу staged changes по задаче X. Продолжаем работу?"
     - Коммиты будут сделаны позже (не предлагай автоматически)
   - **Если staged changes нет** → прочитай TASKS.md и предложи новую задачу

**⚠️ ФОКУС НА MVP:**
Все новые задачи направлены на достижение MVP. Детали scope — по требованию в [MVP.md](.claude/MVP.md).

**🔄 Регулярная проверка (раз в 1-3 дня) — ОБЯЗАТЕЛЬНО:**
Claude должен активно предлагать проверку ретро. Промпт: [TASKS.md](.claude/TASKS.md#-проверка-гипотез-ретро)
Результат записать в `.claude/archived/RETRO-RESULT.md` (append с датой; файл создаётся при первой записи)

---

## 📚 СТРАТЕГИЯ ЧТЕНИЯ ДОКУМЕНТАЦИИ

**Читать в начале сессии:**
- **[ROLES.md](.claude/ROLES.md)** - роли для разных типов задач (выбрать под задачу!)
- **[TESTING.md](.claude/TESTING.md)** - TDD, Research-First, стратегия тестирования
- **[ARCHITECTURE.md](.claude/ARCHITECTURE.md)** - архитектура, модули, паттерны

**⚠️ Explicit Read [RETRO-2024-11]:**
При начале задачи — выбрать роль из ROLES.md и **сообщить пользователю**:
> "Перечитываю TESTING.md для задачи X. Роль: Testing Architect"

| Тип задачи | Обязательно | По ситуации |
|------------|-------------|-------------|
| Новая фича/модуль | TESTING.md, ARCHITECTURE.md, ROLES.md | MVP.md |
| Баг-фикс | TESTING.md, TROUBLESHOOTING.md | ARCHITECTURE.md |
| Рефакторинг | ARCHITECTURE.md, TESTING.md | - |
| Тесты | TESTING.md, ROLES.md | - |
| Документация | [TESTING.md#документация-в-тестах](.claude/TESTING.md#документация-в-тестах) | - |
| Деплой/инфра | [DEPLOY.md](.claude/DEPLOY.md) | - |

**Читать только по требованию:**
- **[TASKS.md](.claude/TASKS.md)** - текущие задачи (часто меняется)
- **[CHANGELOG.md](.claude/CHANGELOG.md)** - история сессий (⚠️ только prepend через bash)
- **[MVP.md](.claude/MVP.md)** - цели и scope MVP (по требованию)
- **[BACKLOG.md](.claude/BACKLOG.md)** - бэклог для версий после MVP (по требованию)
- **[DEPLOY.md](.claude/DEPLOY.md)** - развёртывание, настройка окружения, env (по требованию)
- **[TROUBLESHOOTING.md](.claude/TROUBLESHOOTING.md)** - частые проблемы (по требованию)

---

## 🎛️ УПРАВЛЕНИЕ КОНТЕКСТОМ

При warning CLI о большом контексте (compact suggestion) → предложи `/endsession` или вручную: обновить TASKS.md, prepend в CHANGELOG.md, написать промпт для следующей сессии.

