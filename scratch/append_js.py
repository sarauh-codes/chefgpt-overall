js_code = """
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
"""

with open("c:/Users/azree/chefgpt-overall/static/js/dashboard.js", "a", encoding="utf-8") as f:
    f.write(js_code)
