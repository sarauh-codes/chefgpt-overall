// ===== Chip Management System (text tab) =====
let ingredientChips = [];

function addChip(ingredient) {
    ingredient = ingredient.trim().toLowerCase().replace(/,+$/, '');
    if (!ingredient || ingredientChips.includes(ingredient)) return;
    ingredientChips.push(ingredient);
    renderChips();
    syncHiddenInput();
    updateIngredientMeta();
}

function removeChip(ingredient) {
    ingredientChips = ingredientChips.filter(i => i !== ingredient);
    renderChips();
    syncHiddenInput();
    updateIngredientMeta();
}

function clearAllChips() {
    ingredientChips = [];
    renderChips();
    syncHiddenInput();
    updateIngredientMeta();
}

function renderChips() {
    const container = document.getElementById('chips-container');
    const input = document.getElementById('ingredient-typing-input');
    container.querySelectorAll('.ingredient-chip').forEach(c => c.remove());
    ingredientChips.forEach(ing => {
        const chip = document.createElement('span');
        chip.className = 'ingredient-chip';
        const label = document.createTextNode(ing);
        const removeBtn = document.createElement('button');
        removeBtn.className = 'chip-remove';
        removeBtn.textContent = '×';
        removeBtn.addEventListener('click', (e) => { e.stopPropagation(); removeChip(ing); });
        chip.appendChild(label);
        chip.appendChild(removeBtn);
        container.insertBefore(chip, input);
    });
}

function syncHiddenInput() {
    document.getElementById('ingredients-input').value = ingredientChips.join(', ');
}

function updateIngredientMeta() {
    const countEl = document.getElementById('ingredient-count');
    const countText = document.getElementById('count-text');
    if (ingredientChips.length > 0) {
        countEl.style.display = 'inline-flex';
        countText.textContent = `${ingredientChips.length} ingredient${ingredientChips.length !== 1 ? 's' : ''} added`;
    } else {
        countEl.style.display = 'none';
    }
}

// ===== Typing input event handlers =====
document.addEventListener('DOMContentLoaded', function() {
    const typingInput = document.getElementById('ingredient-typing-input');
    if (typingInput) {
        typingInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ',') {
                e.preventDefault();
                const val = this.value.trim().replace(/,+$/, '');
                if (val) { addChip(val); this.value = ''; }
            } else if (e.key === 'Backspace' && this.value === '' && ingredientChips.length > 0) {
                removeChip(ingredientChips[ingredientChips.length - 1]);
            }
        });

        typingInput.addEventListener('paste', function(e) {
            e.preventDefault();
            const pasted = (e.clipboardData || window.clipboardData).getData('text');
            pasted.split(',').forEach(part => {
                const trimmed = part.trim();
                if (trimmed) addChip(trimmed);
            });
            this.value = '';
        });
    }

    const voiceInput = document.getElementById('ingredients-input-voice');
    if (voiceInput) {
        voiceInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') getRecommendationsFromVoice();
        });
    }

    const imageInput = document.getElementById('ingredients-input-image');
    if (imageInput) {
        imageInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') getRecommendationsFromImage();
        });
    }
});

// ===== Tab switcher =====
function switchTab(tab) {
    document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
    document.getElementById('content-' + tab).style.display = 'block';
    document.getElementById('tab-' + tab).classList.add('active');
    document.getElementById('error-message').classList.remove('show');
    document.getElementById('results').classList.remove('show');
    document.getElementById('result-filters').style.display = 'none';
}

