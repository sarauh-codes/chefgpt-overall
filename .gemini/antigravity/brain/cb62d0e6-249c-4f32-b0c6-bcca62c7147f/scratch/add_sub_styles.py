path = r'c:\Users\azree\chefgpt-overall\static\css\recipe.css'
with open(path, 'a', encoding='utf-8') as f:
    f.write("""
/* ===== Ingredient Substitution UI ===== */
.ingredient-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 4px;
}

.swap-btn {
    background: var(--panel-2);
    border: 1px solid var(--border);
    color: var(--brand);
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 20px;
    cursor: pointer;
    transition: all 0.2s;
    text-transform: lowercase;
}

.swap-btn:hover {
    background: var(--brand-soft);
    border-color: var(--brand);
}

.sub-result {
    font-size: 12px;
    display: inline-block;
}

.sub-list {
    color: #38A169;
    font-weight: 600;
}

.sub-item {
    background: rgba(56, 161, 105, 0.1);
    color: #2F855A;
    padding: 2px 8px;
    border-radius: 20px;
    font-size: 11px;
    margin: 0 2px;
    cursor: help;
}

.sub-none {
    color: var(--muted);
    font-size: 11px;
    font-style: italic;
}
""")
print("Substitution styles added to recipe.css")
