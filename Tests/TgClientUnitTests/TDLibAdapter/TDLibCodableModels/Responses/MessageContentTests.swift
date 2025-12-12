import TgClientModels
import TGClientInterfaces
import Foundation
import Testing
import FoundationExtensions
import TestHelpers
@testable import TDLibAdapter

/// Unit-тесты для MessageContent (типы контента сообщений).
///
/// **TDLib API:** https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_message_content.html
@Suite("Unit: MessageContent")
struct MessageContentTests {

    // MARK: - messagePhoto

    /// Декодирование messagePhoto с caption.
    @Test("Decode: messagePhoto с caption")
    func decodePhotoWithCaption() throws {
        let json = """
        {
            "@type": "messagePhoto",
            "photo": {
                "@type": "photo",
                "has_stickers": false,
                "minithumbnail": null,
                "sizes": []
            },
            "caption": {
                "@type": "formattedText",
                "text": "Beautiful sunset",
                "entities": []
            },
            "is_secret": false,
            "has_spoiler": false,
            "show_caption_above_media": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: data)

        guard case .photo(let caption) = decoded else {
            Issue.record("Expected .photo content")
            return
        }

        #expect(caption != nil)
        #expect(caption?.text == "Beautiful sunset")
    }

    /// Декодирование messagePhoto без caption (пустой объект).
    @Test("Decode: messagePhoto без caption")
    func decodePhotoWithoutCaption() throws {
        let json = """
        {
            "@type": "messagePhoto",
            "photo": {
                "@type": "photo",
                "has_stickers": false,
                "minithumbnail": null,
                "sizes": []
            },
            "caption": {
                "@type": "formattedText",
                "text": "",
                "entities": []
            },
            "is_secret": false,
            "has_spoiler": false,
            "show_caption_above_media": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: data)

        guard case .photo(let caption) = decoded else {
            Issue.record("Expected .photo content")
            return
        }

        // Caption присутствует, но пустой
        #expect(caption != nil)
        #expect(caption?.text == "")
    }

    // MARK: - messageVideo

    /// Декодирование messageVideo с caption.
    @Test("Decode: messageVideo с caption")
    func decodeVideoWithCaption() throws {
        let json = """
        {
            "@type": "messageVideo",
            "video": {
                "@type": "video",
                "duration": 120,
                "width": 1920,
                "height": 1080,
                "file_name": "video.mp4",
                "mime_type": "video/mp4",
                "has_stickers": false,
                "supports_streaming": true,
                "minithumbnail": null,
                "thumbnail": null,
                "video": {
                    "@type": "file",
                    "id": 123,
                    "size": 1048576,
                    "expected_size": 1048576,
                    "local": {},
                    "remote": {}
                }
            },
            "caption": {
                "@type": "formattedText",
                "text": "Tutorial video",
                "entities": []
            },
            "is_secret": false,
            "has_spoiler": false,
            "show_caption_above_media": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: data)

        guard case .video(let caption) = decoded else {
            Issue.record("Expected .video content")
            return
        }

        #expect(caption != nil)
        #expect(caption?.text == "Tutorial video")
    }

    // MARK: - messageVoice

    /// Декодирование messageVoice с caption.
    @Test("Decode: messageVoice с caption")
    func decodeVoiceWithCaption() throws {
        let json = """
        {
            "@type": "messageVoice",
            "voice": {
                "@type": "voiceNote",
                "duration": 30,
                "waveform": [],
                "mime_type": "audio/ogg",
                "speech_recognition_result": null,
                "voice": {
                    "@type": "file",
                    "id": 456,
                    "size": 32768,
                    "expected_size": 32768,
                    "local": {},
                    "remote": {}
                }
            },
            "caption": {
                "@type": "formattedText",
                "text": "Quick voice note",
                "entities": []
            },
            "is_listened": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: data)

        guard case .voice(let caption) = decoded else {
            Issue.record("Expected .voice content")
            return
        }

        #expect(caption != nil)
        #expect(caption?.text == "Quick voice note")
    }

    // MARK: - messageAudio

