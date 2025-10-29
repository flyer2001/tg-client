# Стратегия тестирования

> 📋 **Обновлено:** 2025-10-28

## ⚠️ Неснимаемое правило

**Все тесты пишутся ТОЛЬКО на Swift Testing фреймворке (НЕ XCTest).**

**Документация:** https://developer.apple.com/documentation/testing

---

## Уровни тестирования

### Unit-тесты
- Изолированное тестирование функций/классов
- Моки для всех зависимостей
- Быстрые, детерминированные
- Примеры: TDLibRequestEncoder, TDLibUpdate, модели

### Component-тесты
- Тестирование модулей с реальными зависимостями
- Без внешней сети
- Моки только для C API и сетевых вызовов
- Примеры: TDLibClient (с мок TDLib), авторизация

### E2E-тесты
- Интеграционные тесты с реальным TDLib
- Требуют credentials
- Медленные, опционально в CI
- Примеры: полный цикл авторизации

## TDD Workflow

RED → GREEN → REFACTOR

## Coverage Requirements

Минимальный coverage для PR: **TODO**

## Инфраструктура

- Swift Testing framework (Swift 6)
- CI интеграция
- Coverage отчёты

---

**См. также:**
- [TASKS.md](TASKS.md) - задача 5.1
- [CONTRIBUTING.md](CONTRIBUTING.md) - правила разработки
