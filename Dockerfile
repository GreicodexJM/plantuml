# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Install Java (required for PlantUML JAR), Chromium + Node.js (required for Mermaid CLI)
RUN apt-get update && apt-get install -y \
    openjdk-21-jre-headless \
    graphviz \
    nodejs \
    npm \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Install Mermaid CLI (mmdc) — use system Chromium, skip Puppeteer's own download
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
RUN npm install -g @mermaid-js/mermaid-cli

# Set environment variables
ENV PLANTUML_JAR=/app/plantuml.jar
ENV PORT=8080

# Create app directory
WORKDIR /app

# Copy PlantUML JAR to the container
ADD https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar /app/plantuml.jar

# Puppeteer config: use system Chromium with no-sandbox (required in containers)
COPY puppeteer-config.json /app/puppeteer-config.json

# Install Python dependencies
RUN pip install flask boto3

# Copy the API code
COPY api.py /app/api.py

# Expose the application port
EXPOSE $PORT

# Run the API
CMD ["python", "/app/api.py"]
