from recipe_recommender import get_recommender
import pandas as pd

rec = get_recommender()
print("Columns:", rec.df.columns.tolist())
print("Sample cook_time values:")
print(rec.df['cook_time'].head())
print("Value counts:")
print(rec.df['cook_time'].value_counts())
