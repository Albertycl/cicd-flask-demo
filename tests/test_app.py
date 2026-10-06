from app import app


def test_index_shows_title_and_version(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "abc1234")
    response = app.test_client().get("/")
    assert response.status_code == 200
    assert b"CI/CD demo!" in response.data
    assert b"abc1234" in response.data


def test_health_is_ok():
    response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_index_defaults_to_dev_version(monkeypatch):
    monkeypatch.delenv("APP_VERSION", raising=False)
    response = app.test_client().get("/")
    assert b"<code>dev</code>" in response.data