// ===== Get recommendations =====
async function getRecommendations() {
    const ingredients = document.getElementById('ingredients-input').value.trim();

    const loading = document.getElementById('loading');
    const results = document.getElementById('results');
    const errorMsg = document.getElementById('error-message');
    const searchBtn = document.getElementById('text-search-btn');
    const insightBanner = document.getElementById('ai-insight-banner');

    results.classList.remove('show');
    document.getElementById('result-filters').style.display = 'none';
    errorMsg.classList.remove('show');
    insightBanner.style.display = 'none';

    if (!ingredients) {
        errorMsg.textContent = 'Please add at least one ingredient!';
        errorMsg.classList.add('show');
        return;
    }

    loading.classList.add('show');
    if (searchBtn) { searchBtn.disabled = true; searchBtn.textContent = 'Searching...'; }

    try {
        const cookingContext = document.getElementById('cooking-context-input')?.value.trim() || '';

        const response = await fetch('/get-recommendations', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ingredients: ingredients, context: cookingContext })
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Failed to get recommendations');

        // AI insight banner
        if (data.ai_context && (data.ai_context.cooking_insight || data.ai_context.cuisine_context)) {
            document.getElementById('ai-insight-content').textContent = data.ai_context.cooking_insight || '';
            const cuisineEl = document.getElementById('ai-insight-cuisine');
            if (data.ai_context.cuisine_context && data.ai_context.cuisine_context !== 'general') {
                cuisineEl.textContent = data.ai_context.cuisine_context;
                cuisineEl.style.display = 'inline-block';
            } else {
                cuisineEl.style.display = 'none';
            }
            insightBanner.style.display = 'flex';
        }

        // Personalisation badge
        const p = data.personalisation || {};
        const personBadge = document.getElementById('personalisation-badge');
        if (personBadge) {
            if (p.has_history && p.top_cuisines && p.top_cuisines.length > 0) {
                personBadge.textContent = `🎯 Personalised for you · based on ${p.saved_count} saved recipes · you love ${p.top_cuisines.slice(0,2).join(' & ')}`;
                personBadge.style.display = 'block';
            } else {
                personBadge.textContent = '💡 Save recipes to get personalised recommendations next time!';
                personBadge.style.display = 'block';
            }
        }

        displayResults(data.recommendations || [], data.ai_recipes || []);
    } catch (error) {
        errorMsg.textContent = 'Error: ' + error.message;
        errorMsg.classList.add('show');
    } finally {
        loading.classList.remove('show');
        if (searchBtn) { searchBtn.disabled = false; searchBtn.textContent = 'Get Recipes'; }
    }
}

// ===== Display results (grouped) =====
let allRecommendations = [];
let storedAiRecipes = [];

function displayResults(recommendations, aiRecipes) {
    const recipeList = document.getElementById('recipe-list');
    const results = document.getElementById('results');
    const filterBar = document.getElementById('result-filters');
    const summary = document.getElementById('result-summary');

    storedAiRecipes = aiRecipes || [];

    if (recommendations.length === 0 && storedAiRecipes.length === 0) {
        recipeList.innerHTML = '<p class="no-results">No recipes found. Try adding more ingredients!</p>';
        filterBar.style.display = 'none';
        results.classList.add('show');
        return;
    }

    allRecommendations = recommendations;

    if (summary) {
        summary.textContent = recommendations.length > 0
            ? `${recommendations.length} recipes from our database`
            : '';
    }

    // Filter bar — cuisine only, no more ready/almost grouping
    const cuisines = [...new Set(recommendations.map(r => r.cuisine).filter(Boolean))];
    filterBar.innerHTML = `
        <button class="filter-btn active" onclick="applyFilter('all', this)">All (${recommendations.length})</button>
        ${cuisines.slice(0, 5).map(c => `<button class="filter-btn filter-cuisine" onclick="applyFilter(${JSON.stringify('cuisine:' + c)}, this)">${c}</button>`).join('')}
    `;
    filterBar.style.display = recommendations.length > 0 ? 'flex' : 'none';

    renderResults(recommendations);
    results.classList.add('show');
}

function applyFilter(filter, btn) {
    document.querySelectorAll('#result-filters .filter-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');

    let filtered;
    if (filter === 'all') {
        filtered = allRecommendations;
    } else if (filter.startsWith('cuisine:')) {
        const cuisine = filter.replace('cuisine:', '');
        filtered = allRecommendations.filter(r => r.cuisine === cuisine);
    } else {
        filtered = allRecommendations;
    }

    renderResults(filtered);
}

function renderResults(recommendations) {
    const recipeList = document.getElementById('recipe-list');
    let html = '';

    // AI-generated section (always at top)
    if (storedAiRecipes.length > 0) {
        html += `
            <div class="result-group">
                <div class="group-header ai-header">
                    <span class="group-icon">✨</span>
                    <span class="group-title">AI-Generated Recipes</span>
                    <span class="ai-badge">Made just for you</span>
                </div>
                <div class="recipe-grid">
                    ${storedAiRecipes.map((r, i) => renderAIRecipeCard(r, i)).join('')}
                </div>
            </div>`;
    }

    // DB results — flat grid, no grouping
    if (recommendations.length > 0) {
        html += `
            <div class="result-group">
                <div class="group-header db-header">
                    <span class="group-icon">📖</span>
                    <span class="group-title">From Our Database</span>
                    <span class="group-count">${recommendations.length}</span>
                </div>
                <div class="recipe-grid">
                    ${recommendations.map(renderRecipeCard).join('')}
                </div>
            </div>`;
    }

    if (!html) {
        html = '<p class="no-results">No recipes match this filter.</p>';
    }

    recipeList.innerHTML = html;
}