    /// Декодирование messageAudio с caption.
    @Test("Decode: messageAudio с caption")
    func decodeAudioWithCaption() throws {
        let json = """
        {
            "@type": "messageAudio",
            "audio": {
                "@type": "audio",
                "duration": 240,
                "title": "Song Title",
                "performer": "Artist Name",
                "file_name": "song.mp3",
                "mime_type": "audio/mpeg",
                "album_cover_minithumbnail": null,
                "album_cover_thumbnail": null,
                "external_album_covers": [],
                "audio": {
                    "@type": "file",
                    "id": 789,
                    "size": 5242880,
                    "expected_size": 5242880,
                    "local": {},
                    "remote": {}
                }
            },
            "caption": {
                "@type": "formattedText",
                "text": "Great track!",
                "entities": []
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: data)

        guard case .audio(let caption) = decoded else {
            Issue.record("Expected .audio content")
            return
        }

        #expect(caption != nil)
        #expect(caption?.text == "Great track!")
    }

    // MARK: - Encoding

    /// Энкодирование messagePhoto с caption.
    @Test("Encode: messagePhoto с caption")
    func encodePhotoWithCaption() throws {
        let caption = FormattedText(text: "Test caption", entities: nil)
        let content = MessageContent.photo(caption: caption)

        let data = try JSONEncoder.tdlib().encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["@type"] as? String == "messagePhoto")
        let captionDict = json["caption"] as? [String: Any]
        #expect(captionDict?["text"] as? String == "Test caption")
    }

    /// Энкодирование messagePhoto без caption.
    @Test("Encode: messagePhoto без caption")
    func encodePhotoWithoutCaption() throws {
        let content = MessageContent.photo(caption: nil)

        let data = try JSONEncoder.tdlib().encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["@type"] as? String == "messagePhoto")
        #expect(json["caption"] == nil)
    }

    /// Энкодирование messageVideo с caption.
    @Test("Encode: messageVideo с caption")
    func encodeVideoWithCaption() throws {
        let caption = FormattedText(text: "Video description", entities: nil)
        let content = MessageContent.video(caption: caption)

        let data = try JSONEncoder.tdlib().encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["@type"] as? String == "messageVideo")
        let captionDict = json["caption"] as? [String: Any]
        #expect(captionDict?["text"] as? String == "Video description")
    }

    /// Энкодирование messageVoice с caption.
    @Test("Encode: messageVoice с caption")
    func encodeVoiceWithCaption() throws {
        let caption = FormattedText(text: "Voice memo", entities: nil)
        let content = MessageContent.voice(caption: caption)

        let data = try JSONEncoder.tdlib().encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["@type"] as? String == "messageVoice")
        let captionDict = json["caption"] as? [String: Any]
        #expect(captionDict?["text"] as? String == "Voice memo")
    }

    /// Энкодирование messageAudio с caption.
    @Test("Encode: messageAudio с caption")
    func encodeAudioWithCaption() throws {
        let caption = FormattedText(text: "Podcast episode", entities: nil)
        let content = MessageContent.audio(caption: caption)

        let data = try JSONEncoder.tdlib().encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["@type"] as? String == "messageAudio")
        let captionDict = json["caption"] as? [String: Any]
        #expect(captionDict?["text"] as? String == "Podcast episode")
    }

    // MARK: - Edge Cases

    /// Декодирование messageText (для сравнения с новыми типами).
    @Test("Decode: messageText (baseline)")
    func decodeMessageText() throws {
        let json = """
        {
            "@type": "messageText",
            "text": {
                "@type": "formattedText",
                "text": "Plain text message",
                "entities": []
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: data)

        guard case .text(let formattedText) = decoded else {
            Issue.record("Expected .text content")
            return
        }

        #expect(formattedText.text == "Plain text message")
    }

    /// Декодирование unsupported типа (messageDocument, messageSticker).
    @Test("Decode: unsupported types")
    func decodeUnsupportedTypes() throws {
        let documentJson = """
        {
            "@type": "messageDocument",
            "document": {},
            "caption": {}
        }
        """

        let stickerJson = """
        {
            "@type": "messageSticker",
            "sticker": {}
        }
        """

        let docData = documentJson.data(using: .utf8)!
        let docDecoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: docData)
        guard case .unsupported = docDecoded else {
            Issue.record("Expected .unsupported for messageDocument")
            return
        }

        let stickerData = stickerJson.data(using: .utf8)!
        let stickerDecoded = try JSONDecoder.tdlib().decode(MessageContent.self, from: stickerData)
        guard case .unsupported = stickerDecoded else {
            Issue.record("Expected .unsupported for messageSticker")
            return
        }
    }
}
