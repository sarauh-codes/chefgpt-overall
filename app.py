# ==================== IMPORTS ====================
from flask import Flask, render_template, request, url_for, redirect, flash, jsonify, get_flashed_messages
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
from recipe_recommender import get_recommender
from config import Config
from transformers import pipeline, BlipProcessor, BlipForConditionalGeneration
from PIL import Image as PILImage
import pandas as pd
import tempfile
import csv
import re
import os


# ==================== APP INIT ====================
app = Flask(__name__)
CORS(app)
app.config.from_object(Config)
app.config['JWT_SECRET_KEY'] = 'chefgpt-secret-key-2024'

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = "login"
ADMIN_ACCESS_CODE = app.config['ADMIN_ACCESS_CODE']


# ==================== AI MODELS ====================
whisper_model = pipeline(
    "automatic-speech-recognition",
    model=app.config.get("WHISPER_MODEL", "openai/whisper-small")
)

blip_processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
blip_model = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-base")


# ==================== DATABASE MODELS ====================
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    role = db.Column(db.String(20), nullable=False, default='user')


class CookedRecipe(db.Model):
    __tablename__ = 'cooked_recipes'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    recipe_id = db.Column(db.Integer, nullable=False)
    recipe_name = db.Column(db.String(200), nullable=False)
    cooked_at = db.Column(db.DateTime, default=datetime.utcnow)
    user = db.relationship('User', backref='cooked_recipes')


class Feedback(db.Model):
    __tablename__ = 'feedbacks'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id', ondelete="SET NULL"), nullable=True)
    username_backup = db.Column(db.String(80), nullable=True)
    recipe_id = db.Column(db.Integer, nullable=False)
    recipe_name = db.Column(db.String(200), nullable=False)
    rating = db.Column(db.Integer, nullable=True)
    comment = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    user = db.relationship('User', backref='feedbacks')


class SavedRecipe(db.Model):
    __tablename__ = 'saved_recipes'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    recipe_id = db.Column(db.Integer, nullable=False)
    recipe_name = db.Column(db.String(200), nullable=False)
    saved_at = db.Column(db.DateTime, default=datetime.utcnow)
    user = db.relationship('User', backref='saved_recipes')


class DietaryProfile(db.Model):
    __tablename__ = 'dietary_profiles'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, unique=True)
    diet_type = db.Column(db.String(50), default='omnivore')
    allergies = db.Column(db.Text, default='')
    forbidden_ingredients = db.Column(db.Text, default='')
    updated_at = db.Column(db.DateTime, default=datetime.utcnow)
    user = db.relationship('User', backref=db.backref('dietary_profile', uselist=False))


# ==================== DATABASE INIT ====================
with app.app_context():
    db.create_all()
    from sqlalchemy import Column, String
    if not hasattr(Feedback, 'username_backup'):
        with db.engine.connect() as conn:
            conn.execute('ALTER TABLE feedbacks ADD COLUMN username_backup VARCHAR(80)')


# ==================== LOGIN MANAGER ====================
@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


# ==================== HELPER FUNCTIONS ====================
def apply_dietary_filter(df, profile):
    if not profile:
        return df

    ingredients_col = df['ingredients'].str.lower()

    diet_rules = {
        'vegan': ['chicken', 'beef', 'pork', 'lamb', 'turkey', 'meat',
                  'fish', 'shrimp', 'prawn', 'salmon', 'tuna', 'crab',
                  'lobster', 'milk', 'cream', 'butter', 'cheese',
                  'egg', 'honey', 'yogurt'],
        'vegetarian': ['chicken', 'beef', 'pork', 'lamb', 'turkey',
                       'meat', 'fish', 'shrimp', 'prawn', 'salmon',
                       'tuna', 'crab', 'lobster'],
        'halal': ['pork', 'bacon', 'ham', 'lard', 'gelatin',
                  'alcohol', 'wine', 'beer'],
    }

    if profile.diet_type in diet_rules:
        for item in diet_rules[profile.diet_type]:
            df = df[~ingredients_col.str.contains(item, na=False)]
            ingredients_col = df['ingredients'].str.lower()

    if profile.allergies:
        for allergy in [a.strip().lower() for a in profile.allergies.split(',') if a.strip()]:
            df = df[~df['ingredients'].str.lower().str.contains(allergy, na=False)]

    if profile.forbidden_ingredients:
        for item in [f.strip().lower() for f in profile.forbidden_ingredients.split(',') if f.strip()]:
            df = df[~df['ingredients'].str.lower().str.contains(item, na=False)]

    return df


def singularize(word):
    word = word.strip().lower()
    if word.endswith("ies"):
        return word[:-3] + "y"
    if word.endswith("ves"):
        return word[:-3] + "f"
    if word.endswith("es") and not word.endswith("ses"):
        return word[:-2]
    if word.endswith("s") and not word.endswith("ss"):
        return word[:-1]
    return word


# ==================== AUTH ROUTES ====================
@app.route("/")
def home():
    get_flashed_messages()
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return render_template("index.html")


