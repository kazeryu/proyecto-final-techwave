"""Panel de TechWave. La ranura y la versión llegan por variables de entorno."""

import os

from flask import Flask, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

REQUESTS = Counter(
    "techwave_http_requests_total",
    "Peticiones HTTP atendidas por la aplicación",
    ["path", "color", "status"],
)

SERVICES = [
    {"id": "tw-01", "name": "Auditoría DevOps", "status": "disponible"},
    {"id": "tw-02", "name": "Plataforma Kubernetes", "status": "disponible"},
    {"id": "tw-03", "name": "Observabilidad gestionada", "status": "disponible"},
]

PAGE = """<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>{company}</title>
  <style>
    body {{ margin: 0; background: #f3efe6; color: #243044; font-family: Georgia, serif; }}
    header {{ background: #1e3a5f; color: #fff; padding: 1.3rem 2rem 1.1rem; }}
    header h1 {{ margin: 0; font-size: 1.7rem; }}
    header p {{ margin: 0.45rem 0 0; font-family: sans-serif; font-size: 0.95rem; }}
    .slot {{ background: {color}; color: #fff; padding: 0.12rem 0.5rem; border-radius: 3px; }}
    main {{ padding: 1.4rem 2rem 0.4rem; }}
    main > p {{ max-width: 38rem; }}
    .cards {{ display: flex; gap: 0.8rem; flex-wrap: wrap; margin-top: 1rem; }}
    article {{ background: #fff; border: 1px solid #ddd4c4; width: 200px; padding: 0.7rem 0.9rem; }}
    article h2 {{ margin: 0 0 0.4rem; font-size: 1.05rem; }}
    .ok {{ margin: 0; color: #1d7a3a; font-family: sans-serif; font-size: 0.85rem; }}
    footer {{ font-family: sans-serif; color: #667; font-size: 0.82rem; padding: 0.2rem 2rem 1.6rem; }}
  </style>
</head>
<body>
  <header>
    <h1>{company}</h1>
    <p>Panel de publicación · versión <strong>{version}</strong>
       · ranura <span class="slot">{color}</span></p>
  </header>
  <main>
    <p>Lo que se ve aquí es la ranura que tiene el Service en este momento.
       La otra copia del despliegue no recibe peticiones hasta que se conmuta.</p>
    <div class="cards">{cards}</div>
  </main>
  <footer>TechWave Solutions</footer>
</body>
</html>
"""


def _flag(name: str) -> bool:
    return os.getenv(name, "false").strip().lower() in {"1", "true", "yes"}


def setup_telemetry(flask_app: Flask) -> None:
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "").strip()
    if not endpoint:
        return
    endpoint = endpoint.removeprefix("https://").removeprefix("http://")
    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
        from opentelemetry.instrumentation.flask import FlaskInstrumentor
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor

        resource = Resource.create(
            {
                "service.name": os.getenv("OTEL_SERVICE_NAME", "techwave"),
                "service.version": os.getenv("APP_VERSION", "1.0.0"),
            }
        )
        provider = TracerProvider(resource=resource)
        provider.add_span_processor(
            BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint, insecure=True))
        )
        trace.set_tracer_provider(provider)
        FlaskInstrumentor().instrument_app(flask_app)
    except Exception:
        flask_app.logger.exception("OpenTelemetry no se ha podido iniciar")


def create_app() -> Flask:
    flask_app = Flask(__name__)
    setup_telemetry(flask_app)

    @flask_app.get("/")
    def index():
        color = os.getenv("APP_COLOR", "blue")
        cards = "".join(
            "<article><h2>{name}</h2><p class=\"ok\">{status}</p></article>".format(**item)
            for item in SERVICES
        )
        return PAGE.format(
            company=os.getenv("COMPANY_NAME", "TechWave Solutions"),
            version=os.getenv("APP_VERSION", "1.0.0"),
            color=color,
            cards=cards,
        )

    @flask_app.get("/health")
    def health():
        if _flag("FAIL_HEALTH"):
            return jsonify(status="fail"), 500
        return jsonify(
            status="ok",
            color=os.getenv("APP_COLOR", "blue"),
            version=os.getenv("APP_VERSION", "1.0.0"),
        )

    @flask_app.get("/version")
    def version():
        return jsonify(
            version=os.getenv("APP_VERSION", "1.0.0"),
            color=os.getenv("APP_COLOR", "blue"),
            company=os.getenv("COMPANY_NAME", "TechWave Solutions"),
        )

    @flask_app.get("/api/services")
    def services():
        return jsonify(services=SERVICES)

    @flask_app.get("/metrics")
    def metrics():
        payload = generate_latest()
        return payload, 200, {"Content-Type": CONTENT_TYPE_LATEST}

    @flask_app.after_request
    def count(response):
        if request.path != "/metrics":
            REQUESTS.labels(
                path=request.path,
                color=os.getenv("APP_COLOR", "blue"),
                status=str(response.status_code),
            ).inc()
            flask_app.logger.info(
                "path=%s status=%s color=%s version=%s",
                request.path,
                response.status_code,
                os.getenv("APP_COLOR", "blue"),
                os.getenv("APP_VERSION", "1.0.0"),
            )
        return response

    return flask_app


app = create_app()
