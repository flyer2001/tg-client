#!/bin/bash
# Release-сборка tg-client для Linux со статически вшитой стандартной библиотекой Swift.
#
# Бинарь не требует Swift на целевой машине (проверено: собран Swift 6.4 на ubuntu-home,
# запускается на VDS со Swift 6.3.2). Нужны только системные библиотеки Ubuntu 24.04 (glibc 2.39,
# libcurl…) и libtdjson той же версии, что при сборке — кладите рядом и запускайте с
# LD_LIBRARY_PATH=<папка>. Размер: ~73 МБ бинарь + ~46 МБ libtdjson.
#
# Swift 6.4: --static-swift-stdlib НЕ подтягивает статические части Foundation сам —
# без явного списка ниже линковка падает (undefined reference CFCharacterSetGetPredefined,
# _platform_shims_*, Synchronization.Mutex). См. TROUBLESHOOTING.md.
#
# Использование: ./scripts/build-release-linux.sh   → .build/…/Release-linux-x86_64/tg-client
set -euo pipefail

LIBS=(FoundationNetworking _CFURLSessionInterface Foundation FoundationInternationalization
      FoundationEssentials CoreFoundation _FoundationCollections _FoundationCShims _FoundationICU
      swiftSynchronization curl)
FLAGS=()
for lib in "${LIBS[@]}"; do FLAGS+=(-Xlinker "-l$lib"); done

swift build -c release --static-swift-stdlib --product tg-client "${FLAGS[@]}"
BIN="$(swift build -c release --show-bin-path)/tg-client"
ls -la "$BIN"
ldd "$BIN" | grep -E "tdjson|not found" || true
