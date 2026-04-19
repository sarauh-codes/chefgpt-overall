function toggleStep(element) {
    element.classList.toggle('completed');
}

async function markAsCooked() {
    const confirmed = confirm('Have you finished cooking this recipe? You can rate it after!');
    if (!confirmed) return;
    
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
            document.getElementById('success-message').classList.add('show');
            setTimeout(() => {
                const giveReview = confirm('Would you like to rate this recipe now?');
                if (giveReview) {
                    window.location.href = `/recipe/${recipeId}`;
                } else {
                    window.location.href = '/cooked-history';
                }
            }, 1000);
        } else {
            alert('Error: ' + data.error);
        }
    } catch (error) {
        alert('Error marking recipe as cooked');
    }
}
