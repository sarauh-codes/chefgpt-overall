---
title: ChefGPT
emoji: 🍳
colorFrom: green
colorTo: yellow
sdk: docker
app_port: 7860
pinned: false
---

# ChefGPT — Setup Guide

## Prerequisites

- Python 3.10+
- Git

---

## 1. Clone the project

```bash
git clone <your-repo-url>
cd chefgpt-overall
```

---

## 2. Create a virtual environment

```bash
python -m venv venv
```

**Windows:**
```bash
venv\Scripts\activate
```

**Mac/Linux:**
```bash
source venv/bin/activate
```

---

## 3. Install dependencies

```bash
pip install -r requirements.txt
```

> ⚠️ This includes PyTorch and AI models (~2GB). It may take a few minutes on first install.

---

## 4. Create a `.env` file

Create a file named `.env` in the project root with the following:

```
GROQ_API_KEY=your_groq_api_key_here
ADMIN_ACCESS_CODE=hiAdmin123
```

- Get a free GROQ API key at: https://console.groq.com/
- The `ADMIN_ACCESS_CODE` is used to register the admin account (default is `hiAdmin123`)

---

## 5. Run the app

```bash
python app.py
```

The server will start at: **http://127.0.0.1:5000**

> On first run, it will automatically create the database tables. This is normal.

---

## 6. Create your account

1. Go to **http://127.0.0.1:5000/register** to create a regular user account.
2. To create an **Admin** account, go to **http://127.0.0.1:5000/register_admin** and enter the admin access code (`hiAdmin123`).

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `ModuleNotFoundError` | Make sure you activated the venv and ran `pip install -r requirements.txt` |
| `GROQ_API_KEY not found` | Make sure `.env` file exists in the project root |
| App starts but no recipes show | The AI model is still loading — wait 30-60 seconds and refresh |
| Database empty | This is normal on first run — register a new account at `/register` |

---

## Notes

- The `instance/chefgpt.db` database is **not shared** — each person gets their own fresh database when they first run the app.
- Recipe data is in `RECIPES.csv` (tracked by git).
- User accounts and saved recipes are stored in the local SQLite database only.
