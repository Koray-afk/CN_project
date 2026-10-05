from flask import Flask, jsonify, request

BACKEND = "A"
PORT = 3001

app = Flask(__name__)


@app.after_request
def add_backend_header(response):
    response.headers["X-Backend"] = BACKEND
    return response


@app.route("/")
def home():
    return jsonify({"backend": BACKEND, "status": "running"})


@app.route("/api/status")
def status():
    response = jsonify({"backend": BACKEND, "status": "ok"})
    response.headers["Cache-Control"] = "no-store"
    return response


@app.route("/api/cached")
def cached():
    # identical body on both backends, so the ETag is identical too
    response = jsonify({"message": "cached content", "ttl": 60})
    response.headers["Cache-Control"] = "public, max-age=60"
    response.add_etag()
    return response.make_conditional(request)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)