function renderRecipeCard(recipe) {
    const difficultyIcon = recipe.difficulty === 'easy' ? '✅' : recipe.difficulty === 'medium' ? '⚡' : '🔥';
    const difficultyText = recipe.difficulty.charAt(0).toUpperCase() + recipe.difficulty.slice(1);

    const pct = recipe.match_pct || 0;
    const matched = recipe.matched_count || 0;
    const total = recipe.total_ingredients || 0;
    const missing = recipe.missing_ingredients || [];

    let bannerColor = 'linear-gradient(135deg,#e53e3e,#fc8181)';
    if (pct >= 80) bannerColor = 'linear-gradient(135deg,#38a169,#68d391)';
    else if (pct >= 40) bannerColor = 'linear-gradient(135deg,#d69e2e,#f6e05e)';

    const swappableKeywords = ['pork', 'wine', 'alcohol', 'beer', 'beef', 'chicken', 'meat', 'bacon', 'ham', 'lard', 'shrimp', 'crab', 'prawn', 'fish', 'tofu', 'cheese', 'milk', 'cream', 'butter', 'rum', 'brandy', 'vodka', 'whiskey', 'sauce'];

    const missingHTML = missing.length > 0
        ? `<div class="missing-info">
            🛒 <strong>Still need:</strong>
            ${missing.map(m => {
                const isSwappable = swappableKeywords.some(k => m.toLowerCase().includes(k));
                return `<span class="missing-tag-wrap">
                    <span class="missing-tag-item">${m}</span>
                    ${isSwappable ? `<button class="swap-btn" onclick="getSubstitute('${m}', this)">swap?</button>` : ''}
                    <span class="sub-result"></span>
                </span>`;
            }).join('')}
           </div>`
        : `<div class="missing-info all-good">✅ You have all the ingredients!</div>`;

    return `
    <div class="recipe-card" style="padding:0;">
        <div class="card-top-banner" style="background:${bannerColor};">
            <span class="banner-match">${pct}% Match</span>
            <span class="banner-have">You have ${matched} of ${total}</span>
        </div>
        ${recipe.image_url ? `<img src="${recipe.image_url}" alt="${recipe.recipe_name}" class="card-img" onerror="this.style.display='none'">` : ''}
        <div class="card-body">
            <h3 class="card-title">${recipe.recipe_name}</h3>
            <div class="recipe-info">
                <span class="info-tag">🍽️ ${recipe.cuisine}</span>
                <span class="info-tag">🔥 ${recipe.calories} cal</span>
                <span class="info-tag">⭐ ${recipe.rating}/5</span>
                <span class="info-tag">${difficultyIcon} ${difficultyText}</span>
            </div>
            ${recipe.chef_tip ? `<div class="chef-tip">💬 <em>${recipe.chef_tip}</em></div>` : ''}
            ${missingHTML}
            <a href="/recipe/${recipe.recipe_id}" class="view-recipe-btn">View Full Recipe →</a>
        </div>
    </div>`;
}

function renderAIRecipeCard(recipe, index) {
    const difficultyIcon = recipe.difficulty === 'easy' ? '✅' : recipe.difficulty === 'medium' ? '⚡' : '🔥';
    const difficultyText = (recipe.difficulty || 'easy').charAt(0).toUpperCase() + (recipe.difficulty || 'easy').slice(1);

    const aiImg = recipe.image_url
        ? `<div style="width:100%;aspect-ratio:4/3;overflow:hidden;border-radius:8px 8px 0 0;background:var(--panel-2);">
               <img src="${recipe.image_url}" alt="${recipe.recipe_name}" style="width:100%;height:100%;object-fit:cover;display:block;transition:transform 0.4s ease;" onerror="this.onerror=null;this.src='/static/images/recipe-placeholder.jpg';">
           </div>`
        : '';

    return `
    <div class="recipe-card ai-recipe-card" style="padding:0;">
        ${aiImg}
        <div class="ai-recipe-header-banner">✨ AI-Generated Just for You</div>
        <div class="card-body">
            <h3 class="card-title">${recipe.recipe_name}</h3>
            <div class="recipe-info">
                <span class="info-tag">🍽️ ${recipe.cuisine || 'Fusion'}</span>
                <span class="info-tag">🔥 ${recipe.calories || '~'} cal</span>
                <span class="info-tag">⏱️ ${recipe.estimated_time_mins || 30} min</span>
                <span class="info-tag">${difficultyIcon} ${difficultyText}</span>
            </div>
            ${recipe.why_it_works ? `<div class="ai-why-box">💡 ${recipe.why_it_works}</div>` : ''}
            ${recipe.chef_tip ? `<div class="chef-tip">💬 <em>${recipe.chef_tip}</em></div>` : ''}
            <a href="/recipe/ai?n=${index}" class="view-recipe-btn ai-view-btn">View Full Recipe →</a>
        </div>
    </div>`;
}

