import os

from flask import Flask, render_template

app = Flask(__name__)


@app.route("/")
def index():
    return render_template(
        "index.html",
        title="CI/CD demo",
        version=os.environ.get("APP_VERSION", "dev"),
    )


@app.route("/health")
def health():
    return {"status": "ok"}
