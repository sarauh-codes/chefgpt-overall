import requests
import pandas as pd
import time

PEXELS_KEY = "1qVl6KHPbeJzMVUYX39nuq2HsEmyimsG21kkZTo3wkjKbD9SXoRouP6R"
PLACEHOLDER = "https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg"

def fetch_pexels(query):
    while True:
        res = requests.get(
            "https://api.pexels.com/v1/search",
            params={"query": query, "per_page": 1},
            headers={"Authorization": PEXELS_KEY}
        )
        time.sleep(18)
        print(f"   Pexels [{query}] → status: {res.status_code}")
        if res.status_code == 429:
            print("   Rate limit hit! Waiting 60s...")
            time.sleep(60)
            continue
        if res.status_code != 200:
            print(f"   Pexels error: {res.text}")
            return None
        photos = res.json().get("photos", [])
        if photos:
            print(f"   ✅ Found!")
            return photos[0]["src"]["medium"]
        return None

def get_image(recipe_name, cuisine, ingredients):
    main_ingredient = ingredients.split(",")[0].strip()
    for query in [recipe_name, f"{cuisine} food", main_ingredient]:
        img = fetch_pexels(query)
        if img:
            return img
    print("   ⚠️ Nothing found, using placeholder.")
    return PLACEHOLDER

df = pd.read_csv("recipespalinglatest.csv")

if "image_url" not in df.columns:
    df["image_url"] = ""

df["image_url"] = df["image_url"].astype(str)
old_placeholder = "https://images.unsplash.com/photo-1504674900247-0877df9cc836"
df["image_url"] = df["image_url"].replace(old_placeholder, "")
df["image_url"] = df["image_url"].replace("nan", "")

for i, row in df.iterrows():
    if pd.notna(row["image_url"]) and str(row["image_url"]).strip() not in ("", "nan"):
        print(f"✅ Skipping (done): {row['recipe_name']}")
        continue

    print(f"\n🔍 Fetching: {row['recipe_name']}...")
    df.at[i, "image_url"] = get_image(
        row["recipe_name"], row["cuisine"], row["ingredients"]
    )
    df.to_csv("recipespalinglatest.csv", index=False)

print("\n🎉 Done!")