@app.route('/register', methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form.get("username")
        email = request.form.get("email")
        password = request.form.get("password")

        if User.query.filter_by(username=username).first():
            flash("Username already exists!", "error")
            return render_template("register.html")

        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        new_user = User(username=username, email=email, password=hashed_password)
        db.session.add(new_user)
        db.session.commit()
        flash("Registration successful! Please login.", "success")
        return redirect(url_for("login"))

    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username")
        password = request.form.get("password")
        user = User.query.filter_by(username=username).first()

        if user and bcrypt.check_password_hash(user.password, password):
            login_user(user)
            flash(f"Welcome {user.username}!", "success")
            if user.role == "admin":
                return redirect(url_for('admin_dashboard'))
            else:
                return redirect(url_for('dashboard'))
        else:
            flash("Invalid username or password", "error")

    return render_template("index.html")


@app.route("/logout")
@login_required
def logout():
    logout_user()
    flash("Logged out successfully.", "success")
    return redirect(url_for("home"))


# ==================== DASHBOARD ROUTES ====================
@app.route("/dashboard")
@login_required
def dashboard():
    recommender = get_recommender()
    df = recommender.df.copy()
    df = df.drop_duplicates(subset=['recipe_id'], keep='first')
    df = df.drop_duplicates(subset=['recipe_name'], keep='first')

    profile = DietaryProfile.query.filter_by(user_id=current_user.id).first()
    if profile:
        df = apply_dietary_filter(df, profile)

    df_shuffled = df.sample(n=min(12, len(df)), replace=False)
    recipes = df_shuffled.to_dict('records')
    total_recipes = len(df)

    return render_template("dashboard.html",
        username=current_user.username,
        recipes=recipes,
        total_recipes=total_recipes,
        profile=profile)


@app.route('/load-more-recipes')
@login_required
def load_more_recipes():
    offset = request.args.get('offset', 0, type=int)
    limit = 12

    recommender = get_recommender()
    df = recommender.df.copy()
    df = df.drop_duplicates(subset=['recipe_name'], keep='first')
    profile = DietaryProfile.query.filter_by(user_id=current_user.id).first()
    df = apply_dietary_filter(df, profile)
    df = df.sample(frac=1).reset_index(drop=True)
    recipes_df = df.iloc[offset:offset + limit]

    recipes_list = []
    for _, row in recipes_df.iterrows():
        recipes_list.append({
            'recipe_id': int(row['recipe_id']),
            'recipe_name': str(row['recipe_name']),
            'ingredients': str(row['ingredients']),
            'cuisine': str(row['cuisine']),
            'calories': int(row['calories']),
            'rating': float(row['rating'])
        })

    has_more = (offset + limit) < len(df)
    return jsonify({'recipes': recipes_list, 'has_more': has_more})


@app.route('/search-recipes', methods=['GET'])
@login_required
def search_recipes():
    query = request.args.get('q', '').strip().lower()
    if not query:
        return jsonify({'recipes': []})

    recommender = get_recommender()
    df = recommender.df.copy()
    df = df.drop_duplicates(subset=['recipe_name'], keep='first')

    mask = (
        df['recipe_name'].str.lower().str.contains(query, na=False) |
        df['cuisine'].str.lower().str.contains(query, na=False) |
        df['ingredients'].str.lower().str.contains(query, na=False)
    )

    recipes_list = []
    for _, row in df[mask].iterrows():
        recipes_list.append({
            'recipe_id': int(row['recipe_id']),
            'recipe_name': str(row['recipe_name']),
            'ingredients': str(row['ingredients']),
            'cuisine': str(row['cuisine']),
            'calories': int(row['calories']),
            'rating': float(row['rating']),
            'difficulty': str(row['difficulty'])
        })

    return jsonify({'recipes': recipes_list})


# ==================== RECIPE ROUTES ====================
@app.route("/recipe/<int:recipe_id>")
@login_required
def recipe_detail(recipe_id):
    recommender = get_recommender()
    recipe = recommender.get_recipe_by_id(recipe_id)
    if not recipe:
        flash("Recipe not found!", "error")
        return redirect(url_for('dashboard'))
    return render_template("recipe_detail.html", recipe=recipe)


@app.route("/start-cooking/<int:recipe_id>")
@login_required
def start_cooking(recipe_id):
    recommender = get_recommender()
    recipe = recommender.get_recipe_by_id(recipe_id)
    if not recipe:
        flash("Recipe not found!", "error")
        return redirect(url_for('dashboard'))
    return render_template("cooking.html", recipe=recipe)


@app.route("/mark-as-cooked/<int:recipe_id>", methods=["POST"])
@login_required
def mark_as_cooked(recipe_id):
    try:
        recommender = get_recommender()
        recipe = recommender.get_recipe_by_id(recipe_id)
        if not recipe:
            return jsonify({'error': 'Recipe not found'}), 404
        cooked = CookedRecipe(
            user_id=current_user.id,
            recipe_id=recipe_id,
            recipe_name=recipe['recipe_name']
        )
        db.session.add(cooked)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Recipe marked as cooked!'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ── TASTE PROFILE HELPER ──────────────────────────────────────────
TASTE_KEYWORDS = {
    "spicy":     ["chili", "pepper", "cayenne", "jalapeño", "sriracha", "hot sauce", "chilli"],
    "sweet":     ["sugar", "honey", "chocolate", "coconut milk", "maple syrup", "vanilla"],
    "savory":    ["garlic", "soy sauce", "onion", "cheese", "mushroom", "broth", "miso"],
    "healthy":   ["spinach", "broccoli", "quinoa", "tofu", "salad", "kale", "lentil", "oats"],
    "indulgent": ["butter", "cream", "bacon", "fried", "pastry", "mayo", "cheese sauce"],
}

CUISINE_WEIGHTS = {
    "asian":            {"savory": 2, "spicy": 1},
    "italian":          {"savory": 2, "indulgent": 1},
    "indian":           {"spicy": 2, "savory": 1},
    "mexican":          {"spicy": 2, "indulgent": 1},
    "middle eastern":   {"savory": 2, "healthy": 1},
    "british":          {"indulgent": 2, "savory": 1},
    "japanese":         {"savory": 2, "healthy": 1},
    "american":         {"indulgent": 2},
    "french":           {"indulgent": 2, "sweet": 1},
    "french/american":  {"indulgent": 2, "sweet": 1},
    "vietnamese":       {"healthy": 2, "savory": 1},
    "hungarian":        {"savory": 2, "indulgent": 1},
    "greek":            {"healthy": 2, "savory": 1},
    "russian":          {"indulgent": 2, "savory": 1},
    "spanish":          {"savory": 2},
    "thai":             {"spicy": 2, "sweet": 1},
    "korean":           {"spicy": 2, "savory": 1},
    "north african":    {"savory": 2, "healthy": 1},
    "caribbean":        {"sweet": 1, "spicy": 1},
    "african/caribbean":{"sweet": 1, "spicy": 1},
    "turkish":          {"savory": 2, "spicy": 1},
    "eastern european": {"indulgent": 2, "savory": 1},
    "australian":       {"healthy": 1, "savory": 1},
    "dessert":          {"sweet": 3, "indulgent": 2},
    "malaysian":        {"spicy": 2, "savory": 1},
    "malay":            {"spicy": 2, "savory": 1},
}

def compute_taste_profile(recipes_list):
    from collections import defaultdict
    totals = defaultdict(float)
    axes = ["spicy", "sweet", "savory", "healthy", "indulgent"]

    for recipe in recipes_list:
        ingredients_text = str(recipe.get("ingredients", "")).lower()
        cuisine = str(recipe.get("cuisine", "")).lower()

        for axis, keywords in TASTE_KEYWORDS.items():
            for kw in keywords:
                if kw in ingredients_text:
                    totals[axis] += 1

        for cname, boosts in CUISINE_WEIGHTS.items():
            if cname in cuisine:
                for axis, val in boosts.items():
                    totals[axis] += val

    max_val = max(totals.values(), default=1)
    return {axis: round((totals.get(axis, 0) / max_val) * 100) for axis in axes}


# ── TASTE PROFILE ROUTE ───────────────────────────────────────────
@app.route("/api/taste-profile")
@login_required
def taste_profile_api():
    cooked = CookedRecipe.query.filter_by(user_id=current_user.id).all()

    if not cooked:
        return jsonify({"empty": True, "labels": [], "scores": []})

    recommender = get_recommender()
    df = recommender.df.copy()

    cooked_ids = [c.recipe_id for c in cooked]
    matched = df[df["recipe_id"].isin(cooked_ids)]
    recipes_list = matched[["ingredients", "cuisine"]].to_dict(orient="records")

    profile = compute_taste_profile(recipes_list)
    labels = [k.capitalize() for k in profile.keys()]
    scores = list(profile.values())

    return jsonify({"empty": False, "labels": labels, "scores": scores})

@app.route("/api/mobile-taste-profile")
@jwt_required()
def mobile_taste_profile_api():
    user_id = get_jwt_identity()
    cooked = CookedRecipe.query.filter_by(user_id=user_id).all()

    if not cooked:
        return jsonify({"empty": True, "labels": [], "scores": []})

    recommender = get_recommender()
    df = recommender.df.copy()

    cooked_ids = [c.recipe_id for c in cooked]
    matched = df[df["recipe_id"].isin(cooked_ids)]
    recipes_list = matched[["ingredients", "cuisine"]].to_dict(orient="records")

    profile = compute_taste_profile(recipes_list)
    labels = [k.capitalize() for k in profile.keys()]
    scores = list(profile.values())

    return jsonify({"empty": False, "labels": labels, "scores": scores})

@app.route("/cooked-history")
@login_required
def cooked_history():
    cooked_recipes = CookedRecipe.query.filter_by(user_id=current_user.id)\
        .order_by(CookedRecipe.cooked_at.desc()).all()
    return render_template("cooked_history.html", recipes=cooked_recipes)


@app.route("/save-recipe/<int:recipe_id>", methods=["POST"])
@login_required
def save_recipe(recipe_id):
    try:
        recommender = get_recommender()
        recipe = recommender.get_recipe_by_id(recipe_id)
        if not recipe:
            return jsonify({'error': 'Recipe not found'}), 404
        existing = SavedRecipe.query.filter_by(
            user_id=current_user.id, recipe_id=recipe_id).first()
        if existing:
            return jsonify({'success': False, 'message': 'Recipe already saved!'})
        saved = SavedRecipe(
            user_id=current_user.id,
            recipe_id=recipe_id,
            recipe_name=recipe['recipe_name']
        )
        db.session.add(saved)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Recipe saved!'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route("/unsave-recipe/<int:recipe_id>", methods=["POST"])
@login_required
def unsave_recipe(recipe_id):
    try:
        saved = SavedRecipe.query.filter_by(
            user_id=current_user.id, recipe_id=recipe_id).first()
        if not saved:
            return jsonify({'success': False, 'message': 'Recipe not in saved list!'})
        db.session.delete(saved)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Recipe unsaved!'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route("/saved-recipes")
@login_required
def saved_recipes():
    saved = SavedRecipe.query.filter_by(user_id=current_user.id)\
        .order_by(SavedRecipe.saved_at.desc()).all()
    return render_template("saved_recipes.html", recipes=saved)


@app.route("/is-saved/<int:recipe_id>")
@login_required
def is_saved(recipe_id):
    saved = SavedRecipe.query.filter_by(
        user_id=current_user.id, recipe_id=recipe_id).first()
    return jsonify({'is_saved': saved is not None})


# ==================== RECOMMEND ROUTES ====================
@app.route("/recommend")
@login_required
def recommend_page():
    return render_template("recommend.html")


@app.route("/get-recommendations", methods=["POST"])
@login_required
def get_recommendations():
    try:
        data = request.get_json()
        user_ingredients = data.get('ingredients', '')
        if not user_ingredients:
            return jsonify({'error': 'Please enter at least one ingredient'}), 400

        recommender = get_recommender()
        recommendations = recommender.fridge_search(user_ingredients, top_k=30)

        profile = DietaryProfile.query.filter_by(user_id=current_user.id).first()
        if profile:
            allowed_ids = set(apply_dietary_filter(recommender.df.copy(), profile)['recipe_id'].tolist())
            recommendations = [r for r in recommendations if r['recipe_id'] in allowed_ids]

        recommendations = recommendations[:10]

        return jsonify({'recommendations': recommendations})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route("/transcribe-audio", methods=["POST"])
@jwt_required()
def transcribe_audio():
    try:
        if 'audio' not in request.files:
            return jsonify({'error': 'No audio file received'}), 400
        
        audio_file = request.files['audio']
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=".webm") as tmp:
            audio_file.save(tmp.name)
            tmp_webm = tmp.name
        
        tmp_wav = tmp_webm + ".wav"
        os.system(f'ffmpeg -i "{tmp_webm}" -ar 16000 -ac 1 -c:a pcm_s16le "{tmp_wav}" -y -loglevel quiet')
        
        result = whisper_model(tmp_wav)
        transcript = result["text"].strip()
        
        os.remove(tmp_webm)
        os.remove(tmp_wav)
        
        return jsonify({'transcript': transcript})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route("/analyze-image", methods=["POST"])
