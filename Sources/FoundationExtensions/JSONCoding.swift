import Foundation

/// Централизованные настройки кодирования/декодирования JSON для TDLib API.
///
/// TDLib JSON API использует snake_case для имён полей согласно официальной документации:
/// - td_json_client.h: "JSON objects with the same keys as the API object field names"
/// - Официальный пример: https://github.com/tdlib/td/blob/36b05e9/example/python/tdjson_example.py
///
/// ## Использование
///
/// Всегда используйте `.tdlib()` factory методы вместо прямого создания encoder/decoder:
///
/// ```swift
/// // ✅ Правильно
/// let encoder = JSONEncoder.tdlib()
/// let decoder = JSONDecoder.tdlib()
///
/// // ❌ Неправильно (будет заблокировано SwiftLint)
/// let encoder = JSONEncoder()
/// let decoder = JSONDecoder()
/// ```
extension JSONEncoder {
    /// Централизованный encoder для TDLib API.
    ///
    /// **Настройки:**
    /// - `keyEncodingStrategy = .convertToSnakeCase` — автоматическая конвертация camelCase → snake_case
    ///
    /// **Использование:**
    /// ```swift
    /// let encoder = JSONEncoder.tdlib()
    /// let data = try encoder.encode(request)
    /// ```
    ///
    /// **Маппинг полей:**
    /// - `chatList` → `"chat_list"` (автоматически)
    /// - `firstName` → `"first_name"` (автоматически)
    /// - `type` → `"@type"` (через явный CodingKey, т.к. @ не конвертируется)
    public static func tdlib() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

extension JSONDecoder {
    /// Централизованный decoder для TDLib API.
    ///
    /// **Настройки:**
    /// - `keyDecodingStrategy = .convertFromSnakeCase` — автоматическая конвертация snake_case → camelCase
    ///
    /// **Использование:**
    /// ```swift
    /// let decoder = JSONDecoder.tdlib()
    /// let response = try decoder.decode(MessagesResponse.self, from: data)
    /// ```
    ///
    /// **Маппинг полей:**
    /// - `"chat_list"` → `chatList` (автоматически)
    /// - `"first_name"` → `firstName` (автоматически)
    /// - `"@type"` → `type` (через явный CodingKey, т.к. @ не конвертируется)
    public static func tdlib() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

// MARK: - OpenAI API

extension JSONEncoder {
    /// Централизованный encoder для OpenAI API.
    ///
    /// **Настройки:**
    /// - `keyEncodingStrategy = .convertToSnakeCase` — автоматическая конвертация camelCase → snake_case
    ///
    /// **Использование:**
    /// ```swift
    /// let encoder = JSONEncoder.openAI()
    /// let data = try encoder.encode(request)
    /// ```
    public static func openAI() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

extension JSONDecoder {
    /// Централизованный decoder для OpenAI API.
    ///
    /// **Настройки:**
    /// - `keyDecodingStrategy = .convertFromSnakeCase` — автоматическая конвертация snake_case → camelCase
    ///
    /// **Использование:**
    /// ```swift
    /// let decoder = JSONDecoder.openAI()
    /// let response = try decoder.decode(ChatCompletionResponse.self, from: data)
    /// ```
    public static func openAI() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
