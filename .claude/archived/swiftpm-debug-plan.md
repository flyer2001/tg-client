# SwiftPM Incremental Build Hang — Debug & Fix Plan

**Цель:** Найти и исправить root cause зависания SwiftPM 6.2 на инкрементальных сборках (KVM/Linux)

**Контекст:** 
- Issue: https://github.com/swiftlang/swift-package-manager/issues/9441
- Симптом: `epoll_wait`/`timerfd_settime` loop в "Planning build" фазе
- Workaround: Swift 6.0 работает ✅
- Environment: Ubuntu 24.04, Kernel 6.11, KVM VDS

---

## Phase 0: Подготовка (ждём ответа от техподдержки)

**⏳ Ожидаем:**
- [ ] Ответ от хостинга UFO (1-3 дня)
- [ ] Ответ от SwiftPM мейнтейнеров (3-7 дней)

**✅ Условие старта Phase 1:**
- Хостинг не нашёл KVM-фикс ИЛИ
- Мейнтейнеры просят больше диагностики ИЛИ
- Прошло 7 дней без движения

---

## Phase 1: Setup & Воспроизведение (Day 1-2)

### 1.1 Клонирование SwiftPM

```bash
cd ~/projects
git clone https://github.com/swiftlang/swift-package-manager.git
cd swift-package-manager

# Checkout версии 6.2.1 (проблемная)
git checkout swift-6.2.1-RELEASE

# Или main ветка если хотим latest
git checkout main
```

### 1.2 Сборка SwiftPM из исходников

```bash
# Сборка в debug режиме (с символами отладки)
swift build -c debug

# Проверка что собралось
ls -lh .build/debug/swift-*
# Ожидаем: swift-build, swift-package, swift-test и др.
```

**Expected time:** 5-10 минут первая сборка

### 1.3 Воспроизведение бага с локальной сборкой

```bash
# Создаём минимальный тестовый проект
cd /tmp
rm -rf spm-hang-test
mkdir spm-hang-test && cd spm-hang-test
swift package init --type executable

# ПЕРВАЯ сборка (должна пройти)
~/projects/swift-package-manager/.build/debug/swift-build

# ВТОРАЯ сборка (должна зависнуть!)
timeout 30 ~/projects/swift-package-manager/.build/debug/swift-build
# Ожидаем: timeout через 30 секунд
```

**✅ Checklist воспроизведения:**
- [ ] Clean build работает
- [ ] Incremental build зависает с локальной сборкой SwiftPM
- [ ] Баг воспроизводится стабильно (3 из 3 попыток)

### 1.4 Baseline с Swift 6.0

```bash
# Checkout версии 6.0 (working version)
cd ~/projects/swift-package-manager
git checkout swift-6.0-RELEASE
swift build -c debug

# Тест на том же проекте
cd /tmp/spm-hang-test
rm -rf .build
~/projects/swift-package-manager/.build/debug/swift-build  # clean
~/projects/swift-package-manager/.build/debug/swift-build  # incremental

# Ожидаем: incremental build НЕ зависает на 6.0
```

**📝 Результат Phase 1:**
- Документируем разницу в поведении 6.0 vs 6.2.1
- Подтверждаем что можем дебажить локальную сборку

---

## Phase 2: Добавление Logging (Day 2-3)

### 2.1 Понимание кодабазы

**Файлы для изучения:**
```
Sources/Build/
├── BuildPlan/           ← "Planning build" фаза
│   ├── BuildPlan.swift
│   └── ...
├── LLBuildManifest.swift
└── ...

Sources/PackageGraph/
├── DependencyResolver.swift
└── ...
```

**Поиск по коду:**
```bash
cd ~/projects/swift-package-manager

# Ищем "Planning build" строку
grep -r "Planning build" Sources/

# Ищем epoll/timer related код (может быть в llbuild)
grep -r "epoll\|timer\|async" Sources/ | grep -i build

# Ищем где вызывается build plan
grep -r "BuildPlan\|buildPlan" Sources/Build/
```

### 2.2 Добавление debug логов

**Цель:** Понять где именно зависает в "Planning build"

Пример модификации `Sources/Build/BuildPlan/BuildPlan.swift`:

```swift
public func create() async throws -> BuildPlan {
    print("🔍 DEBUG: BuildPlan.create() START")
    
    // Существующий код...
    print("🔍 DEBUG: Before dependency resolution")
    let graph = try await resolveDependencies()
    print("🔍 DEBUG: After dependency resolution")
    
    print("🔍 DEBUG: Before build plan generation")
    let plan = try generateBuildPlan(graph)
    print("🔍 DEBUG: After build plan generation")
    
    print("🔍 DEBUG: BuildPlan.create() END")
    return plan
}
```

**Стратегия логирования:**
1. Добавить лог в начало/конец каждой async функции
2. Логировать перед/после каждого await
3. Засечь где последний лог перед зависанием

### 2.3 Пересборка и тест

```bash
# Пересобрать SwiftPM с новыми логами
cd ~/projects/swift-package-manager
swift build -c debug

# Запустить с логами
cd /tmp/spm-hang-test
rm -rf .build
~/projects/swift-package-manager/.build/debug/swift-build  # clean
~/projects/swift-package-manager/.build/debug/swift-build  # incremental - смотрим логи!
```

**📝 Ожидаемый результат:**
```
🔍 DEBUG: BuildPlan.create() START
🔍 DEBUG: Before dependency resolution
🔍 DEBUG: After dependency resolution
🔍 DEBUG: Before build plan generation
[ЗАВИСАНИЕ - лог не появляется дальше]
```

---

## Phase 3: Детальная диагностика (Day 3-5)

### 3.1 Debugging с LLDB

```bash
# Запуск под LLDB
cd /tmp/spm-hang-test
rm -rf .build
~/projects/swift-package-manager/.build/debug/swift-build  # clean build

# Incremental build под отладчиком
lldb ~/projects/swift-package-manager/.build/debug/swift-build

# В lldb:
(lldb) run
# Ждём зависания...
# Ctrl+C когда зависнет

(lldb) bt  # backtrace - где зависло
(lldb) thread list  # все потоки
(lldb) thread backtrace all  # backtrace всех потоков
```

**Что искать:**
- Какой поток зависает?
- В какой функции?
- Ждёт ли await/continuation?
- Deadlock на semaphore/lock?

### 3.2 Сравнение с Swift 6.0

```bash
# Checkout 6.0, добавить те же логи
cd ~/projects/swift-package-manager
git checkout swift-6.0-RELEASE

# Добавить ТАКИЕ ЖЕ логи в те же места
# Пересобрать и запустить

# Сравнить вывод логов 6.0 vs 6.2.1
```

**Вопросы:**
- Проходит ли 6.0 через то же место где зависает 6.2?
- Есть ли разница в порядке вызовов?
- Какие коммиты между 6.0 и 6.2?

### 3.3 Git Bisect (если нужно)

```bash
cd ~/projects/swift-package-manager

# Бинарный поиск коммита который сломал
git bisect start
git bisect bad swift-6.2.1-RELEASE    # 6.2.1 - broken
git bisect good swift-6.0-RELEASE     # 6.0 - works

# Bisect будет checkout коммиты
# Для каждого:
swift build -c debug
cd /tmp/spm-hang-test && rm -rf .build
~/projects/swift-package-manager/.build/debug/swift-build  # test
# Если зависло: git bisect bad
# Если работает: git bisect good

# В конце покажет "first bad commit"
```

**Expected time:** 2-4 часа (если ~100 коммитов между версиями)

---

## Phase 4: Анализ Root Cause (Day 5-7)

### 4.1 Изучение проблемного кода

После Phase 3 мы знаем:
- [ ] Точную функцию где зависает
- [ ] Коммит который сломал (если делали bisect)
- [ ] Разницу в поведении 6.0 vs 6.2

**Типичные причины async зависаний:**
1. **Deadlock** — два await ждут друг друга
2. **Lost continuation** — continuation никогда не вызывается
3. **Event loop starvation** — epoll ждёт event который не придёт
4. **Race condition** — на KVM timing другой, выявляет race

### 4.2 Гипотезы для epoll_wait loop

**Гипотеза 1: File watching issue**
- SwiftPM использует file system watching для incremental builds
- На KVM inotify events могут приходить иначе
- Код ждёт событие которое не придёт

