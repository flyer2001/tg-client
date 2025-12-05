#!/bin/bash
# Тест русского промпта для OpenAI API

if [ -z "$OPENAI_API_KEY" ]; then
  echo "❌ OPENAI_API_KEY не задан"
  exit 1
fi

echo "🧪 Тестируем русский промпт..."

curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "system",
        "content": "Ты — ассистент для создания дайджестов сообщений из Telegram-каналов. Пиши кратко и по делу."
      },
      {
        "role": "user",
        "content": "Создай дайджест этих сообщений:\n\nКанал: TechNews\n- [https://t.me/tech/1] Вышла новая версия GPT-5\n- [https://t.me/tech/2] Обнаружена уязвимость в OpenSSL\n\nКанал: DevOps\n- Релиз Kubernetes 1.30"
      }
    ],
    "max_tokens": 300
  }' | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('✅ Ответ получен!')
print('=' * 60)
print(data['choices'][0]['message']['content'])
print('=' * 60)
print(f\"📊 Токены: {data['usage']['total_tokens']} (prompt: {data['usage']['prompt_tokens']}, completion: {data['usage']['completion_tokens']})\")
"
