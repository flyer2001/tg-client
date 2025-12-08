import Foundation

/// Helper для загрузки переменных окружения из .env файла.
///
/// **Формат .env:**
/// ```bash
/// # Комментарии игнорируются
/// export KEY=value
/// KEY=value
/// KEY="value with spaces"
/// KEY='single quotes'
/// ```
///
/// **Использование:**
/// ```swift
/// try EnvFileLoader.loadDotEnv(from: "/path/to/.env")
/// // Теперь все переменные доступны через ProcessInfo.processInfo.environment
/// ```
public enum EnvFileLoader {
    /// Загружает переменные из .env файла в окружение процесса.
    ///
    /// - Parameter path: Путь к .env файлу (по умолчанию `.env` в текущей директории)
    /// - Throws: Если файл не найден или не читается
    public static func loadDotEnv(from path: String = ".env") throws {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            // Не бросаем ошибку - .env опционален (можно использовать системные env)
            return
        }

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            // Пропускаем комментарии и пустые строки
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Удаляем "export " если есть
            var keyValue = trimmed
            if keyValue.hasPrefix("export ") {
                keyValue = String(keyValue.dropFirst(7)) // "export ".count == 7
            }

            // Парсим KEY=value
            guard let equalIndex = keyValue.firstIndex(of: "=") else {
                continue
            }

            let key = String(keyValue[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(keyValue[keyValue.index(after: equalIndex)...])

            // Убираем кавычки если есть
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            // Заменяем $HOME и ~ на реальный путь
            value = expandPath(value)

            // Устанавливаем переменную окружения
            setenv(key, value, 1) // 1 = overwrite existing
        }
    }

    /// Раскрывает $HOME и ~ в пути.
    private static func expandPath(_ path: String) -> String {
        var result = path
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Заменяем $HOME
        result = result.replacingOccurrences(of: "$HOME", with: homeDir)

        // Заменяем ~ (только в начале строки или после пробела)
        if result.hasPrefix("~") {
            result = homeDir + result.dropFirst()
        }
        result = result.replacingOccurrences(of: " ~", with: " \(homeDir)")

        return result
    }
}
