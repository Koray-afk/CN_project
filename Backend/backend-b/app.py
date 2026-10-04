from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def home():
    response = jsonify({
        "backend": "B",
        "status": "running"
    })
    response.headers["X-Backend"] = "B"
    return response


@app.route("/api/status")
def status():
    response = jsonify({
        "backend": "B",
        "status": "ok"
    })
    response.headers["X-Backend"] = "B"
    response.headers["Cache-Control"] = "max-age=60"
    return response


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3002)
    