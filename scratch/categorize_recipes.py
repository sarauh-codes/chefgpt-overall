import csv
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "RECIPES.csv"

NEW_COLUMNS = ["cuisine_origin", "display_category", "category_confidence", "category_notes"]

NON_CUISINE_VALUES = {
    "beverages",
    "breakfast",
    "chicken breast",
    "dessert",
    "free of...",
    "frozen desserts",
    "one dish meal",
    "spreads",
    "toddler friendly",
    "trout",
    "very low carbs",
}

CUISINE_ALIASES = {
    "asian": "Asian",
    "asian-american": "Asian-American",
    "american": "American",
    "southern american": "American",
    "italian": "Italian",
    "italian-american": "Italian-American",
    "mexican": "Mexican",
    "mexican-american": "Mexican-American",
    "french/american": "French-American",
    "indian": "Indian",
    "thai": "Thai",
    "japanese": "Japanese",
    "chinese": "Chinese",
    "vietnamese": "Vietnamese",
    "filipino": "Filipino",
    "korean": "Korean",
    "malay": "Malay",
}

MALAY_TERMS = [
    "asam", "ayam", "bawal", "belacan", "bihun", "bubur", "cendol", "cili api",
    "cucur", "daging", "gulai", "ikan", "kari", "kerabu", "keria", "ketupat",
    "kicap", "kuih", "laksa", "lemak", "lodeh", "masak", "mee", "nasi",
    "onde", "patin", "percik", "petai", "pulut", "rendang", "roti canai",
    "sambal", "sardin", "singgang", "sotong", "soto", "sup tulang", "tempoyak",
    "terengganu", "kelantan", "udang",
]

CATEGORY_RULES = [
    ("Drinks", ["drink", "drinks", "beverage", "juice", "smoothie", "tea", "coffee", "sirap", "cendol"]),
    ("Kuih, Cakes & Desserts", [
        "kuih", "cake", "kek", "dessert", "pudding", "cookie", "cookies", "brownie",
        "pie", "tart", "muffin", "cheesecake", "ice cream", "custard", "akok",
        "bahulu", "ketayap", "keria", "lopes", "seri muka", "onde",
    ]),
    ("Breakfast & Tea-Time", [
        "breakfast", "pancake", "pancakes", "waffle", "waffles", "toast",
        "biscuit", "biscuits", "scone", "scones", "roti", "apam", "lepat",
        "cucur", "cekodok", "sandwich", "sandwiches",
    ]),
    ("Noodles & Pasta", [
        "mee", "mi ", "bihun", "laksa", "laksam", "noodle", "noodles", "pasta",
        "spaghetti", "fettuccine", "macaroni", "rotini", "penne", "lasagna",
    ]),
    ("Rice Dishes", ["nasi", "rice", "ketupat", "pulut", "biryani", "risotto", "paella"]),
    ("Soups & Broths", ["soup", "sup", "soto", "broth", "singgang", "pho", "tom yam"]),
    ("Curries, Gulai & Coconut Stews", [
        "curry", "kari", "gulai", "kurma", "rendang", "masak lemak", "lemak cili",
        "coconut stew",
    ]),
    ("Fish & Seafood", [
        "fish", "ikan", "salmon", "tuna", "cod", "trout", "prawn", "shrimp", "udang",
        "sotong", "squid", "crab", "ketam", "clam", "mussel", "seafood", "bawal",
        "tenggiri", "patin", "kembung", "siakap",
    ]),
    ("Sambal & Spicy Dishes", ["sambal", "berlado", "berlada", "chili", "chilli", "pedas"]),
    ("Chicken Dishes", ["chicken", "ayam", "turkey"]),
    ("Beef & Lamb Dishes", ["beef", "daging", "lamb", "mutton", "steak", "tulang"]),
    ("Vegetables & Vegetarian", [
        "vegetable", "vegetarian", "veggie", "salad", "sayur", "kangkung", "sawi",
        "kailan", "cabbage", "spinach", "mushroom", "cendawan", "tofu", "tempeh",
        "lentil", "bean",
    ]),
]

FULL_TEXT_CATEGORY_RULES = [
    (category, [term for term in terms if term not in {"juice", "tea", "coffee"}])
    for category, terms in CATEGORY_RULES
]


def normalize_text(value):
    return re.sub(r"\s+", " ", str(value or "").lower()).strip()


def contains_any(text, terms):
    padded = f" {text} "
    for term in terms:
        term = normalize_text(term)
        if " " in term:
            if term in text:
                return term
        elif re.search(rf"\b{re.escape(term)}\b", padded):
            return term
    return None


def infer_cuisine_origin(name, cuisine):
    name_text = normalize_text(name)
    cuisine_text = normalize_text(cuisine)

    malay_match = contains_any(name_text, MALAY_TERMS)
    if cuisine_text == "malay" or malay_match:
        return "Malay", "high" if cuisine_text == "malay" else "medium", (
            "existing Malay cuisine" if cuisine_text == "malay" else f"matched Malaysian term: {malay_match}"
        )

    if cuisine_text in NON_CUISINE_VALUES or not cuisine_text:
        return "Global / Other", "low", f"non-cuisine value in original cuisine: {cuisine or 'blank'}"

    return CUISINE_ALIASES.get(cuisine_text, str(cuisine).strip()), "high", "used existing cuisine value"


def infer_display_category(row):
    name = normalize_text(row.get("recipe_name"))
    ingredients = normalize_text(row.get("ingredients"))
    cuisine = normalize_text(row.get("cuisine"))

    for category, terms in CATEGORY_RULES:
        matched = contains_any(f"{name} {cuisine}", terms)
        if matched:
            return category, "high", f"matched name/cuisine keyword: {matched}"

    text = f"{ingredients} {cuisine}"
    for category, terms in FULL_TEXT_CATEGORY_RULES:
        matched = contains_any(text, terms)
        if matched:
            return category, "medium", f"matched ingredient/cuisine keyword: {matched}"

    return "Western & Global", "low", "fallback category"


def main():
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        rows = list(reader)
        existing_fields = reader.fieldnames or []

    fieldnames = [field for field in existing_fields if field not in NEW_COLUMNS]
    insert_after = fieldnames.index("cuisine") + 1 if "cuisine" in fieldnames else len(fieldnames)
    fieldnames = fieldnames[:insert_after] + NEW_COLUMNS + fieldnames[insert_after:]

    for row in rows:
        cuisine_origin, cuisine_confidence, cuisine_note = infer_cuisine_origin(
            row.get("recipe_name"), row.get("cuisine")
        )
        display_category, category_confidence, category_note = infer_display_category(row)
        confidence = "high" if cuisine_confidence == "high" and category_confidence == "high" else (
            "medium" if "medium" in {cuisine_confidence, category_confidence} else "low"
        )

        row["cuisine_origin"] = cuisine_origin
        row["display_category"] = display_category
        row["category_confidence"] = confidence
        row["category_notes"] = f"{cuisine_note}; {category_note}"

    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    print(f"Updated {CSV_PATH.name} with {len(rows)} categorized recipes.")


if __name__ == "__main__":
    main()
