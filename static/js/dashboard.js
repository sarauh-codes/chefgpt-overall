// ==================== LANGUAGE SWITCHER ====================

const LANG_KEY = 'chefgpt_lang';

function getLanguage() {
    return localStorage.getItem(LANG_KEY) || 'en';
}

function setLanguage(lang) {
    localStorage.setItem(LANG_KEY, lang);
    _updateLangUI(lang);
    closeLangDropdown();

    // If we are currently on a recipe or cooking page, apply or revert translations
    if (typeof applyPageLanguage === 'function') {
        applyPageLanguage(lang);
    }
}

function _updateLangUI(lang) {
    const flagEl   = document.getElementById('langFlag');
    const labelEl  = document.getElementById('langLabel');
    const checkEn  = document.getElementById('checkEn');
    const checkMs  = document.getElementById('checkMs');

    if (!flagEl) return; // topbar not rendered on this page

    if (lang === 'ms') {
        flagEl.textContent  = '🇲🇾';
        labelEl.textContent = 'BM';
        if (checkEn) checkEn.style.display = 'none';
        if (checkMs) checkMs.style.display = 'inline';
    } else {
        flagEl.textContent  = '🌐';
        labelEl.textContent = 'EN';
        if (checkEn) checkEn.style.display = 'inline';
        if (checkMs) checkMs.style.display = 'none';
    }
}

function toggleLangDropdown() {
    const dropdown = document.getElementById('langDropdown');
    const btn      = document.getElementById('langToggleBtn');
    if (!dropdown || !btn) return;

    if (dropdown.classList.contains('open')) {
        dropdown.classList.remove('open');
        return;
    }

    // Position the fixed dropdown just below the button
    const rect = btn.getBoundingClientRect();
    dropdown.style.top   = (rect.bottom + 8) + 'px';
    dropdown.style.right = (window.innerWidth - rect.right) + 'px';
    dropdown.classList.add('open');
}

function closeLangDropdown() {
    const dropdown = document.getElementById('langDropdown');
    if (dropdown) dropdown.classList.remove('open');
}

// Close dropdown when clicking outside
document.addEventListener('click', function(e) {
    const switcher = document.getElementById('langSwitcher');
    if (switcher && !switcher.contains(e.target)) {
        closeLangDropdown();
    }
});

// Init UI label on every page load
document.addEventListener('DOMContentLoaded', function() {
    _updateLangUI(getLanguage());
});

// ==================== END LANGUAGE SWITCHER ====================

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
            setTimeout(typePrompt, 1500); // Wait longer at the end
            return;
        }
    } else {
        charIndex--;
        input.setAttribute("placeholder", currentPrompt.substring(0, charIndex));

        if (charIndex === 0) {
            deleting = false;
            promptIndex = (promptIndex + 1) % rotatingPrompts.length;
            setTimeout(typePrompt, 500); // Brief pause before next
            return;
        }
    }

    const speed = deleting ? 20 : 40;
    setTimeout(typePrompt, speed);
}

document.addEventListener("DOMContentLoaded", typePrompt);
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
let currentAiSuggestions = []; // Store AI results for quick view
let searchController = null; // To abort previous requests

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
    const u = String(url ?? '').trim();
    return u.length > 0 && u.toLowerCase() !== 'nan' && u.toLowerCase() !== 'none' && u !== 'AI_PLACEHOLDER';
}

