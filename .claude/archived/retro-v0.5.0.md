# Ретроспектива v0.5.0 — Отслеживание метрик

**Период разработки v0.5.0:** TBD
**Дата релиза:** TBD

---

## 🔄 ПРОМПТ ДЛЯ СБОРА ЛОГА МЕТРИК (раз в 1-3 дня)

**Скопируй и запусти этот промпт в новой сессии:**

```
Дата: ____

Отслеживание метрик v0.5.0 (раз в 1-3 дня).

**Роль:** AI-Assisted Developer

**Читать:**
1. .claude/archived/retro-v0.5.0.md (этот файл)
2. .claude/archived/retro-v0.4.0.md (контекст целевых метрик, секция "Итоги")

**Задача:**
Проверить соблюдение правил и метрик за последние 1-3 дня:

1. **Research-First для External APIs:**
   - Были ли новые External APIs?
   - Research-First применён? (WebFetch + live эксперименты + failing test + manual UI verification)

2. **Mock только boundaries:**
   - Были ли новые Mock*.swift?
   - Правило соблюдено? (boundary: FFI/network/filesystem)

3. **Code Review вчерашних коммитов:**
   - Проводился ли review? (когда промпт содержит "Code Review")
   - Проблемы найдены? (критичные/желательные/опционально)

4. **User Story + spike research ДО TDD:** 🆕
   - Была ли новая версия или фича?
   - User Story создан ДО реализации?
   - Spike research выполнен (если External API)?
   - Planning Architect → Testing Architect gating сработал?

5. **Модели через Unit Test ДО Component Test:** 🆕
   - Были ли новые модели (struct/enum/class)?
   - Unit Test для модели создан ДО Component Test?
   - После spike search вернулись к TDD порядку?

6. **Правило 0: Grep/Read похожий код ПЕРЕД написанием:** 🆕
   - Был ли новый код (High-Level API, Service, TaskGroup)?
   - Claude выполнил Grep/Read похожих модулей?
   - Claude спросил пользователя про существующий паттерн?
   - Паттерн переиспользован (НЕ изобретён велосипед)?

7. **TSan для concurrency компонентов:**
   - Были ли новые concurrency компоненты (actor, TaskGroup)?
   - Architecture-First чеклист заполнен?
   - TSan запущен? (race conditions найдены?)

**Формат вывода:**
Prepend лог в секцию "📝 Логи метрик" этого файла (retro-v0.5.0.md).

Формат:
---
## Лог метрик — [Дата]

**Research-First:** X/Y External APIs (100% = целевой показатель)
**Mock только boundaries:** соблюдено/нарушено
**Code Review:** проведён/пропущен (когда промпт содержал "Code Review")
**User Story + spike research ДО TDD:** соблюдено/нарушено 🆕
**Модели через Unit Test:** соблюдено/нарушено 🆕
**Правило 0 применено:** ДА/НЕТ (Grep выполнен? Спросил пользователя? Переиспользован паттерн?) 🆕
**TSan:** GREEN/warnings (если были concurrency компоненты)

**Инциденты:**
- [описание если были]

**Нарушения правил:**
- [описание если были + root cause]

**Выводы:**
- Работает: [что работает]
- Не работает: [что не работает]
---

Давай проверим метрики!
```

---

## 📚 Контекст: Целевые метрики v0.5.0

**Из ретро v0.4.0 ([retro-v0.4.0.md](retro-v0.4.0.md), секция "Итоги"):**

### Целевые метрики v0.5.0:

**Оставлены под мониторинг (критично):**
1. **Research-First:** 100% External APIs (было 100% в v0.4.0) ✅
2. **Mock только boundaries:** 100% соблюдений (было 100% в v0.4.0) ✅
3. **TSan:** race conditions найдены ДО production (было 1 race condition в v0.4.0) ✅

