let currentStep = 0;
let totalSteps = 0;
let slides = [];

document.addEventListener('DOMContentLoaded', () => {
    slides = document.querySelectorAll('.cooking-slide');
    totalSteps = slides.length;
    
    if (totalSteps > 0) {
        updateUI();
    }
});

function updateUI() {
    // Hide all slides, show current
    slides.forEach((slide, index) => {
        if (index === currentStep) {
            slide.classList.add('active');
        } else {
            slide.classList.remove('active');
        }
    });

    // Update Progress text and bar
    document.getElementById('step-counter').innerText = `Step ${currentStep + 1} of ${totalSteps}`;
    const progressPercent = ((currentStep + 1) / totalSteps) * 100;
    document.getElementById('progress-fill').style.width = `${progressPercent}%`;

    // Toggle Buttons
    document.getElementById('btn-prev').disabled = currentStep === 0;

    if (currentStep === totalSteps - 1) {
        document.getElementById('btn-next').style.display = 'none';
        document.getElementById('btn-finish').style.display = 'block';
    } else {
        document.getElementById('btn-next').style.display = 'block';
        document.getElementById('btn-finish').style.display = 'none';
    }
}

function nextStep() {
    if (currentStep < totalSteps - 1) {
        currentStep++;
        updateUI();
    }
}

function prevStep() {
    if (currentStep > 0) {
        currentStep--;
        updateUI();
    }
}

async function markAsCooked() {
    const recipeId = document.getElementById('recipe-id').value;
    
    try {
        const response = await fetch(`/mark-as-cooked/${recipeId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (response.ok) {
            // Epic Fireworks Confetti!
            if (window.confetti) {
                var duration = 3000;
                var animationEnd = Date.now() + duration;
                var defaults = { startVelocity: 30, spread: 360, ticks: 60, zIndex: 9999 };
                var interval = setInterval(function() {
                    var timeLeft = animationEnd - Date.now();
                    if (timeLeft <= 0) return clearInterval(interval);
                    var particleCount = 50 * (timeLeft / duration);
                    confetti(Object.assign({}, defaults, { particleCount, origin: { x: Math.random(), y: Math.random() - 0.2 }, colors: ['#FF6B35', '#28a745', '#ffffff', '#FFD700'] }));
                }, 250);
            }

            // Hide the cooking container and show beautiful completion screen
            document.querySelector('.cooking-focus-container').style.display = 'none';
            document.getElementById('success-message').style.display = 'flex';
        } else {
            alert('Error: ' + data.error);
        }
    } catch (error) {
        alert('Error marking recipe as cooked');
    }
}

// ==================== LANGUAGE: COOKING PAGE ====================

const COOKING_LANG_CACHE_PREFIX = 'chefgpt_recipe_ms_';

/**
 * Called by dashboard.js setLanguage() or on page load.
 */
async function applyPageLanguage(lang) {
    if (lang === 'ms') {
        await loadMalayForCookingPage();
    } else {
        revertToEnglishOnCookingPage();
    }
}

async function loadMalayForCookingPage() {
    const recipeIdEl = document.getElementById('recipe-id');
    if (!recipeIdEl) return;
    const recipeId = recipeIdEl.value;

    const cacheKey = COOKING_LANG_CACHE_PREFIX + recipeId;
    let data = null;

    // Try sessionStorage first (populated by recipe detail page)
    const cached = sessionStorage.getItem(cacheKey);
    if (cached) {
        try { data = JSON.parse(cached); } catch(e) {}
    }

    // If not cached, fetch from the API
    if (!data) {
        try {
            const ingredients = document.getElementById('recipe-ingredients-raw')?.value || '';
            const instructions = document.getElementById('recipe-instructions-raw')?.value || '';

            const res = await fetch('/api/translate-recipe', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ recipe_id: recipeId, ingredients, instructions })
            });
            if (res.ok) {
                data = await res.json();
                sessionStorage.setItem(cacheKey, JSON.stringify(data));
            }
        } catch(e) {
            console.error('[cooking.js] Translation error:', e);
        }
    }

    if (data && data.instructions_ms) {
        applyMalayStepsToCookingPage(data.instructions_ms);
    }
}

function applyMalayStepsToCookingPage(instructionsMs) {
    const msSteps = instructionsMs.split('|').map(s => s.trim()).filter(Boolean);
    const stepEls = document.querySelectorAll('.slide-text');
    stepEls.forEach((el, i) => {
        if (msSteps[i]) el.textContent = msSteps[i];
    });
}

function revertToEnglishOnCookingPage() {
    document.querySelectorAll('.slide-text[data-en]').forEach(el => {
        el.textContent = el.dataset.en;
    });
}

// Run on page load — respect user's stored language preference
document.addEventListener('DOMContentLoaded', function() {
    const lang = typeof getLanguage === 'function' ? getLanguage() : (localStorage.getItem('chefgpt_lang') || 'en');
    applyPageLanguage(lang);
});

