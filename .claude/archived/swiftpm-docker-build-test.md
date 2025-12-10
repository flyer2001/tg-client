# SwiftPM Fix Testing: Docker Build on macOS

**Цель:** Собрать SwiftPM с фиксом (убрать `unsafe_await`) в Docker и протестировать на KVM сервере

**Контекст:**
- Issue: https://github.com/swiftlang/swift-package-manager/issues/9441
- Проблемный коммит: 43ca6aa3f (PR #7851)
- Файл: `Sources/Build/LLBuildCommands.swift:429` (в версии 6.2.2)
- Проблема: `unsafe_await` вызывает deadlock на incremental builds на KVM
- Версия: Swift 6.2.2 (последняя релизная, 4 декабря 2025) - проблема НЕ исправлена
- KVM сервер: root@45.8.145.191

---

## Phase 1: Подготовка на macOS

### 1.1 Проверка Docker Desktop

```bash
# Проверить что Docker запущен
docker --version
# Ожидается: Docker version 20.x или выше

# Проверить доступную память для Docker
# Docker Desktop → Settings → Resources → Memory
# Нужно минимум 6GB
```

### 1.2 Создание рабочей директории

```bash
mkdir -p ~/swiftpm-fix-test
cd ~/swiftpm-fix-test
```

---

## Phase 2: Сборка SwiftPM с фиксом в Docker

### 2.1 Запуск Linux контейнера (Ubuntu 22.04, Swift 6.2.2)

```bash
# Запустить интерактивный контейнер
docker run -it --rm \
  --name swiftpm-build \
  --memory=6g \
  --cpus=4 \
  -v "$(pwd):/work" \
  swift:6.2-jammy \
  bash

# Вы окажетесь ВНУТРИ Linux контейнера
# Prompt изменится на: root@<container-id>:/#
```

### 2.2 Установка зависимостей (внутри контейнера)

```bash
# Обновить пакеты
apt-get update

# Установить необходимые библиотеки
apt-get install -y \
  libsqlite3-dev \
  git \
  vim

# Проверить версию Swift
swift --version
# Ожидается: Swift version 6.2.2
```

### 2.3 Клонирование SwiftPM (внутри контейнера)

```bash
cd /work

# Клонировать SwiftPM (Swift 6.2.2 branch - последняя релизная версия)
git clone --depth 1 --branch swift-6.2.2-RELEASE \
  https://github.com/swiftlang/swift-package-manager.git

cd swift-package-manager

# Проверить что на правильной версии
git log --oneline -1
# Должен быть коммит: 6c6c1e5 (Swift 6.2.2 RELEASE)
```

### 2.4 Применение фикса (внутри контейнера)

```bash
# Открыть файл для редактирования
vim Sources/Build/LLBuildCommands.swift

# Найти строку 429 (поиск в vim: /unsafe_await)
# Найти функцию PackageStructureCommand.execute

# БЫЛО (строки 429-431):
#     unsafe_await {
#         await self.context.packageStructureDelegate.packageStructureChanged()
#     }

# ДОЛЖНО СТАТЬ (убрать unsafe_await):
#     self.context.packageStructureDelegate.packageStructureChanged()

# Сохранить: :wq
```

**Точное изменение:**

```diff
override func execute(
    _: SPMLLBuild.Command,
    _: SPMLLBuild.BuildSystemCommandInterface
) -> Bool {
-    unsafe_await {
-        await self.context.packageStructureDelegate.packageStructureChanged()
-    }
+    self.context.packageStructureDelegate.packageStructureChanged()
}
```

### 2.5 Сборка SwiftPM с фиксом (внутри контейнера)

```bash
# Запустить сборку (займёт 30-60 минут)
swift build -c debug -j 2 2>&1 | tee /work/build.log

# Флаги:
# -c debug: debug build (быстрее собирается)
# -j 2: использовать 2 потока (чтобы не перегрузить)
# 2>&1: перенаправить stderr в stdout
# | tee: записать лог И показать на экране

# ВАЖНО: Не закрывать терминал во время сборки!
# Можно открыть новый терминал и следить за прогрессом:
# tail -f ~/swiftpm-fix-test/build.log
```

### 2.6 Проверка успешности сборки (внутри контейнера)

```bash
# Проверить что бинарник создался
ls -lh .build/debug/swift-build

# Ожидается:
# -rwxr-xr-x 1 root root 50M ... .build/debug/swift-build

# Если файл есть - сборка успешна! ✅
```

### 2.7 Выход из контейнера

```bash
# Выйти из контейнера
exit

# Вы окажетесь обратно на macOS
# Проверить что бинарник доступен на macOS:
ls -lh ~/swiftpm-fix-test/swift-package-manager/.build/debug/swift-build
```

---

## Phase 3: Перенос на KVM сервер

### 3.1 Копирование бинарника на сервер (на macOS)

```bash
# С вашей macOS машины
cd ~/swiftpm-fix-test/swift-package-manager

# Скопировать исправленный swift-build на сервер
scp .build/debug/swift-build root@45.8.145.191:/tmp/swift-build-fixed

# Проверить что скопировалось
ssh root@45.8.145.191 "ls -lh /tmp/swift-build-fixed"
```

---

## Phase 4: Тестирование на KVM сервере

### 4.1 Подключение к серверу

```bash
# С macOS
ssh root@45.8.145.191
```

### 4.2 Создание чистого тестового проекта (на сервере)

```bash
# Удалить старые тесты
rm -rf /tmp/incremental-build-test

# Создать новый чистый проект
mkdir /tmp/incremental-build-test
cd /tmp/incremental-build-test

# Инициализировать hello world
swift package init --type executable --name IncrementalTest

# Проверить что создалось
ls -la
# Должно быть: Package.swift, Sources/, .gitignore
```

### 4.3 Тест 1: Clean build с ОРИГИНАЛЬНЫМ swift-build (на сервере)

```bash
cd /tmp/incremental-build-test

# Использовать системный swift build
swift build

# Ожидается: сборка завершится успешно (~10-15 секунд)
# ✅ Clean build работает
```

### 4.4 Тест 2: Incremental build с ОРИГИНАЛЬНЫМ - должен зависнуть (на сервере)

```bash
cd /tmp/incremental-build-test

# Запустить incremental build (без изменений кода)
timeout 30 swift build

# Ожидается: TIMEOUT через 30 секунд
# ❌ Incremental build зависает - подтверждаем баг
```

### 4.5 Очистка перед тестом фикса (на сервере)

```bash
cd /tmp/incremental-build-test

# Удалить .build директорию
rm -rf .build

# Проверить что удалилось
ls -la .build
# Должно быть: No such file or directory
```

### 4.6 Тест 3: Clean build с ИСПРАВЛЕННЫМ swift-build (на сервере)

```bash
cd /tmp/incremental-build-test

# Использовать наш исправленный бинарник
/tmp/swift-build-fixed

# Ожидается: сборка завершится успешно (~10-15 секунд)
# ✅ Clean build работает с фиксом
```

### 4.7 Тест 4: Incremental build с ИСПРАВЛЕННЫМ - НЕ должен зависнуть! (на сервере)

```bash
cd /tmp/incremental-build-test

# Добавить пустую структуру (чтобы симулировать изменение)
cat >> Sources/IncrementalTest/IncrementalTest.swift << 'EOF'

struct MyEmptyStruct {
}
EOF

# Запустить incremental build с нашим фиксом
time /tmp/swift-build-fixed

# КРИТИЧНЫЙ МОМЕНТ:
# ✅ Если завершится за ~5-10 секунд - ФИКс РАБОТАЕТ! 🎉
# ❌ Если зависнет - фикс НЕ помог, проблема глубже
```

### 4.8 Тест 5: Повторный incremental build (финальная проверка)

```bash
cd /tmp/incremental-build-test

# Запустить ещё раз БЕЗ изменений кода
time /tmp/swift-build-fixed

# Ожидается: завершится за ~2-5 секунд (ничего не компилируется)
# ✅ Incremental builds стабильны с фиксом
```

---

## Phase 5: Документирование результатов

### 5.1 Сохранение логов (на сервере)

```bash
# Если фикс сработал - сохранить доказательства
cat > /tmp/fix-test-results.txt << 'EOF'
=== SwiftPM Fix Test Results ===
Date: $(date)
Server: root@45.8.145.191
Swift Version: $(swift --version | head -1)

Test 1: Clean build (original) - PASSED ✅
Test 2: Incremental build (original) - HANG ❌ (timeout 30s)
Test 3: Clean build (fixed) - PASSED ✅
Test 4: Incremental build (fixed) - PASSED ✅ (completed in Xs)
Test 5: Repeat incremental (fixed) - PASSED ✅ (completed in Xs)

Conclusion: Removing unsafe_await FIXES the incremental build hang!
EOF

cat /tmp/fix-test-results.txt
```

### 5.2 Скопировать результаты на macOS

```bash
# С macOS
scp root@45.8.145.191:/tmp/fix-test-results.txt ~/swiftpm-fix-test/
```

---

## Phase 6: Подготовка комментария для GitHub

### На основе результатов:

**Если фикс СРАБОТАЛ ✅:**

```markdown
**Root cause confirmed + fix verified**

I've confirmed the root cause and successfully tested a fix!

### The Issue
**File:** `Sources/Build/LLBuildCommands.swift:429` (Swift 6.2.2)
**Problem:** `unsafe_await` wrapper causes deadlock on incremental builds

### The Fix
Simply remove the `unsafe_await` wrapper:

```diff
override func execute(...) -> Bool {
-    unsafe_await {
-        await self.context.packageStructureDelegate.packageStructureChanged()
-    }
+    self.context.packageStructureDelegate.packageStructureChanged()
}
```

### Test Results (KVM Ubuntu 24.04)
- ✅ Original: Clean builds work
- ❌ Original: Incremental builds hang (30+ seconds)
- ✅ Fixed: Clean builds work
- ✅ Fixed: Incremental builds work (~5 seconds)
- ✅ Fixed: Repeat incremental builds work (~2 seconds)

The fix compiles successfully and resolves the deadlock. Would you like me to open a PR?

**Build logs:** [attach if needed]
```

**Если фикс НЕ СРАБОТАЛ ❌:**

```markdown
**Update: Partial investigation results**

I attempted to verify my hypothesis by removing the `unsafe_await` wrapper, but the issue persists.

### What I tested
Removed `unsafe_await` from `LLBuildCommands.swift:425` and rebuilt SwiftPM.

### Results
- ✅ Clean builds: still work
- ❌ Incremental builds: still hang

This suggests the problem is deeper than just the `unsafe_await` wrapper. The root cause might be in:
1. The async conversion of `packageStructureChanged()` itself
2. The interaction between llbuild's BuildEngine and Swift concurrency
3. Threading behavior specific to KVM environments

I'll continue investigating. Any pointers would be appreciated!
```

---

## Troubleshooting

### Docker сборка не запускается:
```bash
# Увеличить память в Docker Desktop
# Settings → Resources → Memory → 8GB
```

### Сборка падает с OOM:
```bash
# Уменьшить параллелизм
swift build -c debug -j 1
```

### vim не работает в контейнере:
```bash
# Использовать nano вместо vim
apt-get install -y nano
nano Sources/Build/LLBuildCommands.swift
```

### Бинарник не запускается на сервере:
```bash
# Проверить что это Linux бинарник
file /tmp/swift-build-fixed
# Должно быть: ELF 64-bit LSB executable, x86-64

# Добавить execute права
chmod +x /tmp/swift-build-fixed
```

---

## Success Criteria

**Minimum Success:**
- [ ] SwiftPM собрался в Docker
- [ ] Бинарник перенесён на сервер
- [ ] Incremental build протестирован

**Full Success:**
- [ ] Incremental build работает с фиксом ✅
- [ ] Можем подтвердить что убрать `unsafe_await` - это решение
- [ ] Готовы открыть PR с фиксом

---

## Estimated Time

- Docker сборка: 30-60 минут
- Тестирование: 10-15 минут
- Документирование: 5-10 минут

**Total:** ~1-1.5 часа

---

## Files Generated

- `~/swiftpm-fix-test/build.log` - лог сборки
- `~/swiftpm-fix-test/fix-test-results.txt` - результаты тестов
- `/tmp/swift-build-fixed` - исправленный бинарник (на сервере)

---

**Created:** 2025-12-09
**Updated:** 2025-12-09 (изменено на Swift 6.2.2)
**Swift Version:** 6.2.2 (последняя релизная, проблема НЕ исправлена)
**For Issue:** https://github.com/swiftlang/swift-package-manager/issues/9441
**Server:** root@45.8.145.191
