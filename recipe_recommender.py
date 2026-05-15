import pandas as pd
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
from rank_bm25 import BM25Okapi
import numpy as np
import re

#for excluding keywords
def clean_ingredients_for_ml(raw):
    raw = str(raw).lower()
    raw = re.sub(r'\d+\.?\d*\/?\d*', '', raw)
    filler = r'\b(cloves?|cups?|tbsp|tsp|tablespoons?|teaspoons?|grams?|g|kg|ml|oz|pounds?|lbs?|sticks?|slices?|pieces?|heads?|bunches?|cans?|packets?|sheets?|sprigs?|pinch|dash|handful|of|a|an|the|fresh|dried|chopped|minced|sliced|diced|large|small|medium|thick|thin|cut|boneless|skinless|grated|shredded|beaten|melted|softened|cooked|raw|frozen|optional)\b'
    raw = re.sub(filler, '', raw)
    raw = re.sub(r'[(),\-]', ' ', raw)
    raw = re.sub(r'\s+', ' ', raw).strip()
    return raw


def ingredient_tokens(text):
    """Tokenize a cleaned ingredient phrase into meaningful words."""
    return {token for token in str(text).split() if len(token) > 2}


INGREDIENT_CONTEXT = {
    "milk": {"milk", "condensed", "evaporated", "whole", "skim", "buttermilk"},
    "cream": {"cream", "creme", "crema", "whipping", "heavy", "half", "halfandhalf"},
    "cheese": {"cheese", "cheddar", "mozzarella", "parmesan", "feta", "gouda"},
    "butter": {"butter", "margarine", "ghee"},
    "yogurt": {"yogurt", "yoghurt", "curd"},
    "chicken": {"chicken", "thigh", "drumstick", "drumsticks", "breast", "wings", "wing"},
    "beef": {"beef", "steak", "sirloin", "brisket", "mince", "groundbeef"},
    "pork": {"pork", "ham", "bacon", "prosciutto"},
    "fish": {"fish", "salmon", "tuna", "cod", "tilapia", "mackerel"},
    "shellfish": {"shrimp", "prawn", "crab", "lobster", "mussel", "clams"},
    "onion": {"onion", "shallot", "scallion", "spring", "leek"},
    "garlic": {"garlic", "clove"},
    "pepper": {"pepper", "capsicum", "jalapeno", "chili", "chilli"},
    "tomato": {"tomato", "roma", "cherry", "plum", "passata"},
    "potato": {"potato", "russet", "yam", "sweetpotato"},
    "egg": {"egg", "eggs", "yolk", "white"},
    "flour": {"flour", "allpurpose", "plain", "breadflour", "selfraising"},
    "sugar": {"sugar", "brown", "caster", "granulated", "powdered", "icing"},
    "oil": {"oil", "olive", "canola", "sunflower", "sesame", "vegetableoil"},
    "rice": {"rice", "basmati", "jasmine", "arborio", "wildrice"},
    "pasta": {"pasta", "spaghetti", "penne", "fusilli", "fettuccine", "macaroni"},
}


CONTEXT_BY_TOKEN = {
    token: canonical
    for canonical, tokens in INGREDIENT_CONTEXT.items()
    for token in tokens
}


def contextual_tokens(text):
    """
    Expand ingredient tokens with canonical context terms.
    Example: "condensed milk" -> {"condensed", "milk"} + {"milk"}
    """
    tokens = ingredient_tokens(text)
    expanded = set(tokens)
    for token in tokens:
        compact = token.replace(" ", "")
        canonical = CONTEXT_BY_TOKEN.get(token) or CONTEXT_BY_TOKEN.get(compact)
        if canonical:
            expanded.add(canonical)
    return expanded


def ingredients_match(user_item, recipe_item):
    """
    Flexible ingredient matching:
    - exact phrase match
    - token subset match (milk -> condensed milk, chicken -> chicken breast)
    - token overlap fallback
    """
    user_clean = clean_ingredients_for_ml(user_item)
    recipe_clean = clean_ingredients_for_ml(recipe_item)

    if not user_clean or not recipe_clean:
        return False

    if user_clean == recipe_clean:
        return True

    user_tokens = contextual_tokens(user_clean)
    recipe_tokens = contextual_tokens(recipe_clean)
    if not user_tokens or not recipe_tokens:
        return False

    if user_tokens.issubset(recipe_tokens) or recipe_tokens.issubset(user_tokens):
        return True

    return bool(user_tokens & recipe_tokens)