// ===== Substitute feature =====
async function getSubstitute(ingredient, btn) {
    const resultSpan = btn.nextElementSibling;

    if (resultSpan.innerHTML !== '') {
        resultSpan.innerHTML = '';
        btn.textContent = 'swap?';
        return;
    }

    btn.textContent = '...';

    try {
        const res = await fetch('/get-substitute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ingredient: ingredient })
        });
        const data = await res.json();
        btn.textContent = 'swap?';

        if (data.substitutes.length === 0) {
            resultSpan.innerHTML = `<span class="sub-none">No substitute found</span>`;
        } else {
            resultSpan.innerHTML = `<span class="sub-list">→ ${data.substitutes.map(s => `<span class="sub-item" title="${s[1]}">${s[0]}</span>`).join(' or ')}</span>`;
        }
    } catch (err) {
        btn.textContent = 'swap?';
        resultSpan.innerHTML = `<span class="sub-none">Error</span>`;
    }
}

// ===== Whisper Voice Recording =====
let mediaRecorder = null;
let audioChunks = [];
let isRecording = false;

async function toggleRecording() {
    if (isRecording) stopRecording();
    else startRecording();
}

async function startRecording() {
    const micBtn = document.getElementById('micBtn');
    const status = document.getElementById('voiceStatus');
    const resultGroup = document.getElementById('voice-result-group');

    try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        audioChunks = [];
        mediaRecorder = new MediaRecorder(stream);
        mediaRecorder.ondataavailable = (event) => {
            if (event.data.size > 0) audioChunks.push(event.data);
        };
        mediaRecorder.onstop = async () => {
            const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
            await sendAudioToWhisper(audioBlob);
            stream.getTracks().forEach(track => track.stop());
        };
        mediaRecorder.start();
        isRecording = true;
        micBtn.textContent = '⏹️ Stop Recording';
        micBtn.classList.add('listening');
        status.textContent = '🎙️ Recording... speak your ingredients now!';
        resultGroup.style.display = 'none';
    } catch (err) {
        status.textContent = '❌ Mic permission denied. Please allow microphone access.';
    }
}

function stopRecording() {
    if (mediaRecorder && isRecording) {
        mediaRecorder.stop();
        isRecording = false;
        const micBtn = document.getElementById('micBtn');
        const status = document.getElementById('voiceStatus');
        micBtn.textContent = '⏳ Processing...';
        micBtn.classList.remove('listening');
        micBtn.disabled = true;
        status.textContent = '🤖 Whisper is transcribing your audio...';
    }
}

async function sendAudioToWhisper(audioBlob) {
    const micBtn = document.getElementById('micBtn');
    const status = document.getElementById('voiceStatus');
    const resultGroup = document.getElementById('voice-result-group');
    const voiceInput = document.getElementById('ingredients-input-voice');

    try {
        const formData = new FormData();
        formData.append('audio', audioBlob, 'recording.webm');
        const response = await fetch('/transcribe-audio', { method: 'POST', body: formData });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Transcription failed');
        voiceInput.value = data.transcript;
        status.textContent = `✅ Heard: "${data.transcript}" — edit if needed, then click Get Recipes!`;
        resultGroup.style.display = 'flex';
    } catch (error) {
        status.textContent = '❌ Error: ' + error.message;
    } finally {
        micBtn.textContent = '🎤 Start Recording';
        micBtn.disabled = false;
    }
}

function getRecommendationsFromVoice() {
    const voiceValue = document.getElementById('ingredients-input-voice').value.trim();
    if (!voiceValue) {
        document.getElementById('error-message').textContent = '⚠️ No ingredients detected yet. Please record first!';
        document.getElementById('error-message').classList.add('show');
        return;
    }
    document.getElementById('ingredients-input').value = voiceValue;
    getRecommendations();
}

