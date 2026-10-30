import pytest

from app import create_app


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setenv("FAIL_HEALTH", "false")
    monkeypatch.setenv("APP_VERSION", "1.0.0")
    monkeypatch.setenv("APP_COLOR", "blue")
    monkeypatch.setenv("COMPANY_NAME", "TechWave Solutions")
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
    application = create_app()
    application.config["TESTING"] = True
    return application.test_client()


def test_home_muestra_la_ranura(client):
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_data(as_text=True)
    assert "TechWave Solutions" in body
    assert "blue" in body


def test_health_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"
    assert response.get_json()["version"] == "1.0.0"


def test_health_falla_si_la_version_es_invalida(monkeypatch):
    monkeypatch.setenv("FAIL_HEALTH", "true")
    application = create_app()
    response = application.test_client().get("/health")
    assert response.status_code == 500


def test_catalogo(client):
    response = client.get("/api/services")
    assert response.status_code == 200
    names = [item["name"] for item in response.get_json()["services"]]
    assert "Plataforma Kubernetes" in names


def test_metricas(client):
    client.get("/health")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"techwave_http_requests_total" in response.data
