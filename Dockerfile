FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your project
COPY . .

# Expose HF Spaces default port
EXPOSE 7860

# Run with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:7860", "--timeout", "120", "app:app"]