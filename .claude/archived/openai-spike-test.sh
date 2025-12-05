#!/bin/bash
# OpenAI API Spike: проверка реального поведения

# Проверка наличия ключа
if [ -z "$OPENAI_API_KEY" ]; then
  echo "❌ OPENAI_API_KEY не задан"
  exit 1
fi

# Простой тестовый запрос
curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant that summarizes messages."},
      {"role": "user", "content": "Summarize this: Hello world"}
    ],
    "max_tokens": 100
  }' | python3 -m json.tool
