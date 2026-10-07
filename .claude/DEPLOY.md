# Развёртывание и настройка

> Актуально на v0.5.0 (2026-10-07). Отдельного «прод-сервера» нет: сервис живёт на домашней Linux-машине,
> выход в Telegram — через прокси на VDS. Репозиторий публичный — IP, порты и пароли здесь не пишем.

## Топология

```
VK-сообщество ──Long Poll──► tg-client service (ubuntu-home, systemd)
                                   │ TDLib
                                   ▼
                         TDLIB_PROXY (tinyproxy на VDS, HTTP CONNECT)
                                   ▼
                         дата-центры Telegram
```

- **ubuntu-home** (Ubuntu 24.04, домашняя сеть в РФ): сервис `tg-client`, сессия TDLib, сборка и тесты.
  Telegram напрямую отсюда **недоступен** (DC на :443 не отвечают) — поэтому `TDLIB_PROXY`. VK доступен.
- **VDS (ufohosting)**: tinyproxy с BasicAuth — выход в Telegram; git и работа агента. Сборки тут не гоняем (2 ядра / 4 ГБ).
- ubuntu-home — dual-boot с Windows: пока загружена Windows, мост недоступен; после загрузки Ubuntu сервис стартует сам.

## Переменные окружения

Шаблон — `.env.example`. На машине сервиса `.env` лежит в рабочей папке (`chmod 600`, в `.gitignore`):

| Переменная | Зачем |
|---|---|
| `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` | https://my.telegram.org/apps |
| `TDLIB_STATE_DIR` | сессия TDLib (`$HOME/.tdlib` — приложение само раскрывает `$HOME`) |
| `TDLIB_DATABASE_ENCRYPTION_KEY` | шифрование локальной БД TDLib |
| `TDLIB_PROXY` | `http://user:pass@host:port` или `socks5://…` — если Telegram недоступен напрямую |
| `VK_BOT_TOKEN`, `VK_BOT_GROUP_ID`, `VK_BOT_OWNER_IDS` | VK Bridge (см. README → «VK Bridge») |

Приложение читает `.env` из текущей папки само и **не перезатирает** уже заданные переменные.
Поэтому в systemd — `WorkingDirectory`, а не `EnvironmentFile` (иначе `$HOME` в путях не раскроется).

## Сборка

**Тулчейн:** Swift 6.4 (`/opt/swift-6.4.0` на ubuntu-home), TDLib из master — сейчас **1.8.67** (`42e6a5259`).

```bash
swift build --build-tests && swift test           # разработка (если линковка странная — rm -rf .build, см. TROUBLESHOOTING)
./scripts/build-release-linux.sh                  # release со статически вшитым Swift (~73 МБ)
```

Release-бинарь не требует Swift на целевой машине — нужны системные библиотеки Ubuntu 24.04 и `libtdjson`
**той же версии**, что при сборке (рядом + `LD_LIBRARY_PATH`, или в `/usr/local/lib`). Проверено: собран на
ubuntu-home (Swift 6.4), запускается на VDS (Swift 6.3.2).

### TDLib

```bash
sudo apt install -y build-essential cmake gperf libssl-dev zlib1g-dev pkg-config git
git clone https://github.com/tdlib/td.git && cd td && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
cmake --build . -j$(nproc) && sudo cmake --install . && sudo ldconfig
```

`--target tdjson` быстрее, но тогда `cmake --install` падает (нужны все таргеты) — собирайте целиком.

**Политика обновления TDLib:** коммит сборки фиксируем здесь; обновлять раз в квартал или сразу, если Telegram
отвечает ошибкой версии. Перед переносом бинаря на другую машину — та же версия `libtdjson`
(сейчас на VDS системная 1.8.66, рядом с бинарём в `/opt/tg-client` — 1.8.67).
⚠️ В свежих TDLib меняются сигнатуры (пример: `addProxy` в 1.8.67 принимает вложенный `proxy`) — Research-First по схеме
`td/generate/scheme/td_api.tl`.

## Первый вход в Telegram

Интерактивно, один раз, в безвредном режиме (обычный запуск без аргументов прогоняет сценарий v0.4.0 и **помечает каналы прочитанными**):

```bash
cd ~/tg-client
/opt/tg-client/tg-client dump @telegram /tmp/login.jsonl   # телефон → код → облачный пароль; сессия → TDLIB_STATE_DIR
```

Telegram пришлёт «вход с нового устройства» — локация будет по IP прокси.

## Сервис (systemd)

```ini
# /etc/systemd/system/tg-client.service
[Unit]
Description=tg-client VK Bridge (VK Long Poll -> Telegram via TDLib)
After=network-online.target
Wants=network-online.target

[Service]
User=<user>
WorkingDirectory=/home/<user>/tg-client      # здесь .env
ExecStart=/opt/tg-client/tg-client service
Restart=on-failure
RestartSec=30
TimeoutStopSec=15

[Install]
WantedBy=multi-user.target
```

```bash
sudo install -m 755 "$(swift build -c release --show-bin-path)/tg-client" /opt/tg-client/tg-client
sudo systemctl daemon-reload && sudo systemctl enable --now tg-client
journalctl -u tg-client -f
```

SIGTERM/SIGINT → цикл Long Poll отменяется, в логе «Service mode: остановлен сигналом». Память ~20 МБ.

## macOS (локальная разработка)

```bash
brew install tdlib pkg-config
export PKG_CONFIG_PATH="/opt/homebrew/opt/tdlib/lib/pkgconfig:$PKG_CONFIG_PATH"
swift build && swift test
```

## GitHub Actions CI

- `linux-build.yml` — сборка + тесты, `docs.yml` — DocC → GitHub Pages. Ubuntu 24.04, **Swift 6.4.0**.
- TDLib собирается из master и кэшируется; кэш живёт 7 дней без использования — после паузы первая сборка ~25 мин.
- `docs.yml` включает DocC-плагин правкой `Package.swift` через `sed` — меняя список зависимостей, проверяйте этот шаг
  (2026-10-07: после удаления Hummingbird `sed` давал `,,` и манифест не собирался).

---

Связанное: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) · [README](../README.md) (VK Bridge) · [vk-personal-messages-spike.md](vk-personal-messages-spike.md)
