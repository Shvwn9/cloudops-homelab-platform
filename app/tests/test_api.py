from app.api.main import app


def test_health() -> None:
    app.config.update(TESTING=True)

    with app.test_client() as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_assets() -> None:
    app.config.update(TESTING=True)

    with app.test_client() as client:
        response = client.get("/api/assets")

    assert response.status_code == 200

    assets = response.get_json()

    assert isinstance(assets, list)
    assert len(assets) >= 1
    assert "hostname" in assets[0]