class RecipeRecommender:
    def __init__(self, csv_path='RECIPES.csv'):
        """Initialize the recommender with dataset and model"""
        # Load dataset
        self.df = pd.read_csv(csv_path, encoding='utf-8-sig')
        self.df.columns = self.df.columns.str.strip()  # Clean column names

        # Add recipe_id column only if it doesn't exist
        if 'recipe_id' not in self.df.columns:
            self.df.insert(0, 'recipe_id', range(1, len(self.df) + 1))

        # Pre-calculate numeric columns for faster analytics
        self.df['rating_num'] = pd.to_numeric(self.df['rating'], errors='coerce').fillna(0.0)
        self.df['calories_num'] = pd.to_numeric(self.df['calories'], errors='coerce').fillna(0)

        # Ensure cook_time exists, assign sensible defaults based on difficulty
        if 'cook_time' not in self.df.columns:
            def assign_time(diff):
                d = str(diff).lower()
                if d == 'easy': return 20
                if d == 'hard': return 75
                return 45 # medium/default
            self.df['cook_time'] = self.df['difficulty'].apply(assign_time)
        
        self.model = None
        self.recipe_embeddings = None
        self.bm25 = None
        print("Recommender initialized (models will load on first search).")

    def _ensure_models_loaded(self):
        """Lazy load ML models only when needed."""
        if self.model is None:
            from sentence_transformers import SentenceTransformer
            from rank_bm25 import BM25Okapi
            
            print("Loading ML models for the first time... (Please wait)")
            self.model = SentenceTransformer('all-MiniLM-L6-v2')
            
            # Encode all recipe ingredients
            cleaned_ingredients = self.df['ingredients'].apply(clean_ingredients_for_ml).tolist()
            self.recipe_embeddings = self.model.encode(cleaned_ingredients, show_progress_bar=True)

            # Build BM25 index for keyword matching
            print("Building BM25 keyword index...")
            tokenized_ingredients = [clean_ingredients_for_ml(ing).split() for ing in self.df['ingredients'].tolist()]
            self.bm25 = BM25Okapi(tokenized_ingredients)
            print("Models ready!")

    def _parse_calories(self, val):
        """Safely parse calories even if it's a range or has text."""
        try:
            if pd.isna(val) or val == '' or val == '---':
                return 0
            s = str(val).lower().replace('kcal', '').strip()
            if '-' in s:
                parts = s.split('-')
                return int(float(parts[0].strip()))
            match = re.search(r'(\d+)', s)
            if match:
                return int(match.group(1))
            return 0
        except:
            return 0

    def recommend(self, user_ingredients, top_k=5, alpha=0.5, min_overlap=0):
        self._ensure_models_loaded()
        """
        Recommend recipes using hybrid search (semantic + keyword matching)

        Args:
            user_ingredients (str): Comma-separated ingredients (e.g., "chicken, rice, egg")
            top_k (int): Number of recommendations to return
            alpha (float): Weight for BM25 keyword matching (0=pure semantic, 1=pure keyword)
                          Recommended: 0.3-0.5 for balanced results
            min_overlap (int): Minimum number of overlapping ingredients required (0=no filter)

        Returns:
            list: Top recommended recipes with details
        """
        # Encode user ingredients for semantic search
        user_embedding = self.model.encode([user_ingredients])

        # Calculate semantic similarity
        semantic_scores = cosine_similarity(user_embedding, self.recipe_embeddings)[0]

        # Calculate BM25 keyword scores
        tokenized_query = user_ingredients.lower().replace(',', ' ').split()
        bm25_scores = self.bm25.get_scores(tokenized_query)

        # Normalize both scores to 0-1 range
        semantic_normalized = (semantic_scores - semantic_scores.min()) / (
            semantic_scores.max() - semantic_scores.min() + 1e-10
        )
        bm25_normalized = (bm25_scores - bm25_scores.min()) / (
            bm25_scores.max() - bm25_scores.min() + 1e-10
        )

        # Combine scores with weighted average
        hybrid_scores = alpha * bm25_normalized + (1 - alpha) * semantic_normalized

        # Apply ingredient overlap filter if specified
        if min_overlap > 0:
            user_ingredients_set = set(tokenized_query)
            overlap_counts = []

            for ingredients in self.df['ingredients'].tolist():
                recipe_ingredients = ingredients.lower().replace(',', ' ').split()
                overlap = 0
                for user_token in user_ingredients_set:
                    if any(ingredients_match(user_token, recipe_token) for recipe_token in recipe_ingredients):
                        overlap += 1
                overlap_counts.append(overlap)

            # Set scores to -1 for recipes below minimum overlap
            overlap_counts = np.array(overlap_counts)
            hybrid_scores = np.where(overlap_counts >= min_overlap, hybrid_scores, -1)

        # Get top K indices
        top_indices = np.argsort(hybrid_scores)[-top_k:][::-1]

        # Filter out any recipes with -1 scores (didn't meet min_overlap)
        top_indices = [idx for idx in top_indices if hybrid_scores[idx] >= 0][:top_k]

        # Prepare recommendations
        recommendations = []
        for idx in top_indices:
            recipe = self.df.iloc[idx]

            # Calculate ingredient overlap for display
            user_ingredients_set = set(tokenized_query)
            recipe_ingredients = recipe['ingredients'].lower().replace(',', ' ').split()
            overlap = 0
            for user_token in user_ingredients_set:
                if any(ingredients_match(user_token, recipe_token) for recipe_token in recipe_ingredients):
                    overlap += 1

            recommendations.append({
                'recipe_id': int(recipe['recipe_id']),
                'recipe_name': recipe['recipe_name'],
                'ingredients': recipe['ingredients'],
                'cuisine': recipe['cuisine'],
                'calories': self._parse_calories(recipe['calories']),
                'rating': float(recipe['rating']),
                'difficulty': recipe.get('difficulty', 'medium'),
                'similarity_score': round(float(hybrid_scores[idx]) * 100, 2),  # Hybrid score
                'semantic_score': round(float(semantic_normalized[idx]) * 100, 2),  # For debugging
                'keyword_score': round(float(bm25_normalized[idx]) * 100, 2),  # For debugging
                'ingredient_overlap': overlap,
                'image_url': str(recipe.get('image_url', '') or ''),
            })

        return recommendations

    def recommend_semantic_only(self, user_ingredients, top_k=5):
        """
        Original semantic-only recommendation (for comparison)
        """
        return self.recommend(user_ingredients, top_k=top_k, alpha=0.0, min_overlap=0)

    def recommend_keyword_only(self, user_ingredients, top_k=5):
        """
        Keyword-only recommendation using BM25
        """
        return self.recommend(user_ingredients, top_k=top_k, alpha=1.0, min_overlap=0)

    def fridge_search(self, user_ingredients, top_k=10):
        self._ensure_models_loaded()
        # Parse user ingredients — split by comma FIRST, then clean each one
        user_items = set()
        for item in user_ingredients.split(','):
            cleaned = clean_ingredients_for_ml(item.strip())
            if cleaned and len(cleaned) > 2:
                user_items.add(cleaned)

        user_embedding = self.model.encode([user_ingredients])
        semantic_scores = cosine_similarity(user_embedding, self.recipe_embeddings)[0]

        results = []
        for idx, row in self.df.iterrows():
            # Parse recipe ingredients — split by comma FIRST, then clean each one
            recipe_items = set()
            for item in row['ingredients'].split(','):
                cleaned = clean_ingredients_for_ml(item.strip())
                if cleaned and len(cleaned) > 2:
                    recipe_items.add(cleaned)

            total = len(recipe_items)
            matched_recipe_items = set()
            for recipe_item in recipe_items:
                if any(ingredients_match(user_item, recipe_item) for user_item in user_items):
                    matched_recipe_items.add(recipe_item)

            matched = len(matched_recipe_items)
            missing = list(recipe_items - matched_recipe_items)
            match_pct = round((matched / total) * 100) if total > 0 else 0

            if matched > 0:
                results.append({
                    'recipe_id': int(row['recipe_id']),
                    'recipe_name': row['recipe_name'],
                    'ingredients': row['ingredients'],
                    'cuisine': row['cuisine'],
                    'calories': self._parse_calories(row['calories']),
                    'rating': float(row['rating']),
                    'difficulty': row.get('difficulty', 'medium'),
                    'matched_count': matched,
                    'total_ingredients': total,
                    'missing_ingredients': missing,
                    'match_pct': match_pct,
                    'semantic_score': round(float(semantic_scores[idx]) * 100, 2),
                    'image_url': row.get('image_url', '') or '',
                })

        results.sort(key=lambda x: (x['match_pct'], x['semantic_score']), reverse=True)
        return results[:top_k]

    def get_recipe_by_id(self, recipe_id):
        """Get full recipe details by ID"""
        recipe = self.df[self.df['recipe_id'] == recipe_id]
        if len(recipe) == 0:
            return None

        recipe = recipe.iloc[0]

        # Check if instructions column exists, if not use placeholder
        instructions = recipe.get('instructions', 'Instructions will be added soon.')

        return {
            'recipe_id': int(recipe['recipe_id']),
            'recipe_name': recipe['recipe_name'],
            'ingredients': recipe['ingredients'],
            'cuisine': recipe['cuisine'],
            'calories': self._parse_calories(recipe['calories']),
            'rating': float(recipe['rating']),
            'difficulty': recipe.get('difficulty', 'medium'),
            'instructions': instructions,
            'image_url': recipe.get('image_url', '') or '',
        }


# Initialize recommender globally (so it loads once when app starts)
recommender = None


def get_recommender():
    """Get or initialize the recommender"""
    global recommender
    if recommender is None:
        recommender = RecipeRecommender()
    return recommender


def reset_recommender():
    """
    Invalidate the cached recommender so next request reloads from disk.
    Call this after any admin edit/delete/add to ensure users see updated data.
    """
    global recommender
    recommender = None


def reload_recommender_data():
    """
    Fast reload: re-reads CSV data into an existing recommender instance
    WITHOUT re-training the ML model. This is much faster than a full reset
    and is sufficient for image URL / text field changes.
    """
    global recommender
    if recommender is not None:
        try:
            fresh_df = pd.read_csv('RECIPES.csv', encoding='utf-8-sig')
            fresh_df.columns = fresh_df.columns.str.strip()
            if 'recipe_id' not in fresh_df.columns:
                fresh_df.insert(0, 'recipe_id', range(1, len(fresh_df) + 1))
            recommender.df = fresh_df
        except Exception:
            # If reload fails, fall back to full reset on next request
            recommender = None
    else:
        # No instance yet — will be created fresh on next request
        pass
