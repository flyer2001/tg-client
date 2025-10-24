/**
 * Shim header для экспорта TDLib C API в Swift
 *
 * Что такое module.modulemap?
 * Module map - это файл, который описывает, как C/C++/Objective-C код должен быть
 * импортирован как Swift-модуль. Он связывает C-заголовки с Swift-модулями.
 * Без module.modulemap Swift не знает, как импортировать C-библиотеки.
 *
 * Зачем нужен shim.h?
 * Shim header (промежуточный заголовок) - это паттерн, где мы создаём один заголовочный
 * файл, который включает все нужные C-заголовки. Преимущества:
 * 1. Централизованное управление импортами - все #include в одном месте
 * 2. Возможность платформо-специфичных импортов через макросы (#if __APPLE__)
 * 3. Избежание абсолютных путей в module.modulemap (улучшает портативность)
 * 4. Упрощение module.modulemap - он ссылается только на shim.h
 *
 * Импортируемые заголовки TDLib:
 * - td_json_client.h: JSON-based API для работы с Telegram (send/receive/execute)
 * - td_log.h: API для настройки логирования TDLib
 *
 * См. также:
 * - module.modulemap: определяет Swift-модуль CTDLib
 * - https://www.swift.org/documentation/articles/wrapping-c-cpp-library-in-swift.html
 */

#include <td/telegram/td_json_client.h>
#include <td/telegram/td_log.h>
