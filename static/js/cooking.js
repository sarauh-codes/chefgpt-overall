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
