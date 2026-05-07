const rotatingPrompts = [
    "Find recipes using chicken and rice...",
    "Plan a healthy dinner for tonight...",
    "What can I cook with eggs?",
    "Suggest a quick halal meal...",
    "Make something spicy and cheap...",
    "Use my leftovers creatively..."
];

let promptIndex = 0;
let charIndex = 0;
let deleting = false;

function typePrompt() {
    const input = document.getElementById("dashChatInput");
    if (!input) return;

    if (document.activeElement === input && input.value.trim() !== "") {
        setTimeout(typePrompt, 800);
        return;
    }

    const currentPrompt = rotatingPrompts[promptIndex];

    if (!deleting) {
        charIndex++;
        input.setAttribute("placeholder", currentPrompt.substring(0, charIndex));

        if (charIndex === currentPrompt.length) {
            deleting = true;
            setTimeout(typePrompt, 900);
            return;
        }
    } else {
        charIndex--;
        input.setAttribute("placeholder", currentPrompt.substring(0, charIndex));

        if (charIndex === 0) {
            deleting = false;
            promptIndex++;

            if (promptIndex >= rotatingPrompts.length) {
                promptIndex = 0;
            }
        }
    }

    const speed = deleting ? 18 : 28;
    setTimeout(typePrompt, speed);
}

window.addEventListener("load", typePrompt);
document.addEventListener('DOMContentLoaded', function () {
    const input = document.getElementById('dashChatInput');
    if (input) {
        input.addEventListener('keydown', function (e) {
            if (e.key === 'Tab') {
                e.preventDefault();
                const placeholder = this.getAttribute('placeholder');
                if (placeholder) {
                    this.value = placeholder.replace('...', '').trim();
                }
            }
        });
    }
});


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


