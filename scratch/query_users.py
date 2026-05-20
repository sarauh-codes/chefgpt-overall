import os
import sys
# Add current directory to path
sys.path.append(os.path.abspath(os.path.dirname(__file__) + '/..'))

from app import app, db, User

with app.app_context():
    users = User.query.all()
    print("Found users:")
    for u in users:
        print(f"ID: {u.id}, Username: {u.username}, Role: {u.role}")