@jwt_required()
def analyze_image():
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file received'}), 400
        image_file = request.files['image']
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            image_file.save(tmp.name)
            tmp_path = tmp.name
        image = PILImage.open(tmp_path).convert("RGB")
        prompt = "the ingredients in this image are"
        inputs = blip_processor(image, prompt, return_tensors="pt")
        output = blip_model.generate(**inputs, max_new_tokens=50)
        caption = blip_processor.decode(output[0], skip_special_tokens=True)
        ingredients = caption.replace(prompt, "").strip()
        descriptors = [
            "white", "brown", "red", "green", "yellow", "fresh", "raw", "cooked",
            "sliced", "chopped", "diced", "minced", "whole", "large", "small",
            "medium", "boiled", "fried", "dried", "frozen", "organic", "ripe"
        ]
        parts = re.split(r'\band\b|,', ingredients)
        seen = set()
        cleaned = []
        for part in parts:
            word = singularize(part)
            word_parts = [w for w in word.split() if w not in descriptors]
            word = " ".join(word_parts).strip()
            if word and word not in seen:
                seen.add(word)
                cleaned.append(word)
        ingredients = ", ".join(cleaned)
        os.remove(tmp_path)
        return jsonify({'ingredients': ingredients})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== FRIDGE SEARCH ROUTES ====================
@app.route("/fridge-search")
@login_required
def fridge_search_page():
    return render_template("fridge_search.html")