function escapeHtml(s) {
    return String(s ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function safeAttr(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function hasRecipeImage(url) {
    const u = String(url ?? '').trim().toLowerCase();
    return u.length > 0 && u !== 'nan' && u !== 'none';
}

// Helper to build a premium recipe card HTML
function createRecipeCardHtml(recipe) {
    const difficultyIcon = recipe.difficulty === 'easy' ? '✅' : recipe.difficulty === 'medium' ? '⚡' : '🔥';
    const cookTime = recipe.cook_time != null ? String(recipe.cook_time) : '30';
    
    const imgInner = hasRecipeImage(recipe.image_url)
        ? `<img src="${safeAttr(recipe.image_url)}" alt="${safeAttr(recipe.recipe_name)}" loading="lazy" onerror="this.parentElement.innerHTML='<div class=\'recipe-img-placeholder\'>🍽️</div>'">`
        : `<div class="recipe-img-placeholder">🍽️</div>`;

    return `
        <div class="recipe-card">
            <div class="recipe-card-img">
                ${imgInner}
                <div class="recipe-time-badge">⏱ ${escapeHtml(cookTime)} min</div>
            </div>
            <div class="recipe-card-body">
                <div class="recipe-card-name">${escapeHtml(recipe.recipe_name)}</div>
                <div class="recipe-card-meta">${escapeHtml(recipe.cuisine)} · ${escapeHtml(String(recipe.calories))} cal</div>
                <div class="recipe-card-footer">
                    <span class="recipe-rating">⭐ ${escapeHtml(String(recipe.rating))}</span>
                    <a href="/recipe/${recipe.recipe_id}" class="recipe-view-btn">View</a>
                </div>
            </div>
        </div>
    `;
}

// Track initial recipes
document.addEventListener('DOMContentLoaded', function () {
    const initialCards = document.querySelectorAll('.recipe-card');
    initialCards.forEach(card => {
        const link = card.querySelector('a.recipe-view-btn');
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
                    recipeCatalog.insertAdjacentHTML('beforeend', createRecipeCardHtml(recipe));
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
                catalog.insertAdjacentHTML('beforeend', createRecipeCardHtml(recipe));
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
    Spicy: "#e05d44",
    Sweet: "#f0a500",
    Savory: "#4f98a3",
    Healthy: "#6daa45",
    Indulgent: "#bb65a0"
};
const AXIS_EMOJIS = {
    Spicy: "🌶️", Sweet: "🍬", Savory: "🧄", Healthy: "🥗", Indulgent: "🧁"
};


// ==================== TASTE DRAWER ====================

function openTasteDrawer() {
    document.getElementById('taste-drawer').style.right = '0';
    document.getElementById('taste-overlay').style.display = 'block';
    renderTasteDrawer();
}

function closeTasteDrawer() {
    document.getElementById('taste-drawer').style.right = '-480px';
    document.getElementById('taste-overlay').style.display = 'none';
}

function renderTasteDrawer() {
    fetch("/api/taste-profile")
        .then(r => r.json())
        .then(data => {
            if (data.empty) {
                document.getElementById("tasteEmptyDrawer").style.display = 'block';
                document.getElementById("tasteContentDrawer").style.display = 'none';
                return;
            }

            document.getElementById("tasteEmptyDrawer").style.display = 'none';
            document.getElementById("tasteContentDrawer").style.display = 'block';

            // Destroy chart lama kalau ada
            const old = Chart.getChart('tasteRadarDrawer');
            if (old) old.destroy();

            // Render radar chart
            const ctx = document.getElementById("tasteRadarDrawer").getContext("2d");
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
                    maintainAspectRatio: true,
                    aspectRatio: 1.2,
                    scales: {
                        r: {
                            min: 0, max: 100,
                            ticks: { display: false, stepSize: 20 },
                            pointLabels: { font: { size: 12, weight: "600" }, color: "#333" },
                            grid: { color: "rgba(0,0,0,0.25)" },
                            angleLines: { color: "rgba(0,0,0,0.25)" }
                        }
                    },
                    plugins: { legend: { display: false } },
                    animation: { duration: 800 }
                }
            });

            // Render bars
            const barsEl = document.getElementById("tasteBarsDrawer");
            barsEl.innerHTML = '';
            data.labels.forEach((label, i) => {
                const color = AXIS_COLORS[label] || "#4f98a3";
                barsEl.innerHTML += `
                    <div style="margin-bottom:12px;">
                        <div style="display:flex; justify-content:space-between; margin-bottom:4px;">
                            <span style="font-size:13px; font-weight:600;">${AXIS_EMOJIS[label] || ""} ${label}</span>
                            <span style="font-size:13px; color:${color}; font-weight:600;">${data.scores[i]}%</span>
                        </div>
                        <div style="background:#f0f0f0; border-radius:99px; height:8px;">
                            <div style="background:${color}; height:8px; border-radius:99px;
                                        width:${data.scores[i]}%; transition:width 0.5s ease;"></div>
                        </div>
                    </div>`;
            });
        });
}
// ==================== CHAT WITH CHEFGPT ====================
async function sendMessage(source = 'floating') {
    // Identify if the request is coming from the Hero (Center) section
    const isHero = (source === 'hero');

    // Select the appropriate input field based on the source
    const input = document.getElementById(isHero ? 'dashChatInput' : 'chat-input');

    // Select the appropriate message container based on the source
    const messages = document.getElementById(isHero ? 'hero-chat-messages' : 'chat-messages');

    // Sanitize user input by trimming whitespace
    const text = input.value.trim();
    if (!text) return;

    // If using the Hero section, hide the dashboard header to focus on the conversation
    if (isHero) {
        const header = document.getElementById('hero-header-text');
        if (header) header.style.display = 'none';
        const section = document.getElementById('hero-section');
        if (section) section.style.paddingTop = '20px';
    }

    // Create and display the User's message bubble
    const userRow = document.createElement('div');
    userRow.style.cssText = 'display:flex; justify-content:flex-end; margin-bottom:12px;';
    userRow.innerHTML = `<div style="background:linear-gradient(135deg,#ff6b35,#f7931e);
        color:white; padding:10px 14px; border-radius:14px; border-bottom-right-radius:4px;
        font-size:13px; max-width:75%;">${text}</div>`;
    messages.appendChild(userRow);

    // Reset input field and disable it while waiting for the AI response
    input.value = '';
    input.disabled = true;
    messages.scrollTop = messages.scrollHeight;

    // Create a temporary 'Thinking' indicator for visual feedback
    const typingId = 'typing-' + Date.now();
    const typing = document.createElement('div');
    typing.id = typingId;
    typing.style.cssText = 'color:#aaa; font-size:12px; font-style:italic; padding:4px 8px;';
    typing.textContent = '⏳ ChefGPT is thinking...';
    messages.appendChild(typing);

    try {
        // Send the user message to the backend API
        const res = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ message: text })
        });
        const data = await res.json();

        // Remove the 'Thinking' indicator once the response is received
        document.getElementById(typingId).remove();

        // Create and display the AI Bot response bubble
        const aiRow = document.createElement('div');
        aiRow.style.cssText = 'display:flex; align-items:flex-end; gap:8px; margin-bottom:12px;';
        aiRow.innerHTML = `
            <div style="width:26px; height:26px; background:linear-gradient(135deg,#ff6b35,#f7931e);
                border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:12px; flex-shrink:0;">🍳</div>
            <div style="background:#2e2e2e; padding:10px 14px; border-radius:14px; border-bottom-left-radius:4px;
    font-size:13px; max-width:75%; color:#f0f0f0; line-height:1.4;">${data.reply}</div>`;
        messages.appendChild(aiRow);
        // scroll to show reply
        messages.scrollTop = messages.scrollHeight;

    } catch (e) {
        const typingEl = document.getElementById(typingId);
        // Handle connection errors gracefully
        if (typingEl) typingEl.textContent = 'Oops! Something went wrong 😅';
    }

    // Re-enable input and return focus to the user
    input.disabled = false;
    input.focus();
    messages.scrollTop = messages.scrollHeight;
}
function applyTheme(theme) {
    const icon = document.getElementById("themeIcon");
    const text = document.getElementById("themeText");

    if (theme === "dark") {
        document.body.classList.add("dark-theme");
        if (icon) icon.textContent = "🌙";
        if (text) text.textContent = "Dark";
    } else {
        document.body.classList.remove("dark-theme");
        if (icon) icon.textContent = "☀️";
        if (text) text.textContent = "Light";
    }

    localStorage.setItem("theme", theme);
}

