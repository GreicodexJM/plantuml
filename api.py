from flask import Flask, request, jsonify, send_file
import subprocess
import tempfile
import os
import logging
import boto3
from botocore.client import Config
from datetime import datetime
import uuid

app = Flask(__name__)

PLANTUML_JAR = os.getenv("PLANTUML_JAR", "/app/plantuml.jar").strip()
PUPPETEER_CONFIG = os.getenv("PUPPETEER_CONFIG", "/app/puppeteer-config.json").strip()
SPACE_REGION = os.getenv("SPACE_REGION", "nyc3").strip()

SPACE_BUCKET = os.getenv("SPACE_BUCKET").strip()
SPACE_ENDPOINT = f"https://{SPACE_REGION}.digitaloceanspaces.com"
SPACE_ACCESS_KEY = os.getenv("SPACE_ACCESS_KEY").strip()
SPACE_SECRET_KEY = os.getenv("SPACE_SECRET_KEY").strip()
SPACE_FOLDER = os.getenv("SPACE_FOLDER", "diagrams").strip()

s3 = boto3.client('s3',
    region_name=SPACE_REGION,
    endpoint_url=SPACE_ENDPOINT,
    aws_access_key_id=SPACE_ACCESS_KEY,
    aws_secret_access_key=SPACE_SECRET_KEY,
    config=Config(signature_version='s3v4')
)


def _upload_or_download(png_path, data):
    """Return PNG as download or upload to S3 and return a JSON URL response."""
    if data.get("download") is True:
        return send_file(png_path, mimetype="image/png", as_attachment=False, download_name="diagram.png")

    unique_name = f"{SPACE_FOLDER}/{datetime.now().strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex}.png"
    with open(png_path, "rb") as file_data:
        s3.upload_fileobj(
            file_data,
            SPACE_BUCKET,
            unique_name,
            ExtraArgs={'ContentType': 'image/png', 'ACL': 'public-read'}
        )

    image_url = f"https://{SPACE_BUCKET}.{SPACE_REGION}.digitaloceanspaces.com/{unique_name}"
    return jsonify({
        "type": "image",
        "source": "url",
        "url": image_url,
        "description": "This is a public URL to the generated diagram."
    })


@app.route("/plantuml2png", methods=["POST"])
def plantuml_to_png():
    try:
        data = request.get_json()
        if not data or "diagram" not in data:
            return jsonify({"error": "Missing 'diagram' key in request body"}), 400

        plantuml_source = data["diagram"]
        logging.warning("plantuml2png: received diagram source")

        with tempfile.TemporaryDirectory() as temp_dir:
            puml_path = os.path.join(temp_dir, "diagram.puml")
            png_path = os.path.join(temp_dir, "diagram.png")

            with open(puml_path, "w") as f:
                f.write(plantuml_source)

            subprocess.run(
                ["java", "-jar", PLANTUML_JAR, "-tpng", puml_path, "-o", temp_dir],
                check=True
            )

            return _upload_or_download(png_path, data)

    except subprocess.CalledProcessError as e:
        return jsonify({"error": "Failed to generate PNG", "details": str(e)}), 500
    except Exception as e:
        return jsonify({"error": "An error occurred", "details": str(e)}), 500


@app.route("/mermaid2png", methods=["POST"])
def mermaid_to_png():
    try:
        data = request.get_json()
        if not data or "diagram" not in data:
            return jsonify({"error": "Missing 'diagram' key in request body"}), 400

        mermaid_source = data["diagram"]
        logging.warning("mermaid2png: received diagram source")

        with tempfile.TemporaryDirectory() as temp_dir:
            mmd_path = os.path.join(temp_dir, "diagram.mmd")
            png_path = os.path.join(temp_dir, "diagram.png")

            with open(mmd_path, "w") as f:
                f.write(mermaid_source)

            subprocess.run(
                ["mmdc", "-i", mmd_path, "-o", png_path, "-p", PUPPETEER_CONFIG],
                check=True
            )

            return _upload_or_download(png_path, data)

    except subprocess.CalledProcessError as e:
        return jsonify({"error": "Failed to generate PNG", "details": str(e)}), 500
    except Exception as e:
        return jsonify({"error": "An error occurred", "details": str(e)}), 500


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