@app.route("/fridge-search-results", methods=["POST"])
@login_required
def fridge_search_results():
    try:
        data = request.get_json()
        user_ingredients = data.get('ingredients', '').strip()
        if not user_ingredients:
            return jsonify({'error': 'Please enter at least one ingredient'}), 400

        recommender = get_recommender()
        results = recommender.fridge_search(user_ingredients, top_k=20)

        # Apply dietary filter
        df = pd.DataFrame(results)
        profile = DietaryProfile.query.filter_by(user_id=current_user.id).first()
        df = apply_dietary_filter(df, profile)
        results = df.head(10).to_dict(orient='records')

        return jsonify({'results': results})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# Mobile API version
@app.route("/api/fridge-search", methods=["POST"])
@jwt_required()
def api_fridge_search():
    try:
        data = request.get_json()
        user_ingredients = data.get('ingredients', '').strip()
        if not user_ingredients:
            return jsonify({'error': 'Please enter at least one ingredient'}), 400

        user_id = get_jwt_identity()
        recommender = get_recommender()
        results = recommender.fridge_search(user_ingredients, top_k=20)

        profile = DietaryProfile.query.filter_by(user_id=user_id).first()
        if profile:
            allowed_ids = set(apply_dietary_filter(recommender.df.copy(), profile)['recipe_id'].tolist())
            results = [r for r in results if r['recipe_id'] in allowed_ids]

        results = results[:10]

        return jsonify({'results': results})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
# ==================== FEEDBACK ROUTES ====================
@app.route("/submit-feedback/<int:recipe_id>", methods=["POST"])
@login_required
def submit_feedback(recipe_id):
    try:
        data = request.get_json()
        rating = data.get('rating')
        comment = data.get('comment', '').strip()
        recommender = get_recommender()
        recipe = recommender.get_recipe_by_id(recipe_id)
        if not recipe:
            return jsonify({'error': 'Recipe not found'}), 404
        existing_feedback = Feedback.query.filter_by(
            user_id=current_user.id, recipe_id=recipe_id).first()
        if existing_feedback:
            existing_feedback.rating = rating
            existing_feedback.comment = comment
            existing_feedback.created_at = datetime.utcnow()
        else:
            feedback = Feedback(
                user_id=current_user.id,
                recipe_id=recipe_id,
                recipe_name=recipe['recipe_name'],
                rating=rating,
                comment=comment
            )
            db.session.add(feedback)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Thank you for your feedback!'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route("/get-feedbacks/<int:recipe_id>")
@login_required
def get_feedbacks(recipe_id):
    try:
        feedbacks = Feedback.query.filter_by(recipe_id=recipe_id)\
            .order_by(Feedback.created_at.desc()).all()
        feedback_list = []
        for fb in feedbacks:
            feedback_list.append({
                'username': fb.user.username if fb.user else "Deleted User",
                'rating': fb.rating,
                'comment': fb.comment,
                'created_at': fb.created_at.strftime('%B %d, %Y')
            })
        return jsonify({'feedbacks': feedback_list})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== DIETARY SETTINGS ROUTES ====================
@app.route("/diet-settings", methods=["GET", "POST"])
@login_required
def diet_settings():
    profile = DietaryProfile.query.filter_by(user_id=current_user.id).first()
    if request.method == "POST":
        diet_type = request.form.get("diet_type", "omnivore")
        allergies = request.form.get("allergies", "").strip()
        forbidden_ingredients = request.form.get("forbidden_ingredients", "").strip()
        if profile:
            profile.diet_type = diet_type
            profile.allergies = allergies
            profile.forbidden_ingredients = forbidden_ingredients
            profile.updated_at = datetime.utcnow()
        else:
            profile = DietaryProfile(
                user_id=current_user.id,
                diet_type=diet_type,
                allergies=allergies,
                forbidden_ingredients=forbidden_ingredients
            )
            db.session.add(profile)
        db.session.commit()
        flash("Dietary details saved successfully!", "success")
        return redirect(url_for("dashboard"))
    return render_template("diet_settings.html", profile=profile)


# ==================== ADMIN ROUTES ====================
@app.route("/dashboard_admin")
@login_required
def admin_dashboard():
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    recommender = get_recommender()
    recipes_df = recommender.df
    users = User.query.all()
    feedbacks = Feedback.query.all()
    return render_template('/admin/dashboard_admin.html',
        users=users, feedbacks=feedbacks,
        recipes=recipes_df.to_dict(orient='records'))


@app.route('/register_admin', methods=['GET', 'POST'])
def register_admin():
    if request.method == 'POST':
        username = request.form['username']
        email = request.form['email']
        password = request.form['password']
        access_code = request.form['access_code']
        if access_code != ADMIN_ACCESS_CODE:
            flash("Invalid admin access code!", "danger")
            return redirect(url_for('register_admin'))
        if User.query.filter_by(username=username).first():
            flash("Username already exists!", "danger")
            return redirect(url_for('register_admin'))
        hashed_pw = bcrypt.generate_password_hash(password).decode('utf-8')
        new_admin = User(username=username, email=email, password=hashed_pw, role='admin')
        db.session.add(new_admin)
        db.session.commit()
        flash("Admin registered successfully!", "success")
        return redirect(url_for('login'))
    return render_template('/admin/register_admin.html')


@app.route('/admin/delete-user/<int:user_id>', methods=['POST'])
@login_required
def delete_user(user_id):
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    user_to_delete = User.query.get_or_404(user_id)
    try:
        feedbacks = Feedback.query.filter_by(user_id=user_to_delete.id).all()
        for fb in feedbacks:
            fb.username_backup = user_to_delete.username
            fb.user_id = None
        db.session.commit()
        db.session.delete(user_to_delete)
        db.session.commit()
        flash(f"User {user_to_delete.username} has been deleted.", "success")
    except Exception as e:
        db.session.rollback()
        flash(f"An error occurred: {str(e)}", "danger")
    return redirect(url_for('admin_dashboard'))


@app.route('/admin/edit-user/<int:user_id>', methods=['GET', 'POST'])
@login_required
def edit_user(user_id):
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    user = User.query.get_or_404(user_id)
    if request.method == 'POST':
        user.username = request.form['username']
        user.email = request.form['email']
        user.role = request.form['role']
        db.session.commit()
        flash("User updated successfully.", "success")
        return redirect(url_for('admin_dashboard'))
    return render_template('admin/edit_user.html', user=user)


