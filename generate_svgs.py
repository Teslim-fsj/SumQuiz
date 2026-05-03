import os

base_path = r"d:\sumquiz-\sumquiz-\assets\mascot\sumi"
os.makedirs(base_path, exist_ok=True)

svgs = {
    "body.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 60 130 C 60 50, 140 50, 140 130 C 140 145, 120 150, 100 150 C 80 150, 60 145, 60 130 Z" fill="#1E3A8A"/>
    </svg>""",
    "head.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg"></svg>""",
    "shadow.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="100" cy="180" rx="60" ry="10" fill="rgba(0,0,0,0.2)"/>
    </svg>""",
    "left_eye_open.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <circle cx="82" cy="95" r="8" fill="white"/>
        <circle cx="84" cy="95" r="4" fill="#0F172A"/>
    </svg>""",
    "left_eye_closed.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 75 95 Q 82 100 89 95" fill="none" stroke="#0F172A" stroke-width="3" stroke-linecap="round"/>
    </svg>""",
    "right_eye_open.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <circle cx="118" cy="95" r="8" fill="white"/>
        <circle cx="116" cy="95" r="4" fill="#0F172A"/>
    </svg>""",
    "right_eye_closed.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 111 95 Q 118 100 125 95" fill="none" stroke="#0F172A" stroke-width="3" stroke-linecap="round"/>
    </svg>""",
    "mouth_smile.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 95 110 Q 100 115 105 110" fill="none" stroke="#0F172A" stroke-width="3" stroke-linecap="round"/>
    </svg>""",
    "mouth_open.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 92 110 Q 100 112 108 110 A 8 8 0 0 1 92 110 Z" fill="#EF4444"/>
    </svg>""",
    "mouth_sad.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 95 115 Q 100 110 105 115" fill="none" stroke="#0F172A" stroke-width="3" stroke-linecap="round"/>
    </svg>""",
    "blush_left.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="72" cy="105" rx="6" ry="4" fill="#EC4899" opacity="0.6"/>
    </svg>""",
    "blush_right.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="128" cy="105" rx="6" ry="4" fill="#EC4899" opacity="0.6"/>
    </svg>""",
    "glasses.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <circle cx="82" cy="95" r="14" fill="none" stroke="#F59E0B" stroke-width="3"/>
        <circle cx="118" cy="95" r="14" fill="none" stroke="#F59E0B" stroke-width="3"/>
        <line x1="96" y1="95" x2="104" y2="95" stroke="#F59E0B" stroke-width="3"/>
    </svg>""",
    "graduation_hat.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <polygon points="100,35 140,50 100,65 60,50" fill="#0D9488"/>
        <polygon points="80,57 120,57 115,70 85,70" fill="#0B7A70"/>
        <line x1="100" y1="50" x2="145" y2="50" stroke="#F59E0B" stroke-width="2"/>
        <line x1="145" y1="50" x2="145" y2="65" stroke="#F59E0B" stroke-width="2"/>
    </svg>""",
    "left_tentacle_1.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 65 140 Q 40 150 50 170 Q 55 180 70 170" fill="none" stroke="#1E3A8A" stroke-width="16" stroke-linecap="round"/>
    </svg>""",
    "right_tentacle_1.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 135 140 Q 160 150 150 170 Q 145 180 130 170" fill="none" stroke="#1E3A8A" stroke-width="16" stroke-linecap="round"/>
    </svg>""",
    "left_tentacle_2.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 80 145 Q 60 160 85 175" fill="none" stroke="#172B6B" stroke-width="12" stroke-linecap="round"/>
    </svg>""",
    "right_tentacle_2.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 120 145 Q 140 160 115 175" fill="none" stroke="#172B6B" stroke-width="12" stroke-linecap="round"/>
    </svg>""",
    "pencil_arm.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 60 120 Q 30 110 35 85" fill="none" stroke="#1E3A8A" stroke-width="12" stroke-linecap="round"/>
        <polygon points="25,75 35,70 40,85 30,90" fill="#FACC15"/>
        <polygon points="25,75 35,70 30,60" fill="#FCA5A5"/>
    </svg>""",
    "calculator_arm.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
        <path d="M 140 120 Q 170 110 165 85" fill="none" stroke="#1E3A8A" stroke-width="12" stroke-linecap="round"/>
        <rect x="155" y="65" width="25" height="35" rx="3" fill="#64748B"/>
        <rect x="158" y="70" width="19" height="10" fill="#E2E8F0"/>
    </svg>""",
    "flashcard_plus.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg"></svg>""",
    "flashcard_minus.svg": """<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg"></svg>"""
}

for name, content in svgs.items():
    with open(os.path.join(base_path, name), "w") as f:
        f.write(content)

print("SVGs generated successfully!")
