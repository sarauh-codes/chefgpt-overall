function switchTab(event, tabId) {
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    document.getElementById('tab-' + tabId).classList.add('active');
    event.currentTarget.classList.add('active');
}

let selectedRating = 0;

function setRating(rating) {
    selectedRating = rating;
    const stars = document.querySelectorAll('.star');
    stars.forEach((star, index) => {
        if (index < rating) {
            star.textContent = '★';
            star.classList.add('selected');
        } else {
            star.textContent = '☆';
            star.classList.remove('selected');
        }
    });
}
   
const recipeId = document.getElementById('recipe-id').value;

async function toggleSave() {
    const btn = document.getElementById('save-btn');
    const isSaved = btn.dataset.saved === 'true';
    const url = isSaved ? `/unsave-recipe/${recipeId}` : `/save-recipe/${recipeId}`;

    const res = await fetch(url, { method: 'POST' });
    const data = await res.json();

    if (data.success) {
        btn.dataset.saved = isSaved ? 'false' : 'true';
        btn.textContent = isSaved ? '💾 Save Recipe' : '✅ Saved';
        
        if (typeof showToast === 'function') {
            if (isSaved) {
                showToast('Recipe removed from saved list.', 'success');
            } else {
                showToast('✅ Recipe saved successfully!', 'success');
                // Trigger delightful micro-animation
                if (window.confetti) {
                    confetti({
                        particleCount: 100,
                        spread: 70,
                        origin: { y: 0.6 },
                        colors: ['#FF6B35', '#f7931e', '#ffffff']
                    });
                }
            }
        }
    } else {
        if (typeof showToast === 'function') showToast(data.message, 'error');
        else alert(data.message);
    }
}

// Check on page load if already saved
async function checkSaved() {
    const res = await fetch(`/is-saved/${recipeId}`);
    const data = await res.json();
    const btn = document.getElementById('save-btn');
    btn.dataset.saved = data.is_saved ? 'true' : 'false';
    btn.textContent = data.is_saved ? '✅ Saved' : '💾 Save Recipe';
}

checkSaved();
async function submitFeedback() {
    if (selectedRating === 0) {
        alert('Please select a rating!');
        return;
    }
    
    const comment = document.getElementById('comment-input').value;
    const recipeId = document.getElementById('recipe-id').value;
    
    try {
        const response = await fetch(`/submit-feedback/${recipeId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                rating: selectedRating,
                comment: comment
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            if (typeof showToast === 'function') showToast('✅ ' + data.message, 'success');
            else alert('✅ ' + data.message);
            document.getElementById('comment-input').value = '';
            loadFeedbacks();
        } else {
            if (typeof showToast === 'function') showToast('Error: ' + data.error, 'error');
            else alert('Error: ' + data.error);
        }
    } catch (error) {
        if (typeof showToast === 'function') showToast('Error submitting feedback', 'error');
        else alert('Error submitting feedback');
    }
}

async function loadFeedbacks() {
    const recipeId = document.getElementById('recipe-id').value;
    
    try {
        const response = await fetch(`/get-feedbacks/${recipeId}`);
        const data = await response.json();
        
        const container = document.getElementById('feedbacks-container');
        
        if (data.feedbacks.length === 0) {
            container.innerHTML = '<div class="no-feedbacks">No reviews yet. Be the first to review this recipe!</div>';
        } else {
            container.innerHTML = data.feedbacks.map(fb => `
                <div class="feedback-card">
                    <div class="feedback-header">
                        <span class="feedback-username">👤 ${fb.username}</span>
                        <span class="feedback-rating">${'★'.repeat(fb.rating)}${'☆'.repeat(5-fb.rating)}</span>
                    </div>
                    ${fb.comment ? `<div class="feedback-comment">"${fb.comment}"</div>` : ''}
                    <div class="feedback-date">📅 ${fb.created_at}</div>
                </div>
            `).join('');
        }
    } catch (error) {
        console.error('Error loading feedbacks:', error);
    }
}

// Load feedbacks when page loads
document.addEventListener('DOMContentLoaded', function() {
    loadFeedbacks();
    
    // Auto-open reviews tab if coming from the cooking completion screen
    if (window.location.hash === '#feedback' || window.location.hash === '#reviews') {
        const reviewBtn = document.querySelector('button[onclick*="reviews"]');
        if (reviewBtn) {
            reviewBtn.click();
            setTimeout(() => {
                reviewBtn.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }, 300);
        }
    }
});

// ------------share Recipe----------
const recipeUrl = window.location.href;
const recipeName = document.querySelector('.recipe-title').textContent.trim();
const cuisineName = document.querySelector('.recipe-cuisine')?.textContent.trim() || 'General';
const caloriesCount = document.querySelector('.meta-tag')?.textContent.trim() || '';

const shareText = `🍳 Check out this recipe: ${recipeName}!\n\n🍽️ Cuisine: ${cuisineName}\n🔥 ${caloriesCount}\n\nView the full recipe here:\n${recipeUrl}\n\nShared from ChefGPT 👨‍🍳`;

function openShareModal() {
    // If the browser supports native sharing (like on mobile phones or modern Macs), use that!
    if (navigator.share) {
        navigator.share({
            title: recipeName,
            text: shareText,
            url: recipeUrl,
        })
        .catch(console.error);
    } else {
        // Fallback to our custom modal for older browsers / desktop
        const modal = document.getElementById('share-modal');
        document.getElementById('share-overlay').style.display = 'block';
        modal.style.display = 'block';
        
        // Trigger reflow for animation
        void modal.offsetWidth;
        modal.classList.add('show');
    }
}

function closeShareModal() {
    const modal = document.getElementById('share-modal');
    modal.classList.remove('show');
    setTimeout(() => {
        modal.style.display = 'none';
        document.getElementById('share-overlay').style.display = 'none';
    }, 300);
}

function shareWhatsApp() {
    window.open(`https://wa.me/?text=${encodeURIComponent(shareText + ' ' + recipeUrl)}`, '_blank');
}

function shareFacebook() {
    window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(recipeUrl)}`, '_blank');
}

function shareTwitter() {
    window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(recipeUrl)}`, '_blank');
}

