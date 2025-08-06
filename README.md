# PlantUML as a Service

This project provides a PlantUML-as-a-Service API that converts PlantUML diagram source code into PNG images. The service can be deployed using Docker, Docker Compose, Kubernetes (with Helm), or as a serverless function on platforms like `faasd`.

The core of the project is a Flask-based Python API that receives PlantUML source code, generates a PNG file using the PlantUML JAR, and then either returns the image directly or uploads it to a DigitalOcean Space, returning the public URL.

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
  - [API Endpoint](#api-endpoint)
  - [Docker](#docker)
  - [Docker Compose](#docker-compose)
  - [Kubernetes with Helm](#kubernetes-with-helm)
- [Configuration](#configuration)
- [Development](#development)

## Features

-   **PlantUML to PNG Conversion**: Converts PlantUML source to a PNG image.
-   **Direct Download or URL**: Option to either download the generated PNG directly or upload it to a DigitalOcean Space and receive a public URL.
-   **Multiple Deployment Options**: Can be deployed using Docker, Docker Compose, Kubernetes (Helm), or as a serverless function.
-   **Infrastructure as Code**: Includes Terraform scripts for setting up the necessary infrastructure on DigitalOcean.

## Project Structure

```
.
├── .gitignore
├── api.py                      # The Flask API for PlantUML conversion.
├── chart-packages/             # Packaged Helm charts.
├── dev-ops/                    # Terraform scripts for infrastructure setup.
├── diagram.puml                # Example PlantUML diagram.
├── docker-compose.faasd.yaml   # Docker Compose for faasd deployment.
├── docker-compose.yaml         # Docker Compose for local deployment.
├── Dockerfile                  # Dockerfile for building the service image.
├── k8s-serverless.yaml         # Kubernetes manifest for serverless deployment.
├── letsencrypt-issuers.yaml    # Kubernetes manifests for cert-manager issuers.
├── Makefile                    # Makefile with helper commands.
├── openapi.json                # OpenAPI specification for the API.
├── plantuml/                   # Helm chart for Kubernetes deployment.
├── plantuml.skin               # PlantUML skin parameters.
└── values.yaml                 # Default values for the Helm chart.
```

## Prerequisites

-   [Docker](https://www.docker.com/get-started)
-   [Docker Compose](https://docs.docker.com/compose/install/)
-   [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (for Kubernetes deployment)
-   [Helm](https://helm.sh/docs/intro/install/) (for Kubernetes deployment)
-   [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (for infrastructure setup)
-   A DigitalOcean account and an S3-compatible Space for image storage.

## Usage

### API Endpoint

The service exposes a single endpoint:

-   **`POST /plantuml2png`**

    This endpoint converts a PlantUML diagram to a PNG image.

    **Request Body:**

    ```json
    {
      "diagram": "plantuml source code here",
      "download": false
    }
    ```

    -   `diagram` (required): A string containing the PlantUML source code.
    -   `download` (optional): A boolean. If `true`, the generated PNG is returned directly in the response. If `false` or omitted, the image is uploaded to a DigitalOcean Space and a JSON response with the public URL is returned.

    **Success Response (download: false):**

    ```json
    {
        "type": "image",
        "source": "url",
        "url": "https://your-space-bucket.nyc3.digitaloceanspaces.com/diagrams/your-diagram.png",
        "description": "This is a public URL to the generated UML diagram."
    }
    ```

### Docker

1.  **Build the Docker image:**

    ```sh
    docker build -t plantuml-api .
    ```

2.  **Run the Docker container:**

    You need to provide the necessary environment variables for the DigitalOcean Space.

    ```sh
    docker run -p 8080:8080 \
      -e SPACE_BUCKET="your-space-bucket" \
      -e SPACE_ACCESS_KEY="your-space-access-key" \
      -e SPACE_SECRET_KEY="your-space-secret-key" \
      plantuml-api
    ```

### Docker Compose

1.  **Create a `.env` file** with your DigitalOcean Space credentials:

    ```
    SPACE_BUCKET=your-space-bucket
    SPACE_ACCESS_KEY=your-space-access-key
    SPACE_SECRET_KEY=your-space-secret-key
    ```

2.  **Run with Docker Compose:**

    ```sh
    docker-compose up
    ```

### Kubernetes with Helm

The project includes a Helm chart in the `plantuml/` directory for deploying to a Kubernetes cluster.

1.  **Package the chart (if not already packaged):**

    ```sh
    helm package plantuml/
    ```

2.  **Install the chart:**

    You can override the default values by creating a custom `values.yaml` file or by using the `--set` flag.

    ```sh
    helm install plantuml ./chart-packages/plantuml-0.1.1.tgz \
      --set space.bucket="your-space-bucket" \
      --set space.accessKey="your-space-access-key" \
      --set space.secretKey="your-space-secret-key"
    ```

## Configuration

The application is configured via environment variables:

| Variable           | Description                                       | Default      |
| ------------------ | ------------------------------------------------- | ------------ |
| `PORT`             | The port on which the Flask application runs.     | `8080`       |
| `PLANTUML_JAR`     | Path to the PlantUML JAR file.                    | `/app/plantuml.jar` |
| `SPACE_REGION`     | The region of the DigitalOcean Space.             | `nyc3`       |
| `SPACE_BUCKET`     | The name of the DigitalOcean Space bucket.        | **Required** |
| `SPACE_ACCESS_KEY` | The access key for the DigitalOcean Space.        | **Required** |
| `SPACE_SECRET_KEY` | The secret key for the DigitalOcean Space.        | **Required** |
| `SPACE_FOLDER`     | The folder within the bucket to store diagrams.   | `diagrams`   |

## Development

To run the application locally for development, you can use Flask's built-in server.

1.  **Install dependencies:**

    ```sh
    pip install -r requirements.txt
    ```
    *(Note: You will need to create a `requirements.txt` file with `Flask` and `boto3`)*

2.  **Set environment variables:**

    ```sh
    export FLASK_APP=api.py
    export FLASK_ENV=development
    export SPACE_BUCKET=...
    export SPACE_ACCESS_KEY=...
    export SPACE_SECRET_KEY=...
    ```

3.  **Run the Flask app:**

    ```sh
    flask run