**Проверка:**
```swift
// Найти где используется file watching
grep -r "FileSystemWatcher\|inotify\|kqueue" Sources/
```

**Гипотеза 2: Timer issue**
- `timerfd_settime` в strace
- Возможно timeout logic сломан
- На KVM виртуализация времени иная

**Проверка:**
```swift
// Искать timer/timeout код
grep -r "Timer\|timeout\|deadline" Sources/Build/
```

**Гипотеза 3: llbuild integration**
- SwiftPM использует llbuild для actual building
- Проблема может быть в llbuild, не SwiftPM
- Нужно смотреть https://github.com/swiftlang/swift-llbuild

**Проверка:**
```bash
# Клонировать llbuild отдельно
git clone https://github.com/swiftlang/swift-llbuild.git
# Изучить как SwiftPM его использует
```

### 4.3 Создание minimal reproducible test

**Цель:** Изолировать проблему в юнит-тест

```swift
// Tests/BuildTests/IncrementalBuildTests.swift (пример)

func testIncrementalBuildOnKVM() async throws {
    // Setup minimal project
    let fs = InMemoryFileSystem()
    // ... setup code ...
    
    // First build - should succeed
    try await build(plan)
    
    // Second build WITHOUT changes - should NOT hang
    try await build(plan)  // ← будет зависать на KVM
}
```

---

## Phase 5: Fix & Testing (Day 7-10)

### 5.1 Разработка фикса

**На основе найденной причины:**

**Пример 1: Timeout issue**
```swift
// Было:
await withTimeout(seconds: 5) { ... }  // зависает на KVM

// Фикс:
await withTimeout(seconds: 5) { ... }
    .catchTimeout {
        // Fallback если timeout не сработал
        logger.warning("Timeout fallback triggered")
        return defaultValue
    }
```

**Пример 2: File watching**
```swift
// Было:
await fileWatcher.waitForChanges()  // бесконечно ждёт

// Фикс:
await fileWatcher.waitForChanges(timeout: .seconds(1))
    .orElse {
        // Если за 1 сек нет изменений, считаем что всё ОК
        return .noChanges
    }
```

### 5.2 Локальное тестирование

```bash
# Пересобрать с фиксом
cd ~/projects/swift-package-manager
swift build -c debug

# Тест на нашем минимальном проекте
cd /tmp/spm-hang-test
rm -rf .build
~/projects/swift-package-manager/.build/debug/swift-build  # clean
~/projects/swift-package-manager/.build/debug/swift-build  # incremental

# Ожидаем: incremental build НЕ зависает!
```

### 5.3 Запуск SwiftPM test suite

```bash
cd ~/projects/swift-package-manager

# Запуск всех тестов
swift test

# Или конкретные build-related тесты
swift test --filter BuildTests
swift test --filter IncrementalBuildTests
```

**Важно:** Все тесты должны проходить ✅

### 5.4 Тест на нашем реальном проекте

```bash
# Тест на tg-client проекте
cd ~/tg-client
rm -rf .build

# Использовать нашу исправленную сборку SwiftPM
~/projects/swift-package-manager/.build/debug/swift-build
~/projects/swift-package-manager/.build/debug/swift-build  # incremental

# Ожидаем: работает!
```

---

## Phase 6: Pull Request (Day 10-14)

### 6.1 Подготовка PR

**Структура коммитов:**
```bash
# Один чистый коммит с фиксом
git checkout -b fix/incremental-build-hang-kvm

# Коммит
git add Sources/Build/...
git commit -m "Fix incremental build hang on KVM/virtualized environments

- Issue: Incremental builds hang at 'Planning build' on KVM
- Root cause: [описание найденной причины]
- Fix: [описание решения]
- Tested on: Ubuntu 24.04, Kernel 6.11, KVM

Fixes swiftlang/swift-package-manager#9441"
```

### 6.2 Написание PR description