function shareTelegram() {
    window.open(`https://t.me/share/url?url=${encodeURIComponent(recipeUrl)}&text=${encodeURIComponent(shareText)}`, '_blank');
}

function copyLink() {
    const input = document.getElementById('share-link-input');
    navigator.clipboard.writeText(input.value).then(() => {
        if (typeof showToast === 'function') {
            showToast('🔗 Link copied to clipboard!', 'success');
        }
        closeShareModal();
    });
}

// ---- PRINT & PDF ----
function printRecipe() {
    window.print();
}

function downloadPDF() {
    if (typeof showToast === 'function') showToast('⏳ Generating PDF... Please wait.', 'success');

    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();

    function cleanText(text) {
        return text
            .replace(/[\u{1F300}-\u{1FFFF}]/gu, '')   
            .replace(/[\u{2600}-\u{26FF}]/gu, '')       
            .replace(/[\u{2700}-\u{27BF}]/gu, '')       
            .replace(/[^\x00-\x7F]/g, '')               
            .replace(/\s+/g, ' ')                        
            .trim();
    }

    const title = cleanText(document.querySelector('.recipe-title').textContent);
    const metaTags = document.querySelectorAll('.meta-tag');
    const cuisine = cleanText(metaTags[0]?.textContent || '');
    const calories = cleanText(metaTags[1]?.textContent || '');
    const rating = cleanText(metaTags[2]?.textContent || '');
    const difficulty = cleanText(metaTags[3]?.textContent || '');

    const ingredientItems = document.querySelectorAll('.ingredient-text');
    const ingredients = Array.from(ingredientItems).map(el => '[  ] ' + cleanText(el.textContent));

    const instructionItems = document.querySelectorAll('.print-only .timeline-content');
    const instructions = Array.from(instructionItems).map((el, i) => `Step ${i + 1}:\n${cleanText(el.textContent)}`);

    let y = 20;

    // Stylish Header
    doc.setFillColor(255, 107, 53); // ChefGPT Orange
    doc.rect(0, 0, 210, 35, 'F');
    
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(24);
    doc.setTextColor(255, 255, 255);
    doc.text(title, 105, 18, { align: 'center' });
    
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(10);
    doc.text(`${cuisine}   |   ${calories}   |   ${rating}   |   Difficulty: ${difficulty}`, 105, 28, { align: 'center' });

    y = 50;

    // Ingredients Section
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(16);
    doc.setTextColor(40, 40, 40);
    doc.text('Ingredients Checklist', 15, y);
    y += 10;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(11);
    doc.setTextColor(60, 60, 60);
    
    ingredients.forEach(ing => {
        if (y > 270) { doc.addPage(); y = 20; }
        doc.text(ing, 15, y);
        y += 7;
    });
    
    y += 10;

    // Instructions Section
    if (y > 250) { doc.addPage(); y = 20; }
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(16);
    doc.setTextColor(40, 40, 40);
    doc.text('Step-by-Step Instructions', 15, y);
    y += 10;

    doc.setFontSize(11);
    instructions.forEach(step => {
        if (y > 270) { doc.addPage(); y = 20; }
        
        // Make 'Step X:' bold visually by splitting it
        const splitText = step.split('\n');
        doc.setFont('helvetica', 'bold');
        doc.setTextColor(255, 107, 53);
        doc.text(splitText[0], 15, y);
        y += 6;
        
        doc.setFont('helvetica', 'normal');
        doc.setTextColor(60, 60, 60);
        const lines = doc.splitTextToSize(splitText[1], 180);
        doc.text(lines, 15, y);
        
        y += (lines.length * 6) + 8; // Extra padding between steps
    });

    // Footer
    const totalPages = doc.internal.getNumberOfPages();
    for (let i = 1; i <= totalPages; i++) {
        doc.setPage(i);
        doc.setFontSize(9);
        doc.setTextColor(150, 150, 150);
        doc.text(`Generated by ChefGPT - Page ${i} of ${totalPages}`, 105, 290, { align: 'center' });
    }

    doc.save(`${title.replace(/\s+/g, '_')}_Recipe.pdf`);
    
    if (typeof showToast === 'function') showToast('✅ PDF downloaded successfully!', 'success');
}