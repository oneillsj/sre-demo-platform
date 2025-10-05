from flask import Flask, request, Response
import time
from prometheus_client import Counter, Histogram, generate_latest

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint"])
REQUEST_LATENCY = Histogram("http_request_latency_seconds", "Request latency", ["endpoint"])

@app.route("/healthz")
def healthz():
    REQUEST_COUNT.labels(method="GET", endpoint="/healthz").inc()
    return "OK", 200

@app.route("/compute")
def compute():
    REQUEST_COUNT.labels(method="GET", endpoint="/compute").inc()
    start = time.time()
    try:
        n = int(request.args.get("n", 10))
        result = n ** 2
        latency = time.time() - start
        REQUEST_LATENCY.labels(endpoint="/compute").observe(latency)
        return {"input": n, "result": result}, 200
    except Exception:
        latency = time.time() - start
        REQUEST_LATENCY.labels(endpoint="/compute").observe(latency)
        return {"error": "invalid input"}, 400

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain; charset=utf-8")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