// Helper to build a premium recipe card HTML
function createRecipeCardHtml(recipe) {
    const difficultyIcon = recipe.difficulty === 'easy' ? '✅' : recipe.difficulty === 'medium' ? '⚡' : '🔥';
    const cookTime = recipe.cook_time != null ? String(recipe.cook_time) : '30';

    const imgInner = (hasRecipeImage(recipe.image_url) && !recipe.is_ai)
        ? `<img src="${safeAttr(recipe.image_url)}" alt="${safeAttr(recipe.recipe_name)}" loading="lazy" onerror="this.parentElement.innerHTML='<div class=\'recipe-img-placeholder\'>🍽️</div>'">`
        : `<div class="recipe-img-placeholder"></div>`;

    const servings = recipe.servings != null ? recipe.servings : (() => {
        const cal = parseInt(recipe.calories) || 0;
        if (cal >= 700) return 4;
        if (cal >= 500) return 3;
        if (cal >= 300) return 2;
        const rId = parseInt(recipe.recipe_id) || 1;
        return (rId % 3) + 2;
    })();

    return `
        <div class="recipe-card ${recipe.is_ai ? 'ai-suggestion-card' : ''}">
            ${recipe.is_ai ? '<div class="ai-badge">AI Suggested</div>' : ''}
            <div class="recipe-card-img">
                ${imgInner}
                <div class="recipe-time-badge">⏱ ${escapeHtml(cookTime)} min</div>
            </div>
            <div class="recipe-card-body">
                <div class="recipe-card-name">${escapeHtml(recipe.recipe_name)}</div>
                <div class="recipe-card-meta">${escapeHtml(recipe.cuisine)} ${recipe.calories !== '---' ? '· ' + escapeHtml(String(recipe.calories)) + ' cal' : ''} · 👥 ${servings} portions</div>
                <div class="recipe-card-footer">
                    <span class="recipe-rating">⭐ ${escapeHtml(String(recipe.rating))}</span>
                    ${recipe.is_ai
            ? `<button onclick="viewAiRecipe('${recipe.recipe_id}')" class="recipe-view-btn" id="btn-${recipe.recipe_id}">View</button>`
            : `<a href="/recipe/${recipe.recipe_id}" class="recipe-view-btn">View</a>`}
                </div>
            </div>
        </div>
    `;
}

function createChatRecipeCardHtml(recipe) {
    const cookTime = recipe.cook_time != null ? String(recipe.cook_time) : '30';
    const imgInner = hasRecipeImage(recipe.image_url)
        ? `<img src="${safeAttr(recipe.image_url)}" alt="${safeAttr(recipe.recipe_name)}" style="width: 80px; height: 80px; object-fit: cover; border-radius: 8px;" onerror="this.parentElement.innerHTML='<div class=\'recipe-img-placeholder\' style=\'width:80px;height:80px;font-size:24px;\'>🍽️</div>'">`
        : `<div class="recipe-img-placeholder" style="width:80px; height:80px; font-size:24px;">🍽️</div>`;

    return `
        <div class="chat-recipe-card" onclick="window.location.href='/recipe/${recipe.recipe_id}'" style="display: flex; gap: 12px; background: rgba(255,255,255,0.05); padding: 10px; border-radius: 12px; cursor: pointer; border: 1px solid rgba(255,255,255,0.1); margin-bottom: 8px; transition: all 0.2s;">
            <div class="chat-recipe-img" style="flex-shrink: 0;">
                ${imgInner}
            </div>
            <div class="chat-recipe-info" style="flex-grow: 1; overflow: hidden;">
                <div style="font-weight: 600; font-size: 14px; color: #fff; margin-bottom: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHtml(recipe.recipe_name)}</div>
                <div style="font-size: 12px; color: #aaa; margin-bottom: 6px;">${escapeHtml(recipe.cuisine)} · ${escapeHtml(String(recipe.calories))} cal · ⭐ ${escapeHtml(String(recipe.rating))}</div>
                <div style="font-size: 11px; display: flex; align-items: center; gap: 4px; color: #ff6b35; font-weight: 600;">
                    <span>View Recipe</span>
                    <span style="font-size: 14px;">→</span>
                </div>
            </div>
        </div>
    `;
}

