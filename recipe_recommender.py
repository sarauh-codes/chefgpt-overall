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

class RecipeRecommender:
    def __init__(self, csv_path='RECIPES.csv'):
        """Initialize the recommender with dataset and model"""
        # Load dataset
        self.df = pd.read_csv(csv_path, encoding='utf-8-sig')
        self.df.columns = self.df.columns.str.strip()  # Clean column names

        # Add recipe_id column
        # Add recipe_id column only if it doesn't exist
        if 'recipe_id' not in self.df.columns:
            self.df.insert(0, 'recipe_id', range(1, len(self.df) + 1))


        # Load pre-trained model (all-MiniLM-L6-v2)
        print("Loading ML model...")
        self.model = SentenceTransformer('all-MiniLM-L6-v2')

        # Encode all recipe ingredients
        cleaned_ingredients = self.df['ingredients'].apply(clean_ingredients_for_ml).tolist()
        self.recipe_embeddings = self.model.encode(cleaned_ingredients, show_progress_bar=True)

        # Build BM25 index for keyword matching
        print("Building BM25 keyword index...")
        tokenized_ingredients = [clean_ingredients_for_ml(ing).split() for ing in self.df['ingredients'].tolist()]
        self.bm25 = BM25Okapi(tokenized_ingredients)

        print("Model ready! Loaded {} recipes.".format(len(self.df)))

    def recommend(self, user_ingredients, top_k=5, alpha=0.5, min_overlap=0):
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
                recipe_ingredients = set(ingredients.lower().replace(',', ' ').split())
                overlap = len(user_ingredients_set & recipe_ingredients)
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
            recipe_ingredients = set(recipe['ingredients'].lower().replace(',', ' ').split())
            overlap = len(user_ingredients_set & recipe_ingredients)

            recommendations.append({
                'recipe_id': int(recipe['recipe_id']),
                'recipe_name': recipe['recipe_name'],
                'ingredients': recipe['ingredients'],
                'cuisine': recipe['cuisine'],
                'calories': int(recipe['calories']),
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
            matched = len(user_items & recipe_items)
            missing = list(recipe_items - user_items)
            match_pct = round((matched / total) * 100) if total > 0 else 0

            results.append({
                'recipe_id': int(row['recipe_id']),
                'recipe_name': row['recipe_name'],
                'ingredients': row['ingredients'],
                'cuisine': row['cuisine'],
                'calories': int(row['calories']),
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
            'calories': int(recipe['calories']),
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