```markdown
## Summary

Fixes incremental build hang on KVM virtualized environments.

## Problem

On KVM-based virtual machines (VDS/VPS), SwiftPM 6.2+ hangs indefinitely 
during incremental builds at the "Planning build" phase.

**Symptoms:**
- Clean builds work fine
- Incremental builds (no code changes) hang forever
- strace shows `epoll_wait`/`timerfd_settime` loop
- Issue does NOT occur on Swift 6.0

**Environment:**
- Ubuntu 24.04, Kernel 6.11
- KVM virtualization
- Minimal reproducible test case included

## Root Cause

[Детальное описание найденной причины]

## Solution

[Описание фикса]

## Testing

- [x] Verified fix on KVM environment (original report)
- [x] Verified fix on minimal test project
- [x] All existing tests pass
- [x] Added regression test

## Related Issues

- #9441
- Forums: https://forums.swift.org/t/83562

## Checklist

- [x] Code follows Swift API Design Guidelines
- [x] Added tests covering the fix
- [x] All tests pass locally
- [x] Updated CHANGELOG.md (if applicable)
```

### 6.3 Создание PR

```bash
# Push ветки
git push origin fix/incremental-build-hang-kvm

# Создать PR через GitHub UI
# Или через gh CLI:
gh pr create \
  --title "Fix incremental build hang on KVM/virtualized environments" \
  --body-file pr-description.md
```

### 6.4 Code Review процесс

**Ожидания:**
- Мейнтейнеры попросят изменения (это нормально!)
- Возможно попросят больше тестов
- Возможно попросят другой подход к фиксу

**Наши действия:**
- Быстро отвечать на комментарии
- Делать requested changes
- Объяснять reasoning за наш подход

---

## Phase 7: Документация для портфолио (Day 14+)

### 7.1 Написание blog post / case study

**Структура:**
```markdown
# Debugging SwiftPM: Fixing Incremental Build Hang on KVM

## The Problem
[Описание issue, как обнаружили]

## Investigation Process
[Что делали в Phase 1-4, находки]

## Root Cause Analysis
[Детальный анализ причины]

## The Fix
[Код фикса с объяснением]

## Impact
- Contribution to official Apple/Swift project
- Helps developers on virtualized environments
- Deep dive into async/await event loops

## Skills Demonstrated
- Low-level debugging (lldb, strace)
- Open source contribution process
- Swift async/await internals
- Linux kernel interaction (epoll, timers)
```

### 7.2 Дополнительно для портфолио

**GitHub Gist:**
- Детальный strace analysis
- Comparison 6.0 vs 6.2 behavior
- Minimal reproducible test case

**Presentation/Talk:**
- Можно сделать доклад на Swift meetup
- Тема: "Debugging Production Issues in SwiftPM"

---

## Resources & Links