// Track initial recipes
const DASHBOARD_SEARCH_KEY = 'chefgpt_dashboard_recipe_search';
const DASHBOARD_SCROLL_KEY = 'chefgpt_dashboard_scroll_y';
const DASHBOARD_FROM_RECIPE = 'chefgpt_came_from_recipe';

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
    const searchBox = document.getElementById('recipe-search');
    
    if (recipeCatalog) {
        originalRecipes = recipeCatalog.innerHTML;

        // Only restore search if user is coming BACK from a recipe detail page
        const cameFromRecipe = sessionStorage.getItem(DASHBOARD_FROM_RECIPE);
        const savedSearch = sessionStorage.getItem(DASHBOARD_SEARCH_KEY);

        if (cameFromRecipe && searchBox && savedSearch) {
            searchBox.value = savedSearch;
            searchRecipes(true);
        }

        // Clear the flag so next fresh visit starts clean
        sessionStorage.removeItem(DASHBOARD_FROM_RECIPE);

        // Save search + scroll and set flag when clicking View on any recipe (regular or AI)
        recipeCatalog.addEventListener('click', function (event) {
            const viewLink = event.target.closest('.recipe-view-btn');
            if (!viewLink) return;

            if (searchBox) {
                sessionStorage.setItem(DASHBOARD_SEARCH_KEY, searchBox.value.trim());
            }
            sessionStorage.setItem(DASHBOARD_SCROLL_KEY, String(window.scrollY));
            sessionStorage.setItem(DASHBOARD_FROM_RECIPE, '1');
        });
    }
});

