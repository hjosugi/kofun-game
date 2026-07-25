#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: scripts/run-software.sh COMMAND [ARGS...]" >&2
  exit 2
fi

# Nix-built OpenGL apps on non-NixOS need a wrapper that exposes the host
# driver. This is the usual cause of "Could not get EGL display" on WSL.
if command -v nixGLIntel >/dev/null 2>&1 && [[ ! -e /run/current-system/nixos-version ]]; then
  exec nixGLIntel "$@"
fi

# On NixOS (or when nixGL is unavailable), Mesa's llvmpipe is the fallback.
export LIBGL_ALWAYS_SOFTWARE=1
export SDL_VIDEO_X11_FORCE_EGL=0

if [[ -n "${DISPLAY:-}" ]]; then
  export SDL_VIDEODRIVER=x11
  exec "$@"
fi

if command -v xvfb-run >/dev/null 2>&1; then
  exec xvfb-run -a -s "-screen 0 1280x720x24" "$@"
fi

echo "No display is available and xvfb-run was not found." >&2
echo "Enter 'nix develop' or run the Phaser Canvas version instead." >&2
exit 1
