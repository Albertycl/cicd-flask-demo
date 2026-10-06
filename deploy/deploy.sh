#!/usr/bin/env bash
# Deploy one tested commit to this VM. Usage: deploy.sh <commit-sha>
set -euo pipefail

SHA="${1:?usage: deploy.sh <commit-sha>}"
[[ $SHA =~ ^[0-9a-f]{40}$ ]] || { echo "not a full commit sha: $SHA" >&2; exit 2; }

APP="$HOME/apps/cicd-flask-demo"
REL="$APP/releases/$SHA"
NEW="$REL.new"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT=cicd-flask-demo.service
URL=http://127.0.0.1:8088

# healthy [sha]: /health is ok and, if a sha is given, the page shows it
healthy() {
  local out
  out="$(curl -fsS --max-time 3 "$URL/health")" || return 1
  [[ $out == *'"ok"'* ]] || return 1
  if [ -n "${1:-}" ]; then
    out="$(curl -fsS --max-time 3 "$URL/")" || return 1
    [[ $out == *"$1"* ]] || return 1
  fi
}

PREV_LINK="$(readlink "$APP/current" 2>/dev/null || true)"
PREV_ENV="$(cat "$APP/app.env" 2>/dev/null || true)"
switched=0

rollback() {
  trap - ERR
  echo "deploy of $SHA failed" >&2
  if [ "$switched" = 1 ]; then
    if [ -n "$PREV_LINK" ]; then
      ln -sfn "$PREV_LINK" "$APP/current"
      printf '%s\n' "$PREV_ENV" > "$APP/app.env"
      systemctl --user reset-failed "$UNIT" || true
      systemctl --user restart "$UNIT" || true
      sleep 2
      if healthy; then echo "rolled back to $PREV_LINK" >&2; else echo "ROLLBACK ALSO UNHEALTHY" >&2; fi
    else
      systemctl --user stop "$UNIT" || true
      echo "first deploy failed, service stopped" >&2
    fi
  fi
  exit 1
}
trap rollback ERR

mkdir -p "$APP/releases" "$UNIT_DIR"

# 1. copy exactly the tracked files of the tested commit
rm -rf "$NEW"
mkdir -p "$NEW"
git -C "$SRC" archive "$SHA" | tar -x -C "$NEW"

# 2. shared virtualenv with the app's dependencies
[ -x "$APP/venv/bin/pip" ] || { rm -rf "$APP/venv"; python3 -m venv "$APP/venv"; }
"$APP/venv/bin/pip" install -q -r "$NEW/requirements.txt"

# 3. put the release in place and switch to it
rm -rf "$REL"
mv "$NEW" "$REL"
switched=1
printf 'APP_VERSION=%s\n' "$SHA" > "$APP/app.env"
ln -sfn "$REL" "$APP/current"

# 4. install the service unit and restart the app
install -m 644 "$REL/deploy/$UNIT" "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable "$UNIT"
systemctl --user reset-failed "$UNIT" || true
systemctl --user restart "$UNIT"

# 5. health check: /health is ok AND the page shows this commit
for _ in $(seq 1 15); do
  if healthy "$SHA"; then
    echo "deployed $SHA"
    ls -1dt "$APP"/releases/* | tail -n +6 | xargs -r rm -rf
    exit 0
  fi
  sleep 1
done
rollback