// Search function
function searchRecipes(restoreScroll = false) {
    const searchInput = document.getElementById('recipe-search').value.trim();
    const recipeCatalog = document.getElementById('recipe-catalog');
    const noResults = document.getElementById('no-results');
    const loadMoreContainer = document.getElementById('load-more-container');

    clearTimeout(searchTimeout);

    if (searchInput.length === 0) {
        sessionStorage.removeItem(DASHBOARD_SEARCH_KEY);
        isSearching = false;
        recipeCatalog.innerHTML = originalRecipes;
        recipeCatalog.style.display = 'grid';
        noResults.style.display = 'none';
        if (loadMoreContainer) loadMoreContainer.style.display = 'block';
        return;
    }

    // Save search immediately so browser back keeps same result state
    sessionStorage.setItem(DASHBOARD_SEARCH_KEY, searchInput);

    // Show loader IMMEDIATELY on first keystroke if not already visible
    if (!recipeCatalog.querySelector('.pan-loader-container')) {
        recipeCatalog.innerHTML = `
            <div class="pan-loader-container">
                <div class="pan-loader">
                    <div class="loader-food"></div>
                    <div class="loader-pan-container">
                        <div class="loader-pan"></div>
                        <div class="loader-handle"></div>
                    </div>
                </div>
                <div class="loader-text">ChefGPT is cooking</div>
            </div>
        `;
    }
    noResults.style.display = 'none';

    searchTimeout = setTimeout(async () => {
        // Abort previous request if it's still running
        if (searchController) {
            searchController.abort();
        }
        searchController = new AbortController();
        const signal = searchController.signal;

        try {
            // STEP 1: Fetch local results (Instant)
            const response = await fetch('/search-recipes?q=' + encodeURIComponent(searchInput), { signal });
            if (!response.ok) throw new Error('Search failed');
            const data = await response.json();

            // Only clear and show if this is still the active search
            if (signal.aborted) return;

            recipeCatalog.innerHTML = '';
            const hasRecipes = data.recipes && data.recipes.length > 0;

            if (hasRecipes) {
                recipeCatalog.style.display = 'grid';
                noResults.style.display = 'none';
                data.recipes.forEach(recipe => {
                    recipeCatalog.insertAdjacentHTML('beforeend', createRecipeCardHtml(recipe));
                });
            } else if (!data.trigger_ai) {
                // Truly no results and AI won't run
                recipeCatalog.style.display = 'none';
                noResults.style.display = 'block';
            }

            // STEP 2: Trigger AI suggestions
            if (data.trigger_ai) {
                const loaderContainer = document.createElement('div');
                loaderContainer.id = 'ai-loader-wrap';
                loaderContainer.style.cssText = 'grid-column: 1 / -1; margin-top: 40px;';
                loaderContainer.innerHTML = `
                    <div class="pan-loader-container" style="padding: 20px 0;">
                        <div class="pan-loader" style="transform: scale(0.6);">
                            <div class="loader-food"></div>
                            <div class="loader-pan-container">
                                <div class="loader-pan"></div>
                                <div class="loader-handle"></div>
                            </div>
                        </div>
                        <div class="loader-text" style="font-size: 11px; opacity: 0.8;">ChefGPT is thinking of more ideas</div>
                    </div>
                `;
                recipeCatalog.appendChild(loaderContainer);
                recipeCatalog.style.display = 'grid';
                noResults.style.display = 'none';

                try {
                    const aiRes = await fetch('/api/ai-search-suggestions?q=' + encodeURIComponent(searchInput), { signal });
                    if (signal.aborted) return;
                    const aiData = await aiRes.json();
                    
                    loaderContainer.remove();

                    if (aiData.suggestions && aiData.suggestions.length > 0) {
                        currentAiSuggestions = aiData.suggestions;
                        const divider = document.createElement('div');
                        divider.style.cssText = 'grid-column: 1 / -1; margin: 40px 0 20px; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 20px;';
                        divider.innerHTML = '<h3 style="color: #8b5cf6; font-size: 1.1rem; display: flex; align-items: center; gap: 8px;">✨ ChefGPT\'s Creative Ideas</h3>';
                        recipeCatalog.appendChild(divider);

                        aiData.suggestions.forEach(recipe => {
                            recipeCatalog.insertAdjacentHTML('beforeend', createRecipeCardHtml(recipe));
                        });
                    } else if (!hasRecipes) {
                        recipeCatalog.style.display = 'none';
                        noResults.style.display = 'block';
                    }
                } catch (aiErr) {
                    if (aiErr.name === 'AbortError') return;
                    loaderContainer.remove();
                    if (!hasRecipes) {
                        recipeCatalog.style.display = 'none';
                        noResults.style.display = 'block';
                    }
                }
            }
        } catch (error) {
            if (error.name === 'AbortError') return;
            console.error('Search error:', error);
            recipeCatalog.innerHTML = '<p style="text-align:center; padding:40px;">Search failed. Please try again.</p>';
        }
    }, restoreScroll ? 0 : 300);
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
        label.style.borderColor = radio.checked ? 'var(--brand)' : 'var(--border)';
        label.style.background = radio.checked ? 'var(--brand-soft)' : 'var(--panel)';
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
            const isDark = document.body.classList.contains('dark-theme');
            const labelColor = isDark ? "#f0f0f0" : "#333333";
            const gridColor = isDark ? "rgba(255,255,255,0.15)" : "rgba(0,0,0,0.15)";
            const angleColor = isDark ? "rgba(255,255,255,0.15)" : "rgba(0,0,0,0.15)";

            new Chart(ctx, {
                type: "radar",
                data: {
                    labels: data.labels.map(l => `${AXIS_EMOJIS[l] || ""} ${l}`),
                    datasets: [{
                        data: data.scores,
                        backgroundColor: isDark ? "rgba(255,107,53,0.15)" : "rgba(79,152,163,0.15)",
                        borderColor: isDark ? "#FF6B35" : "#4f98a3",
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
                            pointLabels: { font: { size: 12, weight: "600" }, color: labelColor },
                            grid: { color: gridColor },
                            angleLines: { color: angleColor }
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
                        <div style="background:var(--panel-2); border-radius:99px; height:8px;">
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

    const typingId = 'typing-' + Date.now();
    const typing = document.createElement('div');
    typing.id = typingId;
    typing.style.cssText = 'color:#aaa; font-size:12px; font-style:italic; padding:4px 8px;';
    typing.textContent = '⏳ ChefGPT is thinking...';
    messages.appendChild(typing);

    try {
        const res = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ message: text })
        });
        if (!res.ok) {
            const errorData = await res.json().catch(() => ({}));
            throw new Error(errorData.error || 'Chat request failed');
        }
        const data = await res.json();

        if (document.getElementById(typingId)) document.getElementById(typingId).remove();

        const aiRow = document.createElement('div');
        aiRow.style.cssText = 'display:flex; align-items:flex-end; gap:8px; margin-bottom:12px;';
        aiRow.innerHTML = `
            <div style="width:26px; height:26px; background:linear-gradient(135deg,#ff6b35,#f7931e);
                border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:12px; flex-shrink:0;">🍳</div>
            <div style="background:#2e2e2e; padding:10px 14px; border-radius:14px; border-bottom-left-radius:4px;
                font-size:13px; max-width:75%; color:#f0f0f0; line-height:1.4;">${data.reply}</div>`;
        messages.appendChild(aiRow);

        messages.scrollTop = messages.scrollHeight;
    } catch (e) {
        console.error('Chat request failed:', e);
        const typingEl = document.getElementById(typingId);
        if (typingEl) typingEl.textContent = 'Oops! Something went wrong 😅';
    }

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

// ==================== AI MODAL ====================

function openAiModal(recipeId) {
    const recipe = currentAiSuggestions.find(r => r.recipe_id === recipeId);
    if (!recipe) return;

    document.getElementById('ai-modal-title').textContent = recipe.recipe_name;
    const content = document.getElementById('ai-modal-content');

    content.innerHTML = `
        <div style="margin-bottom: 24px; color: #aaa; font-style: italic; line-height: 1.6;">
            ${escapeHtml(recipe.description)}
        </div>
        
        <div style="margin-bottom: 24px;">
            <h3 style="color: #ff6b35; font-size: 1rem; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                🥗 Ingredients
            </h3>
            <div style="background: rgba(255,255,255,0.05); padding: 16px; border-radius: 12px; color: #eee; line-height: 1.6;">
                ${recipe.ingredients.split(',').map(i => `• ${i.trim()}`).join('<br>')}
            </div>
        </div>

        <div>
            <h3 style="color: #ff6b35; font-size: 1rem; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                🔥 Instructions
            </h3>
            <div style="color: #eee; line-height: 1.8;">
                ${recipe.instructions.replace(/\n/g, '<br>')}
            </div>
        </div>

        <div style="margin-top: 32px; padding: 16px; background: rgba(255,107,53,0.1); border-radius: 12px; border: 1px dashed #ff6b35; color: #ff6b35; font-size: 12px; text-align: center;">
            Note: This is an AI-generated idea and is not currently saved in your permanent database.
        </div>
    `;

    document.getElementById('ai-modal-overlay').style.display = 'block';
    document.getElementById('ai-drawer').style.right = '0';
}

function closeAiModal() {
    document.getElementById('ai-modal-overlay').style.display = 'none';
    document.getElementById('ai-drawer').style.right = '-520px';
}

async function viewAiRecipe(tempId) {
    const recipe = currentAiSuggestions.find(r => r.recipe_id === tempId);
    if (!recipe) return;

    const btn = document.getElementById(`btn-${tempId}`);
    if (btn) {
        btn.disabled = true;
        btn.textContent = 'Saving...';
    }

    // Prepare session storage so 'Back' works
    const searchBox = document.getElementById('recipe-search');
    if (searchBox) {
        sessionStorage.setItem(DASHBOARD_SEARCH_KEY, searchBox.value.trim());
    }
    sessionStorage.setItem(DASHBOARD_SCROLL_KEY, String(window.scrollY));
    sessionStorage.setItem(DASHBOARD_FROM_RECIPE, '1');

    try {
        const res = await fetch('/api/confirm-ai-recipe', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(recipe)
        });
        const data = await res.json();

        if (data.recipe_id) {
            window.location.href = `/recipe/${data.recipe_id}`;
        } else {
            alert('Could not save AI recipe. Please try again.');
            if (btn) {
                btn.disabled = false;
                btn.textContent = 'View';
            }
        }
    } catch (e) {
        console.error(e);
        alert('An error occurred while saving the recipe.');
        if (btn) {
            btn.disabled = false;
            btn.textContent = 'View';
        }
    }
}

// ==================== ANALYTICS DRAWER ====================

function openAnalyticsDrawer() {
    document.getElementById('analytics-drawer').style.right = '0';
    document.getElementById('analytics-overlay').style.display = 'block';
    renderAnalyticsDrawer();
}

function closeAnalyticsDrawer() {
    document.getElementById('analytics-drawer').style.right = '-480px';
    document.getElementById('analytics-overlay').style.display = 'none';
}

function renderAnalyticsDrawer() {
    const container = document.getElementById('analytics-drawer-content-container');
    container.innerHTML = '<div style="text-align:center; padding:40px; color:var(--muted);">Loading Analytics...</div>';
    
    fetch("/api/kitchen-intelligence")
        .then(r => r.text())
        .then(html => {
            container.innerHTML = html;
            
            // Initialize chart if present
            const canvas = document.getElementById('weeklyActivityChartDrawer');
            if (canvas) {
                const activityDataStr = canvas.getAttribute('data-activity');
                if (activityDataStr) {
                    try {
                        const activityData = JSON.parse(activityDataStr);
                        initAnalyticsChart(activityData, canvas);
                    } catch (e) {
                        console.error('Error parsing activity data', e);
                    }
                }
            }
        })
        .catch(err => {
            console.error('Failed to load analytics', err);
            container.innerHTML = '<div style="text-align:center; padding:40px; color:var(--muted);">Failed to load analytics.</div>';
        });
}

function initAnalyticsChart(activityData, canvas) {
    const ctx = canvas.getContext('2d');
    const isDark = document.body.classList.contains('dark-theme');
    
    const brandColor = "#FF6B35";
    const brandColorTranslucent = isDark ? "rgba(255,107,53,0.15)" : "rgba(255,107,53,0.1)";
    const textColor = isDark ? "#A0A0A0" : "#6b7280";
    const gridColor = isDark ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.05)";

    // Destroy existing chart on this canvas if any
    const existingChart = Chart.getChart(canvas);
    if (existingChart) existingChart.destroy();

    const maxVal = Math.max(...activityData);
    const yMax = maxVal < 5 ? 5 : maxVal + 2;

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
            datasets: [{
                label: 'Cooked Recipes',
                data: activityData,
                backgroundColor: brandColorTranslucent,
                borderColor: brandColor,
                borderWidth: 2,
                borderRadius: 4,
                hoverBackgroundColor: brandColor,
                barThickness: 10
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: {
                duration: 1000,
                easing: 'easeOutQuart'
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: isDark ? '#2e2e2e' : '#fff',
                    titleColor: isDark ? '#fff' : '#1f2937',
                    bodyColor: isDark ? '#ccc' : '#4b5563',
                    borderColor: gridColor,
                    borderWidth: 1,
                    padding: 10,
                    displayColors: false,
                    callbacks: {
                        label: function(context) {
                            return context.raw + ' recipes';
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    max: yMax,
                    ticks: {
                        stepSize: 1,
                        color: textColor,
                        font: { size: 10 }
                    },
                    grid: {
                        color: gridColor,
                        drawBorder: false,
                    },
                    border: { display: false }
                },
                x: {
                    ticks: {
                        color: textColor,
                        font: { size: 10, weight: '500' }
                    },
                    grid: {
                        display: false,
                        drawBorder: false
                    },
                    border: { display: false }
                }
            }
        }
    });
}
