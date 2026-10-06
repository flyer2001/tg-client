# tg-client

![Status](https://img.shields.io/badge/status-alpha-orange)
![Version](https://img.shields.io/badge/version-v0.5.0--alpha-blue)
![Swift](https://img.shields.io/badge/swift-6.0+-orange.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)

CLI-клиент Telegram для получения саммари непрочитанных сообщений через AI.

## 🎯 Описание

TgClient автоматизирует просмотр большого количества Telegram каналов:
- Авторизуется в Telegram через TDLib
- Получает список непрочитанных сообщений
- Генерирует краткое саммари через AI (OpenAI)
- Автоматически помечает прочитанными обработанные чаты
- **VK Bridge (v0.5.0):** управление Telegram через личное VK-сообщество, когда сам Telegram недоступен —
  список непрочитанных, чтение чатов, ответы и пометка прочитанным командами в VK

## 🚀 Быстрый старт

```bash
# Клонировать репозиторий
git clone https://github.com/flyer2001/tg-client.git
cd tg-client

# Установить TDLib (см. раздел "Установка TDLib" ниже)

# Настроить переменные окружения
cp .env.example .env
# Отредактировать .env файл:
# - OPENAI_API_KEY (обязательно) - получить на https://platform.openai.com/api-keys
# - TELEGRAM_API_ID, TELEGRAM_API_HASH - получить на https://my.telegram.org/apps

# Собрать проект (на Linux используй скрипт для избежания проблем с зависанием SwiftPM)
./scripts/build-clean.sh

# Запустить тесты
swift test

# Запустить приложение
swift run tg-client
```
## 📋 Требования

- Swift 6.0+
- TDLib 1.8.6+
- macOS 14+ или Linux (Ubuntu 24.04+)
- SwiftLint (опционально, для проверки качества кода)

## 📦 Установка TDLib

**TDLib** — обязательная зависимость для работы проекта. Без неё сборка провалится.

<details>
<summary><b>macOS (Homebrew)</b></summary>

```bash
# Установка через Homebrew
brew install tdlib pkg-config swiftlint

# Настройка PKG_CONFIG_PATH (добавь в ~/.zshrc для постоянной настройки)
export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"
```

</details>

<details>
<summary><b>Linux (Ubuntu 24.04+) — сборка из исходников</b></summary>

⚠️ **Внимание:** Готовых пакетов TDLib для Ubuntu 24.04 нет. Требуется сборка из исходников (~20-40 минут).

```bash
# Установка зависимостей
sudo apt update
sudo apt install -y build-essential cmake gperf libssl-dev zlib1g-dev pkg-config git

# Клонирование и сборка TDLib
git clone https://github.com/tdlib/td.git ~/td
cd ~/td
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
cmake --build . -j$(nproc)
sudo cmake --install .

# Обновление кэша динамических библиотек
sudo ldconfig
```

💡 **Рекомендация:** Используйте `tmux` для запуска сборки, чтобы процесс не прервался при обрыве SSH-соединения.

</details>

**Официальная документация:**
- [TDLib GitHub](https://github.com/tdlib/td)
- [TDLib Build Instructions](https://tdlib.github.io/td/build.html)

## 📱 VK Bridge — управление через VK-сообщество

Когда мобильный интернет блокирует Telegram, а VK работает, — пишешь команды своему VK-сообществу,
сервис выполняет их в Telegram и отвечает в тот же диалог. Транспорт — **VK Bots Long Poll**:
сервис сам держит исходящий запрос к VK, поэтому **не нужны домен, HTTPS, nginx и открытый порт**
(запускается хоть на домашнем ноутбуке за NAT).

### 1. Создать сообщество

1. vk.com → «Сообщества» → «Создать сообщество» (тип любой, лучше частное — оно только для тебя)
2. Управление → **Сообщения** → включить «Сообщения сообщества»
3. Там же «Настройки для бота» → включить **«Возможности ботов»**
4. Управление → **Работа с API → Long Poll API** → «Включено», версия **5.199**;
   вкладка «Типы событий» → отметить **«Входящие сообщения»**
5. **Работа с API → Ключи доступа → Создать ключ** с правами:
   - «Управление сообществом» — без него VK не выдаёт адрес Long Poll сервера
   - «Сообщения сообщества»
6. ID сообщества — число из адреса `vk.com/club123456789`
7. **Напиши сообществу любое сообщение** со своего аккаунта — иначе VK не даст боту тебе ответить

> ⚠️ Ключ сообщества = полный доступ к его сообщениям. Только в `.env` (он в `.gitignore`), никогда в git и чаты.
> Утёк — удали ключ в «Ключи доступа» и создай новый.

### 2. Настроить `.env`

```bash
VK_BOT_TOKEN=vk1.a....            # ключ сообщества (шаг 5)
VK_BOT_GROUP_ID=123456789         # id сообщества (шаг 6)
VK_BOT_OWNER_IDS=111111,222222    # твой VK id (и других доверенных) — остальных бот игнорирует
VK_API_VERSION=5.199              # опционально
```

### 3. Запустить

```bash
swift run tg-client               # один раз интерактивно — авторизация в Telegram (сессия сохранится)
swift run tg-client service       # сервис: слушает VK, выполняет команды; Ctrl+C — остановка
```

Для постоянной работы — systemd (пример):

```ini
[Service]
ExecStart=/opt/tg-client/tg-client service
EnvironmentFile=/etc/tg-client.env
Restart=on-failure
```

### Команды

| Команда | Что делает |
|---|---|
| `/test` | статус сервиса |
| `/digest` | меню непрочитанных: каналы, группы, ЛС с номерами (архив не попадает) |
| `/get N`, `/get all`, `/get channels\|groups\|dm` | текст непрочитанных выбранных чатов |
| `/last N [count]` | последние `count` сообщений чата (включая прочитанные) |
| `/reply N текст` | ответить в чат N от своего имени |
| `/to username текст` | написать любому по @username |
| `/read N` | пометить чат N прочитанным |

Сценарий целиком — [VK Bridge в документации](https://flyer2001.github.io/tg-client/documentation/tgclient/vkbridge).

## 📖 Документация

**Полная документация доступна онлайн:**
👉 [https://flyer2001.github.io/tg-client/documentation/tgclient](https://flyer2001.github.io/tg-client/documentation/tgclient)

## ⚠️ Статус проекта

**В активной разработке** — проект не готов к production использованию.

### Что работает в v0.5.0:
- ✅ VK Bridge через VK Bots Long Poll: `/digest`, `/get`, `/last`, `/reply`, `/to`, `/read`, `/test`
- ✅ Автоматическое переподключение к VK (ошибки Long Poll `failed:1/2/3`, повтор при обрыве сети)
- ✅ Выгрузка истории чата в JSONL (`tg-client dump @username`) и отправка документа чанками (`tg-client send`)

### Что работает в v0.4.0:
- ✅ Авторизация в Telegram (phone + code + 2FA)
- ✅ Получение списка чатов и непрочитанных сообщений
- ✅ Фильтрация заархивированных чатов и пользовательских папок
- ✅ Чтение истории сообщений из каналов (включая медиа с подписями)
- ✅ AI саммаризация через OpenAI GPT-4 с автоматическим retry
- ✅ Автоматическая отметка прочитанных после генерации дайджеста

## 📄 Лицензия

[MIT License](LICENSE) - свободное использование, модификация и распространение.