### Documentation
- [SwiftPM Contributing Guide](https://github.com/swiftlang/swift-package-manager/blob/main/CONTRIBUTING.md)
- [Swift Forums](https://forums.swift.org/)
- [Swift Evolution](https://github.com/swiftlang/swift-evolution)

### Related Repos
- [swift-package-manager](https://github.com/swiftlang/swift-package-manager)
- [swift-llbuild](https://github.com/swiftlang/swift-llbuild)
- [swift-build](https://github.com/swiftlang/swift-build)

### Our Investigation
- Issue: https://github.com/swiftlang/swift-package-manager/issues/9441
- Forums: https://forums.swift.org/t/83562
- Diagnostics: `~/swiftpm-kernel-6.11-final/`

### Useful Commands Reference

```bash
# Build SwiftPM from source
swift build -c debug

# Run with custom SwiftPM
/path/to/spm/.build/debug/swift-build

# Debug with LLDB
lldb /path/to/spm/.build/debug/swift-build

# Git bisect
git bisect start
git bisect bad <bad-commit>
git bisect good <good-commit>

# Test suite
swift test
swift test --filter TestName
```

---

## Success Metrics

**Minimum Success:**
- [ ] Воспроизвели баг с локальной сборкой SwiftPM
- [ ] Нашли точное место зависания
- [ ] Documented findings в GitHub issue

**Good Success:**
- [ ] Нашли root cause
- [ ] Создали фикс (хотя бы workaround)
- [ ] Открыли PR

**Great Success:**
- [ ] PR merged в SwiftPM
- [ ] Упоминание в release notes
- [ ] Case study для портфолио

---

## Timeline Estimate

**Оптимистичный:** 7-10 дней  
**Реалистичный:** 14-21 день  
**С учётом review:** 21-30 дней до merge

**Time commitment:** ~2-3 часа в день

---

## Notes & Observations

_(Заполнять по ходу работы)_

### Day 1:
- 

### Day 2:
- 

### Findings:
- 

### Questions for community:
- 

---

**Created:** 2025-12-08  
**Last Updated:** 2025-12-08  
**Status:** 🟡 Waiting for hosting/maintainer response (Phase 0)

---

## Pre-Investigation: Dependency Analysis

### Quick Check: llbuild версии

```bash
# Проверить какая версия llbuild используется в Swift 6.0 vs 6.2.1

# Swift 6.0
cd ~/swift-6.0-source  # если есть исходники
# или проверить бинарник
otool -L /usr/share/swift-6.0-backup/usr/bin/swift-build | grep llbuild

# Swift 6.2.1
otool -L /usr/share/swift/usr/bin/swift-build | grep llbuild

# На Linux (ldd вместо otool)
ldd /usr/share/swift-6.0-backup/usr/bin/swift-build | grep llbuild
ldd /usr/share/swift/usr/bin/swift-build | grep llbuild
```

### Альтернатива: посмотреть в Package.resolved

SwiftPM сам является Swift Package и имеет Package.resolved с версиями зависимостей.

```bash
# Клонируем репу с двумя версиями
cd /tmp
git clone https://github.com/swiftlang/swift-package-manager.git spm-6.0
git clone https://github.com/swiftlang/swift-package-manager.git spm-6.2

# Checkout разных версий
cd spm-6.0 && git checkout swift-6.0-RELEASE
cd ../spm-6.2 && git checkout swift-6.2.1-RELEASE

# Сравниваем Package.resolved
diff spm-6.0/Package.resolved spm-6.2/Package.resolved
```

**Если llbuild версия изменилась →** Проблема скорее всего в llbuild, не в SwiftPM!  
**Если llbuild версия та же →** Проблема в коде SwiftPM

### Быстрая проверка коммитов между версиями

```bash
cd /tmp/spm-6.2
git log --oneline swift-6.0-RELEASE..swift-6.2.1-RELEASE | wc -l
# Показывает сколько коммитов между версиями

# Посмотреть коммиты связанные с async/await или build planning
git log --oneline --grep="async\|await\|build\|plan" swift-6.0-RELEASE..swift-6.2.1-RELEASE

# Коммиты связанные с llbuild integration
git log --oneline --grep="llbuild" swift-6.0-RELEASE..swift-6.2.1-RELEASE
```

**Результат:** Если нашли подозрительный коммит — сразу начинаем с него!


## 🎯 Quick Findings (2025-12-08)

### Dependency Changes между 6.0 и 6.2.1:

**Ключевые изменения:**
1. **llbuild** - остался на `branch: relatedDependenciesBranch` (нужно проверить какой конкретно commit)
2. **swift-argument-parser**: `1.2.2` → `1.5.1` ⬆️ (major bump)
3. **swift-tools-support-core** - УДАЛЁН из 6.2.1! 🔴
4. **swift-driver** - переместили в conditional dependencies
5. **NEW в 6.2.1:**
   - `swift-build` (новая зависимость!)
   - `swift-toolchain-sqlite` (новая зависимость!)
   - `swift-docc-plugin` (новая зависимость!)

### 🚨 Критичная находка: `swift-build`

В Swift 6.2.1 появилась НОВАЯ зависимость — **`swift-build`**!

Это может быть root cause:
- Раньше build logic была в SwiftPM напрямую
- Теперь вынесли в отдельный пакет `swift-build`
- Возможно там async/await рефакторинг который сломал KVM

**Action item для Phase 1:**
```bash
# Проверить swift-build репозиторий
git clone https://github.com/swiftlang/swift-build.git
cd swift-build

# Посмотреть когда он появился и какие есть коммиты
git log --oneline | head -20

# Искать async/await и epoll related код
grep -r "epoll\|async\|await" Sources/
```

### Hypothesis Update:

**Вероятность что проблема в:**
- ✅ **swift-build** (новая зависимость) - 60%
- ⚠️ llbuild (если версия изменилась) - 25%
- ⚠️ SwiftPM код напрямую - 15%

**Next step:** Сначала изучить `swift-build` repo в Phase 1!

