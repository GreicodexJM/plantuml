# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Install Java (required for PlantUML JAR)
RUN apt-get update && apt-get install -y \
    openjdk-17-jre-headless \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PLANTUML_JAR=/app/plantuml.jar
ENV PORT=8080

# Create app directory
WORKDIR /app

# Copy PlantUML JAR to the container
ADD https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar /app/plantuml.jar

# Install Flask for the API
RUN pip install flask
RUN pip install boto3

# Copy the API code
COPY api.py /app/api.py

# Expose the application port
EXPOSE $PORT

# Run the API
#CMD ["python", "/app/api.py"]
CMD ["java","-jar","/app/plantuml.jar","-picoweb","-verbose"]

