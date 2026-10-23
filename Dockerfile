# Node.js 22 LTS oficial (Debian trixie trae nodejs 20, EOL)
FROM node:22.23.4-trixie-slim@sha256:8eb619e402eaede1748a3c8173bffab391592812e85136452f781741c7242ddf AS node

# Use an official Python runtime as a parent image
FROM python:3.12.15-slim-trixie@sha256:a0f57064cbdcd6285fa45f51237ab0b35ea8ebaed06a1f5973e89e19dfb86704

# Install Java (required for PlantUML JAR) and Chromium (required for Mermaid CLI)
RUN apt-get update && apt-get install -y \
    openjdk-21-jre-headless \
    graphviz \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS + npm desde la imagen oficial
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Install Mermaid CLI (mmdc) — use system Chromium, skip Puppeteer's own download
# Version y arbol de dependencias fijados a lo desplegado (11.12.0, resuelto al 2026-03-11)
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
RUN npm install -g @mermaid-js/mermaid-cli@11.12.0 --before=2026-03-11T13:50:00Z \
    && npm cache clean --force

# Set environment variables
ENV PLANTUML_JAR=/app/plantuml.jar
ENV PORT=8080

# Create app directory
WORKDIR /app

# Copy PlantUML JAR to the container (v1.2026.2, la misma que estaba desplegada)
ADD https://github.com/plantuml/plantuml/releases/download/v1.2026.2/plantuml-1.2026.2.jar /app/plantuml.jar
RUN echo "3cdce52133c424dea22425b947ae9d47f2167b0866dfcf99e714d4ea1689975c  /app/plantuml.jar" | sha256sum -c -

# Puppeteer config: use system Chromium with no-sandbox (required in containers)
COPY puppeteer-config.json /app/puppeteer-config.json

# Install Python dependencies (versiones fijadas a lo desplegado)
COPY constraints.txt /tmp/constraints.txt
RUN pip install -c /tmp/constraints.txt flask boto3

# Copy the API code
COPY api.py /app/api.py

# Expose the application port
EXPOSE $PORT

# Run the API
CMD ["python", "/app/api.py"]
