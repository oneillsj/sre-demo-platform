# Use lightweight Python base
FROM python:3.11-slim

# Set workdir
WORKDIR /app

# Install dependencies
RUN pip install flask prometheus-client

# Copy app
COPY app.py .

# Run app
CMD ["python", "app.py"]
