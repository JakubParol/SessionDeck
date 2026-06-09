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

    local readiness_output
    readiness_output=$(detect_visible_main_window "$APP_NAME"
) || readiness_output="not-ready"
    if [[ "$readiness_output" == "ready" ]]; then
      echo "SessionDeck window readiness: main window detected for $APP_NAME."
      return 0
    fi

    sleep "$SLEEP_SECONDS"
  done

  echo "SessionDeck window readiness timed out for $APP_NAME after ${TIMEOUT_SECONDS}s." >&2
  return 1
}

detect_visible_main_window() {
  local app_name="$1"
  /usr/bin/swift - "$app_name" <<'SWIFT'
import CoreGraphics
import Foundation

let appName = CommandLine.arguments.last ?? "SessionDeck"
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

let isReady = windows.contains { window in
    guard window[kCGWindowOwnerName as String] as? String == appName,
          window[kCGWindowLayer as String] as? Int == 0,
          let bounds = window[kCGWindowBounds as String] as? [String: Any] else {
        return false
    }

    let width = bounds["Width"] as? Double ?? 0
    let height = bounds["Height"] as? Double ?? 0
    return width > 0 && height > 0
}

print(isReady ? "ready" : "not-ready")
SWIFT
}

wait_for_main_window
