// ===== Enter key: text tab =====
document.getElementById('ingredients-input').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') getRecommendations();
});

// ===== Enter key: voice + image result boxes =====
document.addEventListener('DOMContentLoaded', function() {
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
}

// ===== Get recommendations (text tab) =====
async function getRecommendations() {
    const input = document.getElementById('ingredients-input');
    const ingredients = input.value.trim();

    const loading = document.getElementById('loading');
    const results = document.getElementById('results');
    const errorMsg = document.getElementById('error-message');
    const searchBtn = document.querySelector('.btn-search');

    results.classList.remove('show');
    errorMsg.classList.remove('show');

    if (!ingredients) {
        errorMsg.textContent = 'Please enter at least one ingredient!';
        errorMsg.classList.add('show');
        return;
    }

    loading.classList.add('show');
    searchBtn.disabled = true;
    searchBtn.textContent = 'Searching...';

    try {
        const response = await fetch('/get-recommendations', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ingredients: ingredients })
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Failed to get recommendations');
        displayResults(data.recommendations);

    } catch (error) {
        errorMsg.textContent = 'Error: ' + error.message;
        errorMsg.classList.add('show');
    } finally {
        loading.classList.remove('show');
        searchBtn.disabled = false;
        searchBtn.textContent = 'Get Recipes';
    }
}

// ===== Display results =====
function displayResults(recommendations) {
    const recipeList = document.getElementById('recipe-list');
    const results = document.getElementById('results');

    if (recommendations.length === 0) {
        recipeList.innerHTML = '<p>No recipes found. Try different ingredients!</p>';
    } else {
        recipeList.innerHTML = recommendations.map(recipe => {
            const difficultyIcon = recipe.difficulty === 'easy' ? '✅' : recipe.difficulty === 'medium' ? '⚡' : '🔥';
            const difficultyText = recipe.difficulty.charAt(0).toUpperCase() + recipe.difficulty.slice(1);

            const pct = recipe.match_pct || 0;
            const matched = recipe.matched_count || 0;
            const total = recipe.total_ingredients || 0;
            const missing = recipe.missing_ingredients || [];

            let barColor = '#ff6b6b';
            if (pct >= 70) barColor = '#00b894';
            else if (pct >= 40) barColor = '#fdcb6e';

            const missingHTML = missing.length > 0
                ? `<div class="missing-info">
                    🛒 <strong>Still need:</strong>
                    ${missing.map(m => `
                        <span class="missing-tag-wrap">
                            <span class="missing-tag-item">${m}</span>
                            <button class="swap-btn" onclick="getSubstitute('${m}', this)">swap?</button>
                            <span class="sub-result"></span>
                        </span>
                    `).join('')}
                   </div>`
                : `<div class="missing-info all-good">✅ You have all ingredients!</div>`;

            return `
            <div class="recipe-card" style="padding:0; display:flex; flex-direction:column;">
                ${recipe.image_url ? `<img src="${recipe.image_url}" alt="${recipe.recipe_name}" style="width:100%;height:180px;object-fit:cover;border-radius:10px 10px 0 0;display:block;" onerror="this.style.display='none'">` : ''}
                <div style="padding:20px 28px 28px 28px; display:flex; flex-direction:column; flex:1;">
                    <div class="recipe-header">
                        <h3>${recipe.recipe_name}</h3>
                        <span class="match-score" style="background:${barColor}">${pct}% Match</span>
                    </div>
                    <div class="recipe-info">
                        <span class="info-tag">🍽️ ${recipe.cuisine}</span>
                        <span class="info-tag">🔥 ${recipe.calories} cal</span>
                        <span class="info-tag">⭐ ${recipe.rating}/5</span>
                        <span class="info-tag difficulty-${recipe.difficulty}">${difficultyIcon} ${difficultyText}</span>
                    </div>
                    <div class="match-bar-wrapper">
                        <span style="font-size:12px;color:#888;">You have <strong>${matched} of ${total}</strong> ingredients</span>
                        <div style="background:#edf2f7;border-radius:99px;height:6px;margin-top:5px;overflow:hidden;">
                            <div style="width:${pct}%;height:100%;background:${barColor};border-radius:99px;transition:width 0.6s ease;"></div>
                        </div>
                    </div>
                    ${missingHTML}
                    <div class="ingredients-list">
                        <strong>Ingredients:</strong> ${recipe.ingredients}
                    </div>
                    <a href="/recipe/${recipe.recipe_id}" class="view-recipe-btn" style="margin-top:auto;">View Full Recipe</a>
                </div>
            </div>
            `;
        }).join('');
    }

    results.classList.add('show');
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
    if (isRecording) {
        stopRecording();
    } else {
        startRecording();
    }
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

        const response = await fetch('/transcribe-audio', {
            method: 'POST',
            body: formData
        });

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

// ===== Submit from voice tab =====
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

    // Show thumbnails
    renderThumbnails();
    clearBtn.style.display = 'inline-block';

    // Start analyzing
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
            const response = await fetch('/analyze-image', {
                method: 'POST',
                body: formData
            });
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

    // Show chips one by one
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
    if (uploadedFiles.length === 0) {
        clearImages();
    }
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

// ===== Submit from image tab =====
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