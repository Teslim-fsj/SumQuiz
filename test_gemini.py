import requests
import json
import sys

def test_gemini():
    import os
    api_key = os.environ.get('API_KEY', '')
    model = 'gemini-3.1-flash-lite'
    # Try gemini-1.5-flash if 3.1 fails
    
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    
    headers = {'Content-Type': 'application/json'}
    data = {
        "contents": [{"parts":[{"text": "Hello"}]}]
    }
    
    response = requests.post(url, headers=headers, data=json.dumps(data))
    print(f"Status Coce: {response.status_code}")
    print(f"Response: {response.text}")

if __name__ == '__main__':
    test_gemini()
