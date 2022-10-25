#!/bin/sh
dbus-daemon --session --fork
Xvfb :1 -screen 0 "${XVFB_SCREEN_WIDTH}x${XVFB_SCREEN_HEIGHT}x24" >/dev/null 2>&1 &
fluxbox >/dev/null 2>&1