**Новые метрики (из инцидентов v0.4.0):**
4. **Code Review:** 100% (когда промпт содержит "Code Review") 🆕
5. **User Story + spike research ДО TDD:** 100% соблюдение 🆕
6. **Модели через Unit Test ДО Component Test:** 100% соблюдение 🆕
7. **Правило 0 применено:** наблюдение (Grep/Read + спросить пользователя + переиспользовать) 🆕

**Убраны из мониторинга (стали естественными):**
- Дубликаты типов (два релиза подряд 0%, правило работает автоматически)
- Преждевременное завершение дебага (два релиза подряд 0 нарушений)

---

## 🎯 Новые правила v0.5.0 (для проверки эффективности)

### Правило 1: Planning Architect → Testing Architect gating

**Цель:** Предотвратить начало TDD без User Story и spike research

**Проверка:**
- Planning Architect создал User Story?
- Spike research выполнен (если External API)?
- Testing Architect проверил приемку (gating)?
- Если НЕТ → вернул в Planning?

**Где:** ROLES.md

---

### Правило 2: Правило 0 — Grep/Read похожий код ПЕРЕД написанием

**Цель:** Предотвратить изобретение велосипеда, переиспользовать существующие паттерны

**Проверка:**
- Новый код (High-Level API, Service, TaskGroup)?
- Claude выполнил Grep/Read похожих модулей?
- Claude спросил пользователя: "Вижу паттерн X в модуле Y. Переиспользовать?"
- Паттерн переиспользован?

**Где:** CLAUDE.md § "Workflow при получении задачи"

---

### Правило 3: После spike search → вернуться к TDD

**Цель:** Предотвратить потерю фокуса на TDD порядке после spike research

**Проверка:**
- Spike research выполнен?
- E2E документ обновлен (реальное поведение API)?
- Unit Test для модели создан ДО Component Test?

**Где:** TESTING.md § "Research-First"

---

### Правило 4: Code Review триггер в /endtask + /endsession

**Цель:** Обеспечить Code Review в начале следующего дня автоматически

**Проверка:**
- /endtask или /endsession спросили: "Последняя на сегодня?"
- Если ДА → промпт начинается с Code Review блока?
- Code Review проведён в начале следующей сессии?

**Где:** .claude/commands/endtask.md, .claude/commands/endsession.md, CLAUDE.md

---

## 📝 Логи метрик (prepend сюда после каждой проверки)

<!-- Логи добавляются через prepend (новые логи вверху) -->

---

## 🔴 Инциденты

<!-- Инциденты добавляются по мере обнаружения (prepend для новых) -->

---


---

### Инцидент #7: Попытка захардкодить Bot Token в E2E тест (секрет в репозиторий) (2025-12-18)

**Роль:** Senior Swift Developer

**Контекст:**
- Задача: Реализовать E2E manual test для BotNotifier
- Claude предложил захардкодить Bot Token в тестовом файле для "быстрого тестирования"
- **ПРОБЛЕМА:** Bot Token — чувствительная информация (секрет), НЕЛЬЗЯ в открытом репозитории

**Что было предложено (ОПАСНО!):**
```swift
// ⚠️ TEMP: Захардкожены credentials для быстрого тестирования
let botToken = "<REDACTED>"  // ❌ СЕКРЕТ В РЕПОЗИТОРИИ!
let chatId: Int64 = 566335622  // ✅ Chat ID — не секрет
```

**Root cause:**
- Claude воспринял "захардкодить для быстрого тестирования" как "все credentials"
- НЕ проверил что Bot Token = секрет (как API key)
- Пропустил security best practice: секреты ТОЛЬКО в env, НИКОГДА в коде
- Chat ID (публичный ID) спутан с Bot Token (приватный секрет)

**Правильный подход:**
```swift
// ✅ Секреты из env, публичные ID можно захардкодить
guard let botToken = ProcessInfo.processInfo.environment["TELEGRAM_BOT_TOKEN"] else {
    Issue.record("BOT_TOKEN не задан")
    return
}
let chatId: Int64 = 566335622  // ✅ Публичный chat_id, можно захардкодить
```