function toggleTheme() {
    const isDark = document.body.classList.contains("dark-theme");
    applyTheme(isDark ? "light" : "dark");
}

window.addEventListener("load", () => {
    const savedTheme = localStorage.getItem("theme");

    if (savedTheme) {
        applyTheme(savedTheme);
        return;
    }

    const systemDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    applyTheme(systemDark ? "dark" : "light");
});

// ==================== TOAST NOTIFICATIONS ====================
function showToast(message, type = 'success') {
    let container = document.getElementById('toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        container.style.cssText = 'position: fixed; bottom: 30px; right: 30px; display: flex; flex-direction: column; gap: 10px; z-index: 9999; pointer-events: none;';
        document.body.appendChild(container);
    }

    const toast = document.createElement('div');

    // Style based on type
    const isDarkTheme = document.body.classList.contains('dark-theme');

    // Make toasts look great in both light and dark modes
    const bgColor = type === 'success' ? '#1a3a2a' : '#3a1a1a';
    const textColor = type === 'success' ? '#68d391' : '#fc8181';
    const borderColor = type === 'success' ? '#276749' : '#9b2c2c';

    toast.style.cssText = `
        background: ${bgColor};
        color: ${textColor};
        border: 1px solid ${borderColor};
        padding: 16px 24px;
        border-radius: 12px;
        font-size: 14px;
        font-weight: 600;
        box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        transform: translateY(50px) scale(0.9);
        opacity: 0;
        transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
        pointer-events: auto;
    `;

    toast.textContent = message;
    container.appendChild(toast);

    // Animate in
    requestAnimationFrame(() => {
        toast.style.transform = 'translateY(0) scale(1)';
        toast.style.opacity = '1';
    });

    // Animate out and remove
    setTimeout(() => {
        toast.style.transform = 'translateY(20px) scale(0.9)';
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 400);
    }, 3000);
}