@app.route('/admin/add_user', methods=['GET', 'POST'])
def add_user():
    if not current_user.is_authenticated or current_user.role != 'admin':
        flash("Access denied", "danger")
        return redirect(url_for('login'))
    if request.method == 'POST':
        username = request.form['username']
        email = request.form['email']
        password = request.form['password']
        role = request.form['role']
        if User.query.filter_by(email=email).first():
            flash("Email already exists", "danger")
            return redirect(url_for('add_user'))
        new_user = User(
            username=username, email=email,
            password=generate_password_hash(password), role=role
        )
        db.session.add(new_user)
        db.session.commit()
        flash(f"User {username} added successfully!", "success")
        return redirect(url_for('admin_dashboard'))
    return render_template('/admin/add_user.html')


@app.route('/admin/manage_recipes')
@login_required
def manage_recipes():
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    df = pd.read_csv('recipes.csv', encoding='utf-8-sig')
    df.columns = df.columns.str.strip()
    if 'recipe_id' not in df.columns:
        df.insert(0, 'recipe_id', range(1, len(df)+1))
    search = request.args.get('q', '').lower()
    if search:
        df = df[
            df['recipe_name'].str.lower().str.contains(search, na=False) |
            df['cuisine'].str.lower().str.contains(search, na=False) |
            df['ingredients'].str.lower().str.contains(search, na=False)
        ]
    return render_template('admin/manage_recipes.html', recipes=df.to_dict('records'))


@app.route('/admin/add_recipe', methods=['GET', 'POST'])
@login_required
def add_recipe():
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    if request.method == 'POST':
        df = pd.read_csv('recipes.csv', encoding='utf-8-sig')
        df.columns = df.columns.str.strip()
        if 'recipe_id' not in df.columns:
            df.insert(0, 'recipe_id', range(1, len(df) + 1))
        new_id = df['recipe_id'].max() + 1 if len(df) > 0 else 1
        new_row = {
            'recipe_id': new_id,
            'recipe_name': request.form['recipe_name'],
            'ingredients': request.form['ingredients'],
            'cuisine': request.form['cuisine'],
            'calories': request.form['calories'],
            'rating': request.form['rating'],
            'difficulty': request.form['difficulty'],
            'instructions': request.form.get('instructions', '')
        }
        df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
        df.drop(columns=['recipe_id'], inplace=True)
        df.to_csv('recipes.csv', index=False, encoding='utf-8-sig')
        flash("Recipe added successfully!", "success")
        return redirect(url_for('manage_recipes'))
    return render_template('admin/add_recipe.html')


@app.route('/admin/edit_recipe/<int:recipe_id>', methods=['GET', 'POST'])
@login_required
def edit_recipe(recipe_id):
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    df = pd.read_csv('recipes.csv', encoding='utf-8-sig')
    df.columns = df.columns.str.strip()
    if 'recipe_id' not in df.columns:
        df.insert(0, 'recipe_id', range(1, len(df)+1))
    idx = df[df['recipe_id'] == recipe_id].index
    if idx.empty:
        flash("Recipe not found", "danger")
        return redirect(url_for('manage_recipes'))
    if request.method == 'POST':
        df.loc[idx, 'recipe_name'] = request.form['recipe_name']
        df.loc[idx, 'ingredients'] = request.form['ingredients']
        df.loc[idx, 'cuisine'] = request.form['cuisine']
        df.loc[idx, 'calories'] = request.form['calories']
        df.loc[idx, 'rating'] = request.form['rating']
        df.loc[idx, 'difficulty'] = request.form['difficulty']
        df.loc[idx, 'instructions'] = request.form.get('instructions', '')
        df.to_csv('recipes.csv', index=False, encoding='utf-8-sig')
        flash("Recipe updated successfully!", "success")
        return redirect(url_for('manage_recipes'))
    recipe = df.loc[idx[0]].to_dict()
    return render_template('admin/edit_recipe.html', recipe=recipe)


@app.route('/admin/delete_recipe/<int:recipe_id>', methods=['POST'])
@login_required
def delete_recipe(recipe_id):
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    recipes = []
    with open('recipes.csv', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            recipes.append(row)
    df = pd.DataFrame(recipes)
    df.insert(0, 'recipe_id', range(1, len(df) + 1))
    if df[df['recipe_id'] == recipe_id].empty:
        flash("Recipe not found", "danger")
        return redirect(url_for('manage_recipes'))
    df = df[df['recipe_id'] != recipe_id]
    df.drop(columns=['recipe_id'], inplace=True)
    df.to_csv('recipes.csv', index=False)
    flash("Recipe deleted successfully!", "success")
    return redirect(url_for('manage_recipes'))


@app.route('/admin/manage_user')
@login_required
def manage_user():
    if current_user.role != 'admin':
        flash('Access denied', 'danger')
        return redirect(url_for('dashboard'))
    users = User.query.filter(User.role != 'admin').all()
    return render_template('/admin/manage_user.html', users=users)


@app.route('/admin/manage_feedback')
@login_required
def manage_feedback():
    if current_user.role != 'admin':
        flash('Access denied', 'danger')
        return redirect(url_for('dashboard'))
    feedbacks = Feedback.query.all()
    return render_template('/admin/manage_feedbacks.html', feedbacks=feedbacks)


@app.route('/admin/delete-feedback/<int:feedback_id>', methods=['POST'])
@login_required
def delete_feedback(feedback_id):
    if current_user.role != 'admin':
        flash("Access denied!", "danger")
        return redirect(url_for('dashboard'))
    feedback = Feedback.query.get_or_404(feedback_id)
    try:
        db.session.delete(feedback)
        db.session.commit()
        flash("Feedback deleted successfully.", "success")
    except Exception as e:
        db.session.rollback()
        flash(f"Error deleting feedback: {str(e)}", "danger")
    return redirect(url_for('admin_dashboard'))


# ==================== MOBILE API ROUTES ====================
@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    user = User.query.filter_by(username=username).first()
    if user and bcrypt.check_password_hash(user.password, password):
        token = create_access_token(identity=str(user.id))
        return jsonify({'token': token, 'username': user.username})
    return jsonify({'error': 'Invalid credentials'}), 401


@app.route('/api/register', methods=['POST'])
def api_register():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'Username already exists'}), 400
    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
    new_user = User(username=username, email=email, password=hashed_password)
    db.session.add(new_user)
    db.session.commit()
    return jsonify({'message': 'Registration successful!'})


