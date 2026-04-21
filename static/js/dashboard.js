let currentOffset = 12;
let displayedRecipeIds = new Set();
let searchTimeout;
let isSearching = false;
let originalRecipes = '';

// Wait 3 seconds, then hide all flash messages
document.addEventListener("DOMContentLoaded", () => {
    setTimeout(() => {
        const alerts = document.querySelectorAll('.alert');
        alerts.forEach(alert => {
            alert.classList.add('hide');

            // Remove from DOM after transition ends
            alert.addEventListener('transitionend', () => {
                alert.remove();
            });
        });
    }, 3000); // 3 seconds
});


// Track initial recipes
document.addEventListener('DOMContentLoaded', function() {
    const initialCards = document.querySelectorAll('.recipe-card');
    initialCards.forEach(card => {
        const link = card.querySelector('.view-recipe-btn');
        if (link) {
            const recipeId = link.href.split('/').pop();
            displayedRecipeIds.add(recipeId);
        }
    });
    
    const recipeCatalog = document.getElementById('recipe-catalog');
    originalRecipes = recipeCatalog.innerHTML;
});

// Search function
function searchRecipes() {
    const searchInput = document.getElementById('recipe-search').value.trim();
    const recipeCatalog = document.getElementById('recipe-catalog');
    const noResults = document.getElementById('no-results');
    const loadMoreContainer = document.getElementById('load-more-container');
    
    clearTimeout(searchTimeout);
    
    if (searchInput.length === 0) {
        isSearching = false;
        recipeCatalog.innerHTML = originalRecipes;
        recipeCatalog.style.display = 'grid';
        noResults.style.display = 'none';
        if (loadMoreContainer) loadMoreContainer.style.display = 'block';
        return;
    }
    
    isSearching = true;
    if (loadMoreContainer) loadMoreContainer.style.display = 'none';
    
    searchTimeout = setTimeout(async () => {
        try {
            const response = await fetch('/search-recipes?q=' + encodeURIComponent(searchInput));
            
            if (!response.ok) {
                throw new Error('Search failed');
            }
            
            const data = await response.json();
            
            recipeCatalog.innerHTML = '';
            
            if (data.recipes.length === 0) {
                recipeCatalog.style.display = 'none';
                noResults.style.display = 'block';
            } else {
                recipeCatalog.style.display = 'grid';
                noResults.style.display = 'none';
                
                data.recipes.forEach(recipe => {
                    const difficultyIcon = recipe.difficulty === 'easy' ? '✅' : recipe.difficulty === 'medium' ? '⚡' : '🔥';
                    const difficultyText = recipe.difficulty.charAt(0).toUpperCase() + recipe.difficulty.slice(1);
                    
                    const card = `
                        <div class="recipe-card">
                            <div class="recipe-header">
                                <h3>${recipe.recipe_name}</h3>
                            </div>
                            <div class="recipe-info">
                                <span class="info-tag">🍽️ ${recipe.cuisine}</span>
                                <span class="info-tag">🔥 ${recipe.calories} cal</span>
                                <span class="info-tag">⭐ ${recipe.rating}/5</span>
                                <span class="info-tag difficulty-${recipe.difficulty}">${difficultyIcon} ${difficultyText}</span>
                            </div>
                            <div class="ingredients-list">
                                <strong>Ingredients:</strong> ${recipe.ingredients}
                            </div>
                            <a href="/recipe/${recipe.recipe_id}" class="view-recipe-btn">View Full Recipe</a>
                        </div>
                    `;
                    recipeCatalog.insertAdjacentHTML('beforeend', card);
                });
            }
        } catch (error) {
            console.error('Search error:', error);
            recipeCatalog.innerHTML = '<p style="text-align:center; padding:40px;">Search failed. Please try again.</p>';
        }
    }, 300);
}

// Load more function
async function loadMoreRecipes() {
    if (isSearching) return;
    
    const btn = document.getElementById('load-more-btn');
    const catalog = document.getElementById('recipe-catalog');
    
    btn.disabled = true;
    btn.textContent = 'Loading...';
    
    try {
        const response = await fetch(`/load-more-recipes?offset=${currentOffset}`);
        const data = await response.json();
        
        if (data.recipes.length > 0) {
            let addedCount = 0;
            
            data.recipes.forEach(recipe => {
                if (displayedRecipeIds.has(String(recipe.recipe_id))) return;
                
                displayedRecipeIds.add(String(recipe.recipe_id));
                addedCount++;
                
                const difficultyIcon = recipe.difficulty === 'easy' ? '✅' : recipe.difficulty === 'medium' ? '⚡' : '🔥';
                const difficultyText = recipe.difficulty.charAt(0).toUpperCase() + recipe.difficulty.slice(1);
                
                const card = `
                    <div class="recipe-card">
                        <div class="recipe-header">
                            <h3>${recipe.recipe_name}</h3>
                        </div>
                        <div class="recipe-info">
                            <span class="info-tag">🍽️ ${recipe.cuisine}</span>
                            <span class="info-tag">🔥 ${recipe.calories} cal</span>
                            <span class="info-tag">⭐ ${recipe.rating}/5</span>
                            <span class="info-tag difficulty-${recipe.difficulty}">${difficultyIcon} ${difficultyText}</span>
                        </div>
                        <div class="ingredients-list">
                            <strong>Ingredients:</strong> ${recipe.ingredients}
                        </div>
                        <a href="/recipe/${recipe.recipe_id}" class="view-recipe-btn">View Full Recipe</a>
                    </div>
                `;
                catalog.insertAdjacentHTML('beforeend', card);
            });
            
            currentOffset += data.recipes.length;
            
            if (!data.has_more || addedCount === 0) {
                btn.style.display = 'none';
            }
        }
    } catch (error) {
        console.error('Error:', error);
        alert('Failed to load more recipes');
    } finally {
        btn.disabled = false;
        btn.textContent = 'Load More Recipes';
    }
}
// ==================== DIET DRAWER ====================

