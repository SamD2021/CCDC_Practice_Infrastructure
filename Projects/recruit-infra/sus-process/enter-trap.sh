#!/usr/bin/env bash
set -euo pipefail

# Bypass for graders/admins or scripted checks
if [[ "${NO_TRAP:-}" == "1" ]]; then
  exit 0
fi

# Avoid recursion: if we're already inside the trap, do nothing
if [[ "${INSIDE_TRAP:-}" == "1" ]]; then
  exit 0
fi

PODMAN=podman
TRAP_NAME="recruit-trap"
TRAP_IMAGE="quay.io/samueldasilva/recruit-task:trap"

# prefer podman from PATH; fail gracefully if not present
if ! command -v $PODMAN >/dev/null 2>&1; then
  echo "enter-trap: podman not found; continuing on host shell" >&2
  exit 0
fi

# Try to ensure the image exists (best-effort)
if ! $PODMAN image exists "$TRAP_IMAGE"; then
  # try to pull, but don't fail the login if network/pull fails
  $PODMAN pull "$TRAP_IMAGE" >/dev/null 2>&1 || true
fi

# If container doesn't exist, create it (keep it running via sleep infinity)
if ! $PODMAN container exists "$TRAP_NAME"; then
  HOSTNAME="$(hostname)"
  # We purposely use --network host so network tools behave as expected in the trap.
  $PODMAN run -d --name "$TRAP_NAME" \
    --hostname "$HOSTNAME" \
    --network host \
    --rm=false \
    "$TRAP_IMAGE" sleep infinity >/dev/null 2>&1 || true
fi

# Start container if not running
$PODMAN start "$TRAP_NAME" >/dev/null 2>&1 || true

# Exec the current user inside the container with a login shell
# Pass INSIDE_TRAP=1 to prevent recursive re-entry
exec $PODMAN exec -it \
  -e INSIDE_TRAP=1 \
  -u "recruit" \
  "$TRAP_NAME" /bin/bash --login