@app.route('/api/recipes', methods=['GET'])
@jwt_required()
def api_get_recipes():
    user_id = get_jwt_identity()
    recommender = get_recommender()
    df = recommender.df.copy()
    df = df.drop_duplicates(subset=['recipe_name'], keep='first')
    profile = DietaryProfile.query.filter_by(user_id=user_id).first()
    df = apply_dietary_filter(df, profile)
    df_shuffled = df.sample(n=min(12, len(df)), replace=False)
    return jsonify({'recipes': df_shuffled.to_dict('records')}) 
    return jsonify({'recipes': df_shuffled.to_dict('records')})


@app.route('/api/search-recipes', methods=['GET'])
@jwt_required()
def api_search_recipes():
    query = request.args.get('q', '').strip().lower()
    if not query:
        return jsonify({'recipes': []})

    recommender = get_recommender()
    df = recommender.df.copy()
    df = df.drop_duplicates(subset=['recipe_name'], keep='first')

    mask = (
        df['recipe_name'].str.lower().str.contains(query, na=False) |
        df['cuisine'].str.lower().str.contains(query, na=False) |
        df['ingredients'].str.lower().str.contains(query, na=False)
    )

    recipes_list = []
    for _, row in df[mask].iterrows():
        recipes_list.append({
            'recipe_id': int(row['recipe_id']),
            'recipe_name': str(row['recipe_name']),
            'ingredients': str(row['ingredients']),
            'cuisine': str(row['cuisine']),
            'calories': int(row['calories']),
            'rating': float(row['rating']),
            'difficulty': str(row['difficulty'])
        })

    return jsonify({'recipes': recipes_list})
@app.route('/api/recipe/<int:recipe_id>', methods=['GET'])
@jwt_required()
def api_recipe_detail(recipe_id):
    recommender = get_recommender()
    recipe = recommender.get_recipe_by_id(recipe_id)
    if not recipe:
        return jsonify({'error': 'Recipe not found'}), 404
    return jsonify({'recipe': recipe})


@app.route('/api/recommendations', methods=['POST'])
@jwt_required()
def api_recommendations():
    try:
        data = request.get_json()
        ingredients = data.get('ingredients', '')
        if not ingredients:
            return jsonify({'error': 'No ingredients provided'}), 400

        recommender = get_recommender()
        recommendations = recommender.fridge_search(ingredients, top_k=30)

        profile = DietaryProfile.query.filter_by(user_id=get_jwt_identity()).first()
        if profile:
            allowed_ids = set(apply_dietary_filter(recommender.df.copy(), profile)['recipe_id'].tolist())
            recommendations = [r for r in recommendations if r['recipe_id'] in allowed_ids]

        recommendations = recommendations[:10]

        return jsonify({'recommendations': recommendations})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/save-recipe/<int:recipe_id>', methods=['POST'])
@jwt_required()
def api_save_recipe(recipe_id):
    user_id = get_jwt_identity()
    recommender = get_recommender()
    recipe = recommender.get_recipe_by_id(recipe_id)
    if not recipe:
        return jsonify({'error': 'Recipe not found'}), 404
    existing = SavedRecipe.query.filter_by(user_id=user_id, recipe_id=recipe_id).first()
    if existing:
        return jsonify({'message': 'Already saved!'})
    saved = SavedRecipe(user_id=user_id, recipe_id=recipe_id, recipe_name=recipe['recipe_name'])
    db.session.add(saved)
    db.session.commit()
    return jsonify({'message': 'Recipe saved!'})


@app.route('/api/saved-recipes', methods=['GET'])
@jwt_required()
def api_saved_recipes():
    user_id = get_jwt_identity()
    saved = SavedRecipe.query.filter_by(user_id=user_id).all()
    recipes = [{'recipe_id': s.recipe_id, 'recipe_name': s.recipe_name} for s in saved]
    return jsonify({'recipes': recipes})

@app.route("/api/unsave-recipe/<int:recipe_id>", methods=["POST"])
@jwt_required()
def api_unsave_recipe(recipe_id):
    user_id = get_jwt_identity()
    try:
        saved = SavedRecipe.query.filter_by(
            user_id=user_id, recipe_id=recipe_id).first()
        if not saved:
            return jsonify({'success': False, 'message': 'Recipe not in saved list!'})
        db.session.delete(saved)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Recipe unsaved!'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/diet-settings', methods=['GET'])
@jwt_required()
def api_get_diet():
    user_id = get_jwt_identity()
    profile = DietaryProfile.query.filter_by(user_id=user_id).first()
    if not profile:
        return jsonify({'diet_type': 'omnivore', 'allergies': '', 'forbidden_ingredients': ''})
    return jsonify({
        'diet_type': profile.diet_type,
        'allergies': profile.allergies,
        'forbidden_ingredients': profile.forbidden_ingredients
    })


@app.route('/api/diet-settings', methods=['POST'])
@jwt_required()
def api_save_diet():
    user_id = get_jwt_identity()
    data = request.get_json()
    profile = DietaryProfile.query.filter_by(user_id=user_id).first()
    if profile:
        profile.diet_type = data.get('diet_type', 'omnivore')
        profile.allergies = data.get('allergies', '')
        profile.forbidden_ingredients = data.get('forbidden_ingredients', '')
        profile.updated_at = datetime.utcnow()
    else:
        profile = DietaryProfile(
            user_id=user_id,
            diet_type=data.get('diet_type', 'omnivore'),
            allergies=data.get('allergies', ''),
            forbidden_ingredients=data.get('forbidden_ingredients', '')
        )
        db.session.add(profile)
    db.session.commit()
    return jsonify({'message': 'Dietary settings saved!'})


@app.route('/api/cooked-history', methods=['GET'])
@jwt_required()
def api_cooked_history():
    user_id = get_jwt_identity()
    cooked = CookedRecipe.query.filter_by(user_id=user_id)\
        .order_by(CookedRecipe.cooked_at.desc()).all()
    recipes = [{'recipe_id': c.recipe_id, 'recipe_name': c.recipe_name,
                'cooked_at': c.cooked_at.strftime('%d %b %Y')} for c in cooked]
    return jsonify({'recipes': recipes})

@app.route('/api/mark-cooked/<int:recipe_id>', methods=['POST'])
@jwt_required()
def api_mark_cooked(recipe_id):
    user_id = get_jwt_identity()
    try:
        recommender = get_recommender()
        recipe = recommender.get_recipe_by_id(recipe_id)
        if not recipe:
            return jsonify({'error': 'Recipe not found'}), 404
        cooked = CookedRecipe(
            user_id=user_id,
            recipe_id=recipe_id,
            recipe_name=recipe['recipe_name']
        )
        db.session.add(cooked)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Recipe marked as cooked!'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route("/api/get-feedbacks/<int:recipe_id>")
