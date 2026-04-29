import pandas as pd
import re

df = pd.read_csv('RECIPES.csv', encoding='utf-8-sig')

def clean_url(val):
    if pd.isna(val):
        return ''
    val = str(val).strip()
    # Extract URL from markdown format [url](url)
    match = re.search(r'\(https?://[^\)]+\)', val)
    if match:
        return match.group(0).strip('()')
    return val

df['image_url'] = df['image_url'].apply(clean_url)
df.to_csv('RECIPES.csv', index=False, encoding='utf-8-sig')
print("Done! Saved as RECIPES.csv")