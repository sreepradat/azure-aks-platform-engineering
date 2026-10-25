import pytest

import main


@pytest.fixture
def client():
    app = main.create_app()
    app.config.update(TESTING=True)
    return app.test_client()


def test_index_returns_service_metadata(client):
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_json()
    assert body["service"] == "sample-app"
    assert body["secret_loaded"] is False


def test_index_reports_mounted_secret(client, monkeypatch, tmp_path):
    secret_file = tmp_path / "app-message"
    secret_file.write_text("hello")
    monkeypatch.setattr(main, "SECRET_PATH", secret_file)

    assert client.get("/").get_json()["secret_loaded"] is True


@pytest.mark.parametrize("path", ["/healthz", "/readyz"])
def test_probes_return_200(client, path):
    assert client.get(path).status_code == 200


def test_metrics_expose_request_counter(client):
    client.get("/healthz")
    body = client.get("/metrics").get_data(as_text=True)
    assert "http_requests_total" in body
    assert "http_request_duration_seconds" in body


def test_unknown_route_returns_404(client):
    assert client.get("/does-not-exist").status_code == 404
