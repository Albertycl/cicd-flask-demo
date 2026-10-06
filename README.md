# cicd-flask-demo

A small Flask app used to learn CI/CD with GitHub Actions. No Docker, no Kubernetes.

## What the pipeline does

- **Pull request:** job `test` runs `ruff check .` and `pytest -q` on a GitHub-hosted runner. Branch protection on `main` needs a pull request and a green `test` check before it can merge.
- **Push to `main`:** `test` runs again, then job `deploy` runs on a self-hosted runner on my VM. It runs `deploy/deploy.sh`, which installs the tested commit, restarts the app with systemd and checks `/health`. If the check fails, it goes back to the previous release.
- The environment `production` can hold a deploy until a person approves it.

## Run it locally

```
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/ruff check .
.venv/bin/pytest -q
```
