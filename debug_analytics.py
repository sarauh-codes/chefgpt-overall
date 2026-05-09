
from app import app, db, CookedRecipe
from recipe_recommender import get_recommender
import pandas as pd

with app.app_context():
    recommender = get_recommender()
    print("Checking rating column types...")
    print(recommender.df['rating'].dtype)
    print(recommender.df['rating'].head())
    
    print("\nChecking CookedRecipe table...")
    try:
        count = CookedRecipe.query.count()
        print(f"CookedRecipe count: {count}")
    except Exception as e:
        print(f"Error querying CookedRecipe: {e}")

    print("\nTesting most_cooked_query...")
    from sqlalchemy import func
    try:
        q = db.session.query(
            CookedRecipe.recipe_id, 
            CookedRecipe.recipe_name,
            func.count(CookedRecipe.id).label('cook_count')
        ).group_by(CookedRecipe.recipe_id, CookedRecipe.recipe_name).order_by(func.count(CookedRecipe.id).desc()).limit(3).all()
        print(f"Query successful: {q}")
    except Exception as e:
        print(f"Query failed: {e}")
