import urllib.request
import json

import os

api_key = os.environ.get('API_KEY', '')
url = f'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent?key={api_key}'

payload = {
  "contents": [{
    "parts": [{"text": "Generate a short study guide on Photosynthesis. Include 1 quiz question and 1 flashcard."}]
  }],
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "OBJECT",
      "properties": {
        "title": {"type": "STRING"},
        "summary": {
          "type": "OBJECT",
          "properties": {
            "content": {"type": "STRING"},
            "tags": {
              "type": "ARRAY",
              "items": {"type": "STRING"}
            }
          },
          "required": ["content", "tags"]
        },
        "quiz": {
          "type": "ARRAY",
          "items": {
            "type": "OBJECT",
            "properties": {
              "question": {"type": "STRING"},
              "options": {
                "type": "ARRAY",
                "items": {"type": "STRING"}
              },
              "correctAnswer": {"type": "STRING"},
              "explanation": {"type": "STRING"},
              "questionType": {"type": "STRING"}
            },
            "required": ["question", "correctAnswer", "explanation", "questionType"]
          }
        },
        "flashcards": {
          "type": "ARRAY",
          "items": {
            "type": "OBJECT",
            "properties": {
              "question": {"type": "STRING"},
              "answer": {"type": "STRING"}
            },
            "required": ["question", "answer"]
          }
        }
      },
      "required": ["title", "summary", "quiz", "flashcards"]
    }
  }
}

req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})

try:
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode())
        print(json.dumps(result, indent=2))
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(e.read().decode())
except Exception as e:
    print(e)
