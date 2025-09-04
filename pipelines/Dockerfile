# Use the official Python 3.11 image as base
FROM python:3.11-slim

# Set working directory inside the container
WORKDIR /app

# Copy requirements.txt first to leverage caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app
COPY . .

# Expose port 5000 to the host
EXPOSE 5000

# Command to run the app
CMD ["python", "app.py"]
