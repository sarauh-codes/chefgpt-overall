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
    } else {
        alert(data.message);
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
            alert('✅ ' + data.message);
            document.getElementById('comment-input').value = '';
            loadFeedbacks();
        } else {
            alert('Error: ' + data.error);
        }
    } catch (error) {
        alert('Error submitting feedback');
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
});

// ------------share Recipe----------
const recipeUrl = window.location.href;
const recipeName = document.querySelector('.recipe-title').textContent.trim();
const shareText = `Check out this recipe: ${recipeName} 🍽️`;

function openShareModal() {
    document.getElementById('share-modal').style.display = 'block';
    document.getElementById('share-overlay').style.display = 'block';
}

function closeShareModal() {
    document.getElementById('share-modal').style.display = 'none';
    document.getElementById('share-overlay').style.display = 'none';
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
        const btn = document.getElementById('copy-btn');
        btn.textContent = '✅ Copied!';
        btn.style.background = '#28a745';
        setTimeout(() => {
            btn.textContent = '📋 Copy';
            btn.style.background = 'linear-gradient(135deg,#667eea,#764ba2)';
        }, 2000);
    });
}

// ---- PRINT & PDF ----
function printRecipe() {
    window.print();
}

function downloadPDF() {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();

function cleanText(text) {
    return text
        .replace(/[\u{1F300}-\u{1FFFF}]/gu, '')   // remove emojis
        .replace(/[\u{2600}-\u{26FF}]/gu, '')       // remove misc symbols
        .replace(/[\u{2700}-\u{27BF}]/gu, '')       // remove dingbats
        .replace(/[^\x00-\x7F]/g, '')               // remove ALL non-ASCII characters
        .replace(/\s+/g, ' ')                        // clean extra spaces
        .trim();
}
    const title = cleanText(document.querySelector('.recipe-title').textContent);
    const metaTags = document.querySelectorAll('.meta-tag');
    const cuisine = cleanText(metaTags[0]?.textContent || '');
    const calories = cleanText(metaTags[1]?.textContent || '');
    const rating = cleanText(metaTags[2]?.textContent || '');
    const difficulty = cleanText(metaTags[3]?.textContent || '');

    const ingredientItems = document.querySelectorAll('.ingredients-list li');
    const ingredients = Array.from(ingredientItems).map(li => '• ' + cleanText(li.textContent));

    const instructionItems = document.querySelectorAll('.instructions-list li');
    const instructions = Array.from(instructionItems).map((li, i) => `${i + 1}. ${cleanText(li.textContent)}`);

    let y = 20;

    // Title
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(22);
    doc.setTextColor(102, 126, 234);
    doc.text(title, 105, y, { align: 'center' });
    y += 10;

    // Divider
    doc.setDrawColor(102, 126, 234);
    doc.line(15, y, 195, y);
    y += 8;

    // Meta info
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(11);
    doc.setTextColor(100, 100, 100);
    doc.text(`${cuisine}   |   ${calories}   |   ${rating}   |   ${difficulty}`, 105, y, { align: 'center' });
    y += 12;

    // Ingredients
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('Ingredients', 15, y);
    y += 7;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(11);
    doc.setTextColor(80, 80, 80);
    ingredients.forEach(ing => {
        if (y > 270) { doc.addPage(); y = 20; }
        doc.text(ing, 18, y);
        y += 6;
    });
    y += 6;

    // Instructions
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('Instructions', 15, y);
    y += 7;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(11);
    doc.setTextColor(80, 80, 80);
    instructions.forEach(step => {
        if (y > 270) { doc.addPage(); y = 20; }
        const lines = doc.splitTextToSize(step, 175);
        doc.text(lines, 18, y);
        y += lines.length * 6 + 2;
    });

    // Footer
    doc.setFontSize(9);
    doc.setTextColor(180, 180, 180);
    doc.text('Generated by ChefGPT', 105, 290, { align: 'center' });

    doc.save(`${title}.pdf`);
}