**Что МОЖНО захардкодить:**
- ✅ Chat ID (публичный идентификатор пользователя/чата)
- ✅ API endpoints (https://api.telegram.org)
- ✅ Константы (лимиты, timeouts)

**Что НЕЛЬЗЯ хардкодить:**
- ❌ Bot Token (секрет из @BotFather)
- ❌ API Keys (OpenAI, Telegram API)
- ❌ Пароли, приватные ключи

**Impact:**
- 🔴 **Критичный:** Bot Token в репозитории → compromised bot (кто угодно может использовать бота)
- 🔴 Риск: Если закоммитить → нужно revoke token через @BotFather
- ✅ Пользователь заметил ДО коммита

**Исправление:**
- [x] НЕ хардкодить Bot Token ✅
- [ ] Bot Token через env (`TELEGRAM_BOT_TOKEN`)
- [ ] Chat ID можно захардкодить (не секрет)
- [ ] Добавить комментарий в код: "⚠️ Bot Token — секрет, только из env!"

**Вопросы для ретро:**
1. **Почему Claude не распознал Bot Token как секрет?**
   - "Захардкодить credentials" воспринято буквально (все данные)
   - Нет явного чеклиста: "Bot Token = API Key = секрет"
   - Нужно: security reminder перед хардкодингом ЛЮБЫХ credentials

2. **Как предотвратить в будущем?**
   - TESTING.md § E2E Tests: "⚠️ Секреты (API keys, tokens) ТОЛЬКО из env!"
   - Триггер "захардкодить credentials" → Claude ДОЛЖЕН спросить: "Какие именно? API keys/tokens = env!"
   - Pre-commit hook: проверка на секреты (gitleaks, trufflehog)

3. **Разница между публичными ID и секретами:**
   - Chat ID, User ID — публичные (можно хардкодить для тестов)
   - Bot Token, API Key — секреты (ТОЛЬКО env, НИКОГДА в коде)
   - URL, endpoints — публичные (можно хардкодить)

**Lesson learned:**
- "Захардкодить для тестирования" ≠ "все credentials"
- Секреты (tokens, API keys) = env, НИКОГДА в коде
- Публичные ID (chat_id, user_id) = можно хардкодить

---

---

### Инцидент #6: Пропущен E2E manual test, начата integration БЕЗ завершения TDD (2025-12-18)

**Роль:** Senior Swift Developer → Senior Code Reviewer

**Контекст:**
- Задача: BotNotifier v0.5.0 — завершить TDD цикл
- Прогресс: ✅ E2E тест написан (RED, disabled) → ✅ Component тесты GREEN → ✅ Implementation GREEN
- **ПРОБЛЕМА #1:** Пропущен E2E manual test с реальным Bot API (последний шаг TDD)
- **ПРОБЛЕМА #2:** Начал integration в DigestOrchestrator БЕЗ завершения TDD цикла

**Outside-In TDD workflow должен быть:**
```
1. ✅ E2E тест написан (RED, disabled) — BotNotifierE2ETests.swift
2. ✅ Component тесты → GREEN — 9 тестов с MockHTTPClient
3. ✅ Implementation → GREEN — TelegramBotNotifier
4. ❌ E2E тест с реальным Bot API (enabled) — ПРОПУЩЕН!
5. ❌ Integration в DigestOrchestrator — НАЧАТ БЕЗ шага 4!
```

**Что было пропущено:**
- ❌ E2E manual test — enable E2E тест, задать env, запустить с реальным Bot API
- ❌ Проверка реального поведения API (могут быть edge cases которые mock не покрывает)
- ❌ TDD цикл завершён на шаге 3/4 вместо полного прохода

**Что было сделано:**
- ✅ Code Review проведён (force unwrap → guard, Specs паттерн)
- ✅ Все изменения после review: 281/281 тестов GREEN
- ❌ Начал integration в DigestOrchestrator (спросил про SRP, решили координацию в main.swift)
- ❌ E2E тест так и остался disabled

**Root cause:**
- **Отвлёкся на Code Review** — промпт содержал "Code Review + DigestOrchestrator integration"
- Code Review выполнен правильно (триггер сработал), но потерял фокус на TDD
- После Code Review сразу перешёл к integration, НЕ проверив TDD чеклист
- E2E manual test воспринят как "опциональный" (disabled тест = можно пропустить)

**Правильный процесс (TESTING.md § Outside-In TDD):**
```
☐ E2E тест написан (RED, disabled)
☐ Component тесты → GREEN
☐ Implementation → GREEN
☐ E2E manual test с реальным API/FFI — ОБЯЗАТЕЛЕН!
☐ ТОЛЬКО после E2E GREEN → integration в другие компоненты
```

**Почему E2E manual test ОБЯЗАТЕЛЕН:**
- Mock может не покрывать все edge cases реального API
- Реальный Bot API может иметь недокументированное поведение
- Инцидент #5: `entities` поле НЕ в docs, найдено только в live эксперименте
- Без E2E = **НЕ знаем работает ли компонент с реальным API**

**Impact:**
- ⚠️ Высокий: BotNotifier НЕ проверен с реальным Telegram Bot API
- ⚠️ Риск: могут быть баги которые mock не покрывает (JSON parsing, rate limits)
- ⚠️ Процесс: TDD цикл не завершён → integration преждевременна

**Исправление:**
- [ ] СТОП integration — вернуться к TDD
- [ ] Enable E2E тест BotNotifier
- [ ] Задать env переменные (BOT_TOKEN, CHAT_ID)
- [ ] Запустить E2E тест с реальным Bot API
- [ ] Убедиться что сообщение пришло в Telegram
- [ ] ТОЛЬКО после E2E GREEN → продолжить integration

**Вопросы для ретро:**
1. **Почему Claude пропустил E2E manual test?**
   - Code Review триггер сработал корректно, но сбил с TDD workflow
   - Disabled тест воспринят как "можно пропустить"
   - НЕТ явного чеклиста "TDD завершён?" перед integration

2. **Как предотвратить в будущем?**
   - TESTING.md § Outside-In TDD: добавить чеклист "TDD завершён?"
   - Явный шаг: "E2E manual test ОБЯЗАТЕЛЕН (даже если disabled для CI)"
   - ROLES.md → Senior Swift Developer: "Integration ТОЛЬКО после E2E GREEN"

3. **Нужно ли менять процесс?**
   - TDD цикл = 4 шага, НЕ 3 (E2E manual test НЕ опциональный!)
   - Disabled E2E тест = reminder для manual testing, НЕ "можно пропустить"
   - Integration = последний шаг ПОСЛЕ E2E GREEN

**Триггер для правильного поведения:**
- "Integration" в промпте → Claude ДОЛЖЕН спросить: "TDD завершён? E2E manual test пройден?"
- Если НЕТ → СТОП integration, вернуться к E2E manual test

---
### Инцидент #5: JSONEncoder/Decoder extension БЕЗ unit тестов + избыточные тесты для v0.6.0 (2025-12-16)

**Роль:** Senior Testing Architect

**Контекст:**
- Задача: Unit Tests для моделей Telegram Bot API (TDD шаг 4)
- Claude добавил `.telegramBot()` extension для JSONEncoder/Decoder
- Claude создал 16 тестов в TelegramBotAPIModelsTests.swift (350 строк)
- **ПРОБЛЕМА #1:** Extension добавлен БЕЗ unit тестов на snake_case конвертацию
- **ПРОБЛЕМА #2:** Половина тестов для MarkdownV2 (v0.6.0), который НЕ реализуется в v0.5.0

**Что было пропущено (TDD процесс):**
- ❌ Unit тесты для JSONEncoder.telegramBot() (проверка snake_case encoding)
- ❌ Unit тесты для JSONDecoder.telegramBot() (проверка snake_case decoding)
- ❌ Согласование объёма тестов (v0.5.0 scope: plain text ТОЛЬКО)
- ❌ Показ файла пользователю перед созданием

**Что было сделано:**
- ✅ Добавлен `.telegramBot()` extension в JSONCoding.swift
- ❌ БЕЗ тестов (нарушение TDD — extension до тестов)
- ✅ Создан TelegramBotAPIModelsTests.swift (16 тестов, 350 строк)
- ❌ Избыточные тесты: MarkdownV2 encoding/decoding (v0.6.0), entities field (v0.6.0)
- ❌ Не показан пользователю, не согласован

**Root cause:**
- Claude НЕ написал тесты для JSONEncoder/Decoder extension
- TDD порядок нарушен: extension → тесты (должно быть: тесты → extension)
- Scope v0.5.0 проигнорирован: plain text ТОЛЬКО, но тесты покрывают MarkdownV2
- Торопливость: создал большой файл без согласования

**Telegram Bot API ≠ TDLib API:**
- TDLib: snake_case, поле `"@type"` (custom CodingKey)
- Telegram Bot API: snake_case, поля `"ok"`, `"result"`, `"error_code"`
- Это **разные API** → нужны **отдельные тесты** encoder/decoder

**Правильный процесс (TDD):**
```
1. Unit Test для JSONEncoder.telegramBot() → проверка snake_case (chat_id, parse_mode)
2. Unit Test для JSONDecoder.telegramBot() → проверка snake_case (error_code, message_id)
3. Extension добавлен → тесты GREEN
4. Unit Tests для моделей (только v0.5.0 scope: plain text)
5. Models реализация
```

**Impact:**
- ⚠️ Средний: Extension БЕЗ тестов (может работать неправильно)
- ⚠️ Средний: Избыточные тесты (половина для v0.6.0, будут disabled)
- ⚠️ UX: Пользователь увидел 350 строк без согласования

**Исправление:**
- [ ] Удалить `.telegramBot()` extension из JSONCoding.swift
- [ ] Создать Unit тесты для JSONEncoder/Decoder.telegramBot() (TDD порядок)
- [ ] Добавить extension обратно → GREEN
- [ ] Упростить TelegramBotAPIModelsTests.swift: удалить MarkdownV2 тесты (v0.6.0)
- [ ] Оставить только v0.5.0 scope: plain text encoding/decoding, error responses
- [ ] Показать пользователю ПЕРЕД созданием

**Вопросы для ретро:**
1. **Почему Claude пропустил тесты для extension?**
   - Extension воспринят как "копирование OpenAI extension" (автоматическое)
   - TDD правило "тесты ДО реализации" НЕ применено к extension
   - Нужно: explicit reminder в TESTING.md — "Extension = код, нужны тесты"

2. **Почему Claude проигнорировал scope v0.5.0?**
   - Spike research содержит MarkdownV2 примеры → Claude покрыл их тестами
   - Scope v0.5.0 (plain text ТОЛЬКО) НЕ проверен перед созданием тестов
   - Нужно: перечитать scope из User Story ДО создания тестов

3. **Как предотвратить в будущем?**
   - TESTING.md § "Unit Tests" → "Extension тестируется как обычный код (тест → implementation)"
   - ROLES.md → Testing Architect: "Проверить scope (что реализуем СЕЙЧАС?) перед тестами"
   - Показывать структуру файла (summary) ПЕРЕД созданием: "16 тестов: 8 для v0.5.0, 8 для v0.6.0. Ок?"

---

### Инцидент #4: User Story создан в DocC комментариях вместо отдельного MD файла (2025-12-16)

**Роль:** Senior Testing Architect

**Контекст:**
- Задача: TDD для BotNotifier (шаг 1 — User Story документ)
- Claude начал с создания User Story для BotNotifier
- **ПРОБЛЕМА:** Создал User Story в DocC комментариях E2E теста, НЕ в отдельном MD файле

**Что было пропущено (TESTING.md § "TDD Workflow" + существующие User Story файлы):**
- ❌ НЕ проверил структуру существующих User Story файлов
- ❌ НЕ прочитал примеры: `Sources/TgClient/TgClient.docc/E2E-Scenarios/*.md`
- ❌ Создал User Story в неправильном месте (DocC комментарии вместо MD файла)

**Что было сделано:**
- ✅ Содержание User Story корректно (проблема пользователя, Acceptance Criteria, scope)
- ✅ Ссылки на spike research и architecture
- ❌ Формат: DocC комментарии в `Tests/TgClientE2ETests/BotNotifierE2ETests.swift`
- ❌ НЕ создан отдельный MD файл: `Sources/TgClient/TgClient.docc/E2E-Scenarios/BotNotifier.md`

**Root cause:**
- Claude НЕ проверил существующие User Story файлы перед созданием нового
- TDD Workflow (шаг 1) понят как "User Story в любом виде", а не "следовать структуре проекта"
- **Правило 0 пропущено:** "Grep/Read похожий код ПЕРЕД написанием"

**Правильный процесс (Правило 0 из CLAUDE.md):**
```
☐ Grep User Story файлы (E2E-Scenarios/*.md)
☐ Read существующий User Story (FetchUnreadMessages.md)
☐ Создать BotNotifier.md по паттерну существующих
☐ E2E тест ссылается на <doc:BotNotifier>
```

**Impact:**
- ⚠️ Низкий: пользователь заметил до завершения, не закоммичено
- ⚠️ UX: User Story должен быть отдельным документом (DocC catalogue)
- ⚠️ Риск: нарушение структуры проекта (User Story разбросаны)

**Исправление:**
- [ ] Создать `Sources/TgClient/TgClient.docc/E2E-Scenarios/BotNotifier.md` по паттерну FetchUnreadMessages.md
- [ ] Переделать E2E тест — ссылка на `<doc:BotNotifier>` вместо User Story в комментариях
- [ ] Удалить User Story текст из DocC комментариев E2E теста

**Вопросы для ретро:**
1. **Почему Claude пропустил Правило 0?**
   - Правило 0 применяется к "коду" (struct/enum/class), но НЕ к документации?
   - Нужно расширить Правило 0: "User Story, E2E тест → grep существующие примеры"

2. **Как предотвратить в будущем?**
   - TESTING.md § "TDD Workflow" → явный шаг: "Read существующий User Story файл (паттерн)"
   - ROLES.md → Testing Architect gating: "User Story файл создан по паттерну существующих?"

3. **Нужно ли менять процесс?**
   - Правило 0 распространяется на ВСЕ артефакты (код, тесты, документация)
   - Перед созданием ЛЮБОГО файла: Grep/Read похожие, спросить пользователя

---

### Инцидент #3: Architecture-First результат как "огромная портянка текста" (2025-12-16)

**Роль:** Senior Swift Architect

**Контекст:**
- Задача: Architecture-First анализ (7 блоков) для TelegramBotNotifier
- Claude выполнил полный анализ по чеклисту (7 блоков + критичные решения)
- **ПРОБЛЕМА:** Выкатил весь результат одним сообщением (~50+ строк) без пошагового обсуждения

**Что было пропущено (CLAUDE.md § "Правила для ассистента"):**
- ❌ "Сначала решение/вывод (2-3 строки), детали — по запросу"
- ❌ "Паузы между этапами, спрашивай 'Продолжаем?'"
- ❌ Пошаговое обсуждение каждого из 7 блоков

**Что было сделано:**
- ✅ Прочитаны ROLES.md, spike research
- ✅ Выполнен анализ по чеклисту Senior Swift Architect (7 блоков)
- ✅ Критичные решения проработаны (MarkdownV2, split, HTTPClient)
- ❌ Формат подачи: одно сообщение вместо диалога

**Root cause:**
- Claude прочитал ROLES.md (чеклист 7 блоков), но забыл про CLAUDE.md формат общения
- Architecture-First воспринят как "выполнить чеклист → выдать отчёт"
- Пропущен принцип: "кратко → обсуждение → детали"

**Правильный процесс (CLAUDE.md):**
```
1. Вывод (2-3 строки): "Проанализировал TelegramBotNotifier. 3 критичных решения нужно обсудить"
2. Спросить: "Идём блок за блоком (1. Concurrency → ... → 7. Testing)?"
3. Каждый блок: решение (2-3 строки) → "Продолжаем к следующему?"
4. Критичные решения: по одному (MarkdownV2 → split → HTTPClient)
```

**Impact:**
- ⚠️ Средний: пользователь получил "портянку текста" вместо диалога
- ⚠️ UX: сложно переварить результат целиком, нужно обсуждение
- ⚠️ Риск: пользователь может пропустить важные детали в большом тексте

**Исправление:**
- [ ] Обсудить Architecture-First результаты поэтапно (7 блоков)
- [ ] Обсудить критичные решения по одному
- [ ] Добавить правило в ROLES.md → Senior Swift Architect: "Результат Architecture-First обсуждаем блок за блоком"

**Вопросы для ретро:**
1. **Почему Claude забыл про формат общения?**
   - Роль (Senior Swift Architect) прочитана, но CLAUDE.md принципы пропущены
   - Нужно ли добавлять "формат общения" в каждую роль?

2. **Как предотвратить в будущем?**
   - ROLES.md → каждая роль: напоминание "следуй CLAUDE.md § Правила для ассистента"
   - Explicit reminder после анализа: "Обсудить поэтапно (не выкатывать портянку)"

3. **Нужно ли менять процесс?**
   - Architecture-First = диалог (блок за блоком), НЕ отчёт
   - Каждый блок: решение → обсуждение → подтверждение
   - В конце: резюме (1-2 строки на блок) + handoff в TDD

---

### Инцидент #1: Пропущен live эксперимент в spike research (2025-12-15)

**Роль:** Planning Architect

**Контекст:**
- Задача: Spike research для Telegram Bot API (v0.5.0 BotNotifier)
- Claude провёл WebFetch документации, проанализировал библиотеку swift-telegram-sdk
- Создал spike документ: `.claude/archived/spike-telegram-bot-api-2025-12-15.md`
- **ПРОБЛЕМА:** НЕ выполнен live эксперимент (реальный запрос к Telegram Bot API)

**Что было пропущено (TESTING.md строки 74, 82, 88):**
- ❌ Live эксперимент (throwaway код для проверки реального поведения)
- ❌ Реальный JSON ответ от sendMessage API
- ❌ Проверка edge cases (4096 chars limit, MarkdownV2 escape на практике)
- ❌ Manual E2E для получения реального JSON (debug лог)

**Что было сделано:**
- ✅ WebFetch Telegram Bot API docs (sendMessage, getUpdates)
- ✅ WebFetch swift-telegram-sdk (зависимости, стабильность)
- ✅ Анализ и рекомендация (библиотека vs HTTP calls)
- ✅ Создан spike документ с архитектурой

**Root cause:**
- Claude прочитал TESTING.md, но НЕ применил чеклист Research-First полностью
- Spike research был объявлен "DONE" без throwaway кода
- Пользователь заметил несоответствие процессу

**Что нужно было сделать:**
1. Получить bot token через @BotFather
2. Создать throwaway скрипт (curl или Swift)
3. Отправить реальный запрос sendMessage
4. Получить реальный JSON ответа (success + error cases)
5. Проверить MarkdownV2 escape (как работает на практике)
6. Проверить лимит 4096 символов (truncate или split)
7. Записать результаты в spike документ

**Impact:**
- ⚠️ Средний: spike документ содержит теоретическую информацию, но НЕТ практической проверки
- ⚠️ Риск: модели (SendMessageRequest/Response) могут не соответствовать реальному API
- ⚠️ Риск: MarkdownV2 escape может работать иначе чем в документации

**Исправление:**
- [ ] Выполнить live эксперимент (создать бота, отправить запросы)
- [ ] Обновить spike документ реальными JSON примерами
- [ ] Добавить edge cases из практической проверки

**Вопросы для ретро:**
1. **Почему Claude пропустил live эксперимент?**
   - Чеклист Research-First прочитан, но НЕ применён полностью
   - Нужно ли сделать чеклист более явным? (TODO перед spike документом?)

2. **Как предотвратить в будущем?**
   - Добавить в ROLES.md → Planning Architect: "Spike research = throwaway код ОБЯЗАТЕЛЬНО"
   - Explicit reminder в TESTING.md перед spike research?

3. **Нужно ли менять процесс?**
   - Spike research НЕ завершён пока НЕТ throwaway кода + реальных JSON
   - Planning Architect НЕ может объявить "spike DONE" без live эксперимента

---

### Инцидент #2: Попытка написать production модели в spike документе (2025-12-15)

**Роль:** Planning Architect

**Контекст:**
- Задача: Обновить spike документ после live эксперимента
- Claude выполнил live эксперимент, получил реальные JSON
- **ПРОБЛЕМА:** Попытался написать production модели (Message, User, Chat, MessageEntity) в spike документ

**Что было пропущено (TESTING.md строки 99-103):**
- ❌ Spike research → вернуться к TDD Workflow
- ❌ Unit Test для моделей (сначала тест структуры данных)
- ❌ Component Test (RED)
- ❌ Реализация → GREEN

**Что пытался сделать:**
- ❌ Edit spike документа — добавить production модели с полями `entities`, `from`, `date`
- ❌ Написать Codable структуры БЕЗ unit тестов
- ❌ Пропустить TDD workflow

**Root cause:**
- Claude прочитал TESTING.md ("После spike research"), но НЕ применил
- Попытался сразу в production код, минуя TDD
- Spike документ воспринят как "место для всего кода", а не "результаты исследования"

**Spike research должен содержать:**
- ✅ Документация (WebFetch)
- ✅ Live эксперимент (throwaway код)
- ✅ Реальные JSON responses (для Unit тестов)
- ✅ Критичные находки (MarkdownV2 escape, entities field)
- ✅ Рекомендация (библиотека vs HTTP calls)
- ❌ **НЕ production модели!**

**Правильный процесс (TESTING.md строка 87-92):**
```
1. Spike → понять API (throwaway код + реальные JSON)
2. Architecture → edge cases, concurrency, memory
3. ADR → документ решения (если >50 строк)
4. TDD → Unit Test для моделей → Component Test → Implementation
```

**Impact:**
- ⚠️ Низкий: пользователь заметил до коммита
- ⚠️ Риск: production модели БЕЗ unit тестов → баги в encoding/decoding

**Исправление:**
- [x] Удалить production модели из spike документа ✅
- [x] Spike research ЗАКОНЧЕН на: live эксперимент + реальные JSON + рекомендация ✅
- [ ] Следующий шаг: Architecture-First (7 блоков), затем TDD

**Вопросы для ретро:**
1. **Почему Claude снова пропустил TDD?**
   - Spike документ = "место для кода" (неправильное понимание)
   - TESTING.md прочитан, но чеклист НЕ применён
   - Нужен explicit reminder: "Spike research НЕ содержит production моделей"

2. **Как предотвратить в будущем?**
   - Добавить в TESTING.md § Research-First: "⚠️ Spike документ БЕЗ production моделей!"
   - Planning Architect handoff: "Spike done → передаю в Architecture-First"
   - Explicit checklist ПЕРЕД Edit spike документа

3. **Нужно ли менять процесс?**
   - Spike документ = результаты исследования (JSON, находки, рекомендация)
   - Production код = ТОЛЬКО через TDD (Unit Test → Implementation)
   - Planning Architect завершает на рекомендации, НЕ на коде
