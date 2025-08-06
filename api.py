from flask import Flask, request, jsonify, send_file
import subprocess
import tempfile
import os
import base64
import logging
import boto3
from botocore.client import Config
from datetime import datetime
import uuid

app = Flask(__name__)

PLANTUML_JAR = os.getenv("PLANTUML_JAR", "/app/plantuml.jar").strip()
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

@app.route("/plantuml2png", methods=["POST"])
def plantuml_to_png():
    try:
        # Get PlantUML diagram source from the request
        data = request.get_json()
        if not data or "diagram" not in data:
            return jsonify({"error": "Missing 'diagram' key in request body"}), 400

        plantuml_source = data["diagram"]
        logging.warning("Got data: %s" % plantuml_source)
        # Use a temporary directory for processing
        with tempfile.TemporaryDirectory() as temp_dir:
            logging.warning("TempDir openened")
            if not os.path.exists(temp_dir):
                os.makedirs(temp_dir)
            # Write the PlantUML source to a .puml file
            puml_path = os.path.join(temp_dir, "diagram.puml")
            logging.warning("Opening file %s" % puml_path)
            with open(puml_path, "w") as puml_file:
                logging.warning("File open")
                r=puml_file.write(plantuml_source)
                logging.warning("File written %d" % r)

            logging.warning("Generate the PNG file using the PlantUML JAR")
            png_path = os.path.join(temp_dir, "diagram.png")
            logging.warning("Png path %s" % png_path)
            subprocess.run(
                ["java", "-jar", PLANTUML_JAR, "-tpng", puml_path, "-o", temp_dir],
                check=True
            )
            logging.warning("Sub process ran")
            
            if data and "download" in data and data["download"] == True:
                logging.warning("Send the PNG file as a response")
                return send_file(
                    png_path,
                    mimetype="image/png",
                    as_attachment=False,
                    download_name="diagram.png"
                )
            # Generate unique filename and upload to DigitalOcean Space
            unique_name = f"{SPACE_FOLDER}/{datetime.now().strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex}.png"
            with open(png_path, "rb") as file_data:
                s3.upload_fileobj(
                    file_data,
                    SPACE_BUCKET,
                    unique_name,
                    ExtraArgs={
                        'ContentType': 'image/png',
                        'ACL': 'public-read'
                    }
                )

            image_url = f"https://{SPACE_BUCKET}.{SPACE_REGION}.digitaloceanspaces.com/{unique_name}"
            return jsonify({
                "type": "image",
                "source": "url",
                "url": image_url,
                "description": "This is a public URL to the generated UML diagram."
            })

            
        raise "Unable to process request"

    except subprocess.CalledProcessError as e:
        return jsonify({"error": "Failed to generate PNG", "details": str(e)}), 500
    except Exception as e:
        return jsonify({"error": "An error occurred", "details": str(e)}), 500

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    app.run(host="0.0.0.0", port=port)

