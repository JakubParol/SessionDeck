#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-SessionDeck}"
TIMEOUT_SECONDS="${SESSIONDECK_WINDOW_READINESS_TIMEOUT_SECONDS:-10}"
SLEEP_SECONDS="${SESSIONDECK_WINDOW_READINESS_POLL_SECONDS:-0.25}"

wait_for_main_window() {
  local deadline
  deadline=$((SECONDS + TIMEOUT_SECONDS))

  while (( SECONDS <= deadline )); do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
      sleep "$SLEEP_SECONDS"
      continue
    fi

    if /usr/bin/osascript >/dev/null 2>&1 <<APPLESCRIPT
tell application "System Events"
  if exists process "$APP_NAME" then
    tell process "$APP_NAME"
      if (count of windows) > 0 then return "ready"
    end tell
  end if
end tell
return "not-ready"
APPLESCRIPT
    then
      echo "SessionDeck window readiness: main window detected for $APP_NAME."
      return 0
    fi

    sleep "$SLEEP_SECONDS"
  done

  echo "SessionDeck window readiness timed out for $APP_NAME after ${TIMEOUT_SECONDS}s." >&2
  return 1
}

wait_for_main_window