@jwt_required()
def api_get_feedbacks(recipe_id):
    try:
        feedbacks = Feedback.query.filter_by(recipe_id=recipe_id)\
            .order_by(Feedback.created_at.desc()).all()
        feedback_list = []
        for fb in feedbacks:
            feedback_list.append({
                'username': fb.user.username if fb.user else "Deleted User",
                'rating': fb.rating,
                'comment': fb.comment,
                'created_at': fb.created_at.strftime('%B %d, %Y')
            })
        return jsonify({'feedbacks': feedback_list})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route("/api/submit-feedback/<int:recipe_id>", methods=["POST"])
@jwt_required()
def api_submit_feedback(recipe_id):
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        rating = data.get('rating')
        comment = data.get('comment', '').strip()
        recommender = get_recommender()
        recipe = recommender.get_recipe_by_id(recipe_id)
        if not recipe:
            return jsonify({'error': 'Recipe not found'}), 404
        existing_feedback = Feedback.query.filter_by(
            user_id=user_id, recipe_id=recipe_id).first()
        if existing_feedback:
            existing_feedback.rating = rating
            existing_feedback.comment = comment
            existing_feedback.created_at = datetime.utcnow()
        else:
            feedback = Feedback(
                user_id=user_id,
                recipe_id=recipe_id,
                recipe_name=recipe['recipe_name'],
                rating=rating,
                comment=comment
            )
            db.session.add(feedback)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Thank you for your feedback!'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== SUBSTITUTE ROUTES ====================