function openDietDrawer() {
    document.getElementById('diet-drawer').style.right = '0';
    document.getElementById('diet-overlay').style.display = 'block';
    renderTags('allergies', 'allergy-tags', '#ff6b6b', 'white');
    renderTags('forbidden_ingredients', 'forbidden-tags', '#fdcb6e', '#333');
    updateBorderColors();
}

function closeDietDrawer() {
    document.getElementById('diet-drawer').style.right = '-480px';
    document.getElementById('diet-overlay').style.display = 'none';
}

function renderTags(inputId, containerId, bgColor, textColor) {
    const input = document.getElementById(inputId);
    const container = document.getElementById(containerId);
    container.innerHTML = '';
    input.value.split(',').map(v => v.trim()).filter(v => v).forEach(val => {
        const tag = document.createElement('span');
        tag.textContent = val;
        tag.style.cssText = `background:${bgColor}; color:${textColor}; padding:4px 12px;
            border-radius:20px; font-size:12px; font-weight:500;`;
        container.appendChild(tag);
    });
}

function updateBorderColors() {
    document.querySelectorAll('#diet-drawer input[type=radio]').forEach(radio => {
        const label = radio.closest('label');
        label.style.borderColor = radio.checked ? '#667eea' : '#e0e0e0';
        label.style.background = radio.checked ? 'rgba(102,126,234,0.08)' : 'white';
    });
}

document.addEventListener('DOMContentLoaded', function () {

    // Radio button highlight on change
    document.querySelectorAll('#diet-drawer input[type=radio]').forEach(radio => {
        radio.addEventListener('change', updateBorderColors);
    });

    // Diet form submit via AJAX
    const dietForm = document.getElementById('diet-form');
    if (dietForm) {
        dietForm.addEventListener('submit', function (e) {
            e.preventDefault();
            const formData = new FormData(this);
            const alertBox = document.getElementById('drawer-alert');

            fetch('/diet-settings', {
                method: 'POST',
                body: formData
            }).then(res => {
                if (res.ok || res.redirected) {
                    alertBox.style.display = 'block';
                    alertBox.style.background = '#d4fc79';
                    alertBox.style.color = '#155724';
                    alertBox.textContent = '✅ Dietary settings saved successfully!';
                    setTimeout(() => {
                        closeDietDrawer();
                        location.reload();
                    }, 1200);
                }
            }).catch(() => {
                alertBox.style.display = 'block';
                alertBox.style.background = '#fab1a0';
                alertBox.style.color = '#721c24';
                alertBox.textContent = '❌ Something went wrong. Please try again.';
            });
        });
    }
});

// ==================== TASTE PROFILE ====================

const AXIS_COLORS = {
    Spicy:     "#e05d44",
    Sweet:     "#f0a500",
    Savory:    "#4f98a3",
    Healthy:   "#6daa45",
    Indulgent: "#bb65a0"
};
const AXIS_EMOJIS = {
    Spicy:"🌶️", Sweet:"🍬", Savory:"🧄", Healthy:"🥗", Indulgent:"🧁"
};

fetch("/api/taste-profile")
    .then(r => r.json())
    .then(data => {
        if (data.empty) {
            document.getElementById("tasteContent").classList.add("hidden");
            document.getElementById("tasteEmpty").classList.remove("hidden");
            return;
        }

        const ctx = document.getElementById("tasteRadar").getContext("2d");
        new Chart(ctx, {
            type: "radar",
            data: {
                labels: data.labels.map(l => `${AXIS_EMOJIS[l] || ""} ${l}`),
                datasets: [{
                    data: data.scores,
                    backgroundColor: "rgba(79,152,163,0.15)",
                    borderColor: "#4f98a3",
                    pointBackgroundColor: data.labels.map(l => AXIS_COLORS[l] || "#4f98a3"),
                    pointRadius: 5,
                    pointHoverRadius: 7,
                    borderWidth: 2,
                }]
            },
            options: {
                responsive: true,
                scales: {
                    r: {
                        min: 0, max: 100,
                        ticks: { display: false, stepSize: 25 },
                        pointLabels: {
                            font: { size: 13, weight: "600" },
                            color: "#333"
                        },
                        grid: { color: "rgba(0,0,0,0.08)" },
                        angleLines: { color: "rgba(0,0,0,0.08)" }
                    }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: { label: ctx => ` ${ctx.raw}%` }
                    }
                },
                animation: { duration: 800 }
            }
        });

        const barsEl = document.getElementById("tasteBars");
        data.labels.forEach((label, i) => {
            const color = AXIS_COLORS[label] || "#4f98a3";
            const row = document.createElement("div");
            row.className = "taste-bar-row";
            row.innerHTML = `
                <span class="taste-bar-label">${AXIS_EMOJIS[label] || ""} ${label}</span>
                <div class="taste-bar-track">
                    <div class="taste-bar-fill" style="width:${data.scores[i]}%; background:${color};"></div>
                </div>
                <span class="taste-bar-score" style="color:${color};">${data.scores[i]}%</span>
            `;
            barsEl.appendChild(row);
        });
    });