// ===== Image Upload with Animation =====
let uploadedFiles = [];

async function handleImageUpload(event) {
    const newFiles = Array.from(event.target.files);
    if (!newFiles.length) return;

    uploadedFiles = [...uploadedFiles, ...newFiles];

    const uploadLabel = document.getElementById('imageUploadLabel');
    const resultGroup = document.getElementById('image-result-group');
    const analyzingBox = document.getElementById('analyzingBox');
    const doneBox = document.getElementById('doneBox');
    const detectedChips = document.getElementById('detectedChips');
    const clearBtn = document.getElementById('clearImagesBtn');

    uploadLabel.classList.add('has-image');
    resultGroup.style.display = 'none';
    doneBox.classList.remove('active');
    detectedChips.innerHTML = '';

    renderThumbnails();
    clearBtn.style.display = 'inline-block';
    analyzingBox.classList.add('active');

    const allIngredients = new Set();
    const total = uploadedFiles.length;

    for (let i = 0; i < uploadedFiles.length; i++) {
        document.getElementById('progressLabel').textContent = `Analyzing image ${i + 1} of ${total}...`;
        document.getElementById('progressSub').textContent = uploadedFiles[i].name || `Image ${i + 1}`;
        document.getElementById('progressFill').style.width = `${Math.round((i / total) * 100)}%`;

        const formData = new FormData();
        formData.append('image', uploadedFiles[i]);

        try {
            const response = await fetch('/analyze-image', { method: 'POST', body: formData });
            const data = await response.json();
            if (response.ok && data.ingredients) {
                data.ingredients.split(',').forEach(ing => {
                    const trimmed = ing.trim();
                    if (trimmed) allIngredients.add(trimmed);
                });
            }
        } catch (error) {
            console.warn(`Image ${i + 1} failed, skipping:`, error);
        }
    }

    document.getElementById('progressFill').style.width = '100%';
    await new Promise(r => setTimeout(r, 300));
    analyzingBox.classList.remove('active');

    const finalIngredients = Array.from(allIngredients).join(', ');
    document.getElementById('ingredients-input-image').value = finalIngredients;

    doneBox.classList.add('active');
    Array.from(allIngredients).forEach((ing, i) => {
        setTimeout(() => {
            const chip = document.createElement('span');
            chip.className = 'chip';
            chip.textContent = ing;
            detectedChips.appendChild(chip);
        }, i * 80);
    });

    resultGroup.style.display = 'flex';
    event.target.value = '';
}

function renderThumbnails() {
    const strip = document.getElementById('previewStrip');
    strip.innerHTML = '';
    uploadedFiles.forEach((file, index) => {
        const reader = new FileReader();
        reader.onload = (e) => {
            const thumb = document.createElement('div');
            thumb.className = 'preview-thumb';
            thumb.innerHTML = `
                <img src="${e.target.result}" alt="ingredient photo">
                <button class="remove-btn" onclick="removeImage(${index})">✕</button>
            `;
            strip.appendChild(thumb);
        };
        reader.readAsDataURL(file);
    });
}

function removeImage(index) {
    uploadedFiles.splice(index, 1);
    renderThumbnails();
    if (uploadedFiles.length === 0) clearImages();
}

function clearImages() {
    uploadedFiles = [];
    document.getElementById('previewStrip').innerHTML = '';
    document.getElementById('analyzingBox').classList.remove('active');
    document.getElementById('doneBox').classList.remove('active');
    document.getElementById('detectedChips').innerHTML = '';
    document.getElementById('progressFill').style.width = '0%';
    document.getElementById('image-result-group').style.display = 'none';
    document.getElementById('ingredients-input-image').value = '';
    document.getElementById('imageUploadLabel').classList.remove('has-image');
    document.getElementById('clearImagesBtn').style.display = 'none';
    document.getElementById('imageInput').value = '';
}

function getRecommendationsFromImage() {
    const imageValue = document.getElementById('ingredients-input-image').value.trim();
    if (!imageValue) {
        document.getElementById('error-message').textContent = '⚠️ No ingredients detected yet. Please upload an image first!';
        document.getElementById('error-message').classList.add('show');
        return;
    }
    document.getElementById('ingredients-input').value = imageValue;
    getRecommendations();
}