SUBSTITUTES = {
    # Proteins
    "chicken":        [("tofu", "use firm tofu, same cooking method"), ("turkey", "1:1 ratio, similar texture")],
    "beef":           [("lamb", "stronger flavour, 1:1 ratio"), ("mushrooms", "for vegetarian option, use portobello")],
    "salmon":         [("tuna", "similar oily fish"), ("cod", "milder flavour, works in most salmon dishes")],
    "cod":            [("tilapia", "mild white fish, 1:1 ratio"), ("salmon", "richer flavour")],
    "shrimp":         [("scallops", "similar cook time"), ("firm tofu", "for vegetarian option")],
    "pork":           [("chicken", "leaner, adjust cook time"), ("beef", "richer flavour")],
    "bacon":          [("turkey bacon", "leaner option"), ("smoked ham", "similar smoky flavour")],
    "fish":           [("tofu", "for vegetarian version"), ("chicken", "milder substitute")],
    "clams":          [("mussels", "similar briny flavour"), ("shrimp", "different texture but works in chowder")],
    "paneer":         [("firm tofu", "press well before using"), ("halloumi", "saltier, adjust seasoning")],

    # Dairy
    "milk":           [("oat milk", "neutral flavour, 1:1 ratio"), ("almond milk", "slightly nutty")],
    "cream":          [("coconut cream", "dairy-free option"), ("evaporated milk", "less rich, use same amount")],
    "butter":         [("margarine", "1:1 ratio"), ("coconut oil", "for baking, same amount")],
    "cheese":         [("nutritional yeast", "for vegan option, adds cheesy flavour"), ("parmesan", "if recipe uses mild cheese")],
    "mozzarella":     [("provolone", "melts similarly"), ("cheddar", "stronger flavour but melts well")],
    "parmesan":       [("pecorino romano", "saltier, use less"), ("nutritional yeast", "vegan option")],
    "cheddar":        [("gouda", "milder flavour"), ("colby", "similar meltability")],
    "sour cream":     [("plain yogurt", "1:1 ratio, slightly tangier"), ("creme fraiche", "richer option")],
    "greek yogurt":   [("plain yogurt", "less thick, strain if needed"), ("sour cream", "tangier flavour")],
    "yogurt":         [("sour cream", "tangier, 1:1 ratio"), ("coconut yogurt", "dairy-free option")],
    "ricotta":        [("cottage cheese", "blend until smooth first"), ("cream cheese", "richer and denser")],
    "tahini":         [("peanut butter", "stronger flavour, use less"), ("almond butter", "milder option")],
    "coconut milk":   [("heavy cream", "richer, not dairy-free"), ("oat milk + coconut extract", "lighter option")],

    # Grains & Starches
    "rice":           [("quinoa", "higher protein, same cooking ratio"), ("cauliflower rice", "low-carb option")],
    "pasta":          [("rice noodles", "gluten-free option"), ("zucchini noodles", "low-carb option")],
    "noodles":        [("pasta", "adjust cook time"), ("rice noodles", "gluten-free option")],
    "flour":          [("almond flour", "gluten-free, denser result"), ("oat flour", "blend oats until fine, 1:1")],
    "bread":          [("pita bread", "thinner, works for toast"), ("wraps", "softer texture")],
    "pita bread":     [("flour tortilla", "thinner, similar function"), ("naan", "thicker, softer")],
    "tortillas":      [("pita bread", "thicker but works"), ("lettuce leaves", "low-carb wrap option")],
    "oats":           [("breadcrumbs", "for binding in patties"), ("quinoa flakes", "1:1 ratio")],
    "breadcrumbs":    [("crushed crackers", "similar crunch"), ("panko", "lighter, crispier result")],
    "couscous":       [("quinoa", "higher protein, similar texture"), ("bulgur wheat", "nuttier flavour")],
    "gnocchi":        [("pasta", "adjust cook time"), ("dumplings", "different texture but works with pesto")],
    "phyllo dough":   [("puff pastry", "thicker, adjust baking time"), ("spring roll wrappers", "thinner option")],

    # Vegetables
    "onion":          [("shallots", "milder flavour, use same amount"), ("leeks", "softer flavour, white part only")],
    "garlic":         [("garlic powder", "¼ tsp per clove"), ("shallots", "milder garlic-like flavour")],
    "tomato":         [("canned tomatoes", "use ¼ cup per fresh tomato"), ("roasted red pepper", "sweeter flavour")],
    "carrot":         [("parsnip", "sweeter flavour"), ("sweet potato", "softer texture when cooked")],
    "potato":         [("sweet potato", "sweeter, more nutritious"), ("turnip", "lower carb option")],
    "eggplant":       [("zucchini", "milder flavour, less absorbent"), ("portobello mushroom", "meatier texture")],
    "zucchini":       [("eggplant", "more absorbent, adjust oil"), ("yellow squash", "1:1 ratio")],
    "bell pepper":    [("poblano pepper", "slightly spicier"), ("zucchini", "milder, different texture")],
    "mushrooms":      [("eggplant", "meatier texture"), ("zucchini", "lighter substitute")],
    "spinach":        [("kale", "tougher, cook longer"), ("bok choy", "similar mild flavour")],
    "cabbage":        [("bok choy", "similar crunch"), ("napa cabbage", "milder, 1:1 ratio")],
    "celery":         [("fennel", "similar crunch, anise flavour"), ("bok choy", "milder option")],
    "cucumber":       [("zucchini", "for cooked dishes"), ("celery", "for crunch in salads")],
    "pumpkin":        [("butternut squash", "1:1 ratio, slightly sweeter"), ("sweet potato", "denser texture")],
    "avocado":        [("hummus", "for spreading"), ("greek yogurt", "for creamy texture in dips")],
    "lemongrass":     [("lemon zest + ginger", "use 1 tsp zest + ½ tsp ginger"), ("lemon juice", "less aromatic")],

    # Legumes
    "chickpeas":      [("white beans", "similar texture and mild flavour"), ("lentils", "softer when cooked")],
    "lentils":        [("chickpeas", "firmer texture"), ("split peas", "similar cooking time")],
    "beans":          [("lentils", "softer texture"), ("chickpeas", "firmer, similar protein content")],
    "black beans":    [("kidney beans", "similar size and texture"), ("pinto beans", "creamier option")],
    "tofu":           [("tempeh", "firmer, nuttier flavour"), ("paneer", "for non-vegan dishes")],

    # Sauces & Condiments
    "soy sauce":      [("tamari", "gluten-free, same flavour"), ("coconut aminos", "less salty, slightly sweet")],
    "miso paste":     [("soy sauce", "use 1 tbsp per 2 tbsp miso, less complex"), ("tahini", "different flavour but adds depth")],
    "tomato sauce":   [("crushed tomatoes + herbs", "blend and season to taste"), ("passata", "smoother texture")],
    "sesame oil":     [("olive oil + toasted sesame seeds", "adds nuttiness"), ("peanut oil", "neutral alternative")],
    "olive oil":      [("vegetable oil", "neutral flavour"), ("coconut oil", "slight coconut flavour")],
    "caesar dressing":[("ranch dressing", "different flavour profile but creamy"), ("lemon + parmesan", "make simple dressing")],
    "chili sauce":    [("sriracha", "spicier, use less"), ("sambal oelek", "chunkier texture")],
    "gochujang":      [("sriracha + miso", "mix 1:1 for similar depth"), ("chili paste", "less complex flavour")],

    # Spices & Herbs
    "basil":          [("oregano", "earthier flavour"), ("parsley", "milder, fresh flavour")],
    "cilantro":       [("parsley", "milder flavour, no citrus note"), ("basil", "sweeter alternative")],
    "cumin":          [("coriander", "citrusy, use same amount"), ("caraway seeds", "similar earthy notes")],
    "paprika":        [("chili powder", "spicier, use half the amount"), ("cayenne", "much hotter, use ¼ amount")],
    "cinnamon":       [("nutmeg", "warmer flavour, use half"), ("allspice", "1:1 ratio")],
    "ginger":         [("ground ginger", "¼ tsp powder per 1 tsp fresh"), ("galangal", "similar but more piney")],
    "dill":           [("fennel fronds", "similar anise-like flavour"), ("parsley", "milder, less distinct")],
    "herbs":          [("dried mixed herbs", "use ⅓ of fresh amount"), ("parsley + thyme", "versatile combination")],
    "spices":         [("garam masala", "for Indian dishes"), ("mixed spice blend", "adjust to cuisine type")],

    # Baking
    "egg":            [("flax egg", "1 tbsp ground flaxseed + 3 tbsp water, for binding"), ("applesauce", "¼ cup per egg, for baking")],
    "sugar":          [("honey", "use ¾ amount, reduce other liquids slightly"), ("maple syrup", "use ¾ amount")],
    "cocoa powder":   [("carob powder", "naturally sweeter, caffeine-free"), ("dark chocolate", "melt 30g per 3 tbsp cocoa")],
    "baking powder":  [("¼ tsp baking soda + ½ tsp cream of tartar", "exact substitute"), ("self-raising flour", "adjust flour amount")],
    "vanilla":        [("vanilla bean paste", "1:1 ratio"), ("almond extract", "use half, stronger flavour")],
    "honey":          [("maple syrup", "1:1 ratio, slightly different flavour"), ("agave nectar", "milder sweetness")],
    "nuts":           [("seeds", "sunflower or pumpkin seeds work well"), ("granola", "adds crunch similarly")],

    # Others
    "lime juice":     [("lemon juice", "1:1 ratio, slightly less tart"), ("white vinegar", "use half the amount")],
    "lemon juice":    [("lime juice", "1:1 ratio"), ("white vinegar", "use half the amount")],
    "malt vinegar":   [("white vinegar", "milder, 1:1 ratio"), ("apple cider vinegar", "slightly fruity")],
    "balsamic":       [("red wine vinegar + honey", "mix 1 tbsp vinegar + 1 tsp honey"), ("pomegranate molasses", "sweeter option")],
    "broth":          [("stock", "richer flavour"), ("water + bouillon cube", "convenient substitute")],
    "seaweed":        [("spinach leaves", "different flavour but adds greens"), ("nori strips", "if using as garnish")],
    "wasabi":         [("horseradish", "similar heat, less green"), ("spicy mustard", "milder heat")],
    "saffron":        [("turmeric", "adds colour but different flavour, use a pinch"), ("sweet paprika", "for colour only")],
    "peanuts":        [("cashews", "milder, similar crunch"), ("sunflower seeds", "nut-free option")],
    "pine nuts":      [("walnuts", "stronger flavour, chop finely"), ("cashews", "milder, similar texture")],
    "oil":            [("vegetable oil", "neutral flavour"), ("coconut oil", "slight coconut flavour")],
    "plantain":       [("banana", "sweeter when fried"), ("sweet potato slices", "less sweet option")],
    "mango":          [("peach", "similar sweetness and texture"), ("papaya", "tropical alternative")],
}

@app.route("/get-substitute", methods=["POST"])
@login_required
def get_substitute():
    data = request.get_json()
    ingredient = data.get('ingredient', '').strip().lower()
    subs = SUBSTITUTES.get(ingredient, [])
    return jsonify({'ingredient': ingredient, 'substitutes': subs})

# Mobile API version
@app.route("/api/get-substitute", methods=["POST"])
@jwt_required()
def api_get_substitute():
    data = request.get_json()
    ingredient = data.get('ingredient', '').strip().lower()
    subs = SUBSTITUTES.get(ingredient, [])
    return jsonify({'ingredient': ingredient, 'substitutes': subs})

# ==================== RUN ====================
if __name__ == "__main__":
    app.run(debug=True)