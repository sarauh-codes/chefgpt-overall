import os

BASE_DIR = os.path.abspath(os.path.dirname(__file__))

class Config:
    SECRET_KEY = "chegfpt-secret-key-2025"
    SQLALCHEMY_DATABASE_URI = 'sqlite:///' + os.path.join(BASE_DIR, 'instance/chefgpt.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Admin access code
    ADMIN_ACCESS_CODE = os.environ.get('ADMIN_ACCESS_CODE') or 'hiAdmin123'

    # Whisper model
    WHISPER_MODEL = "openai/whisper-small"
