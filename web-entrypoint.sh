#!/bin/sh
set -eu

index=/usr/share/nginx/html/index.html

# The official web image is a static nginx build whose published index defaults
# to Standard Notes' hosted services. Point this self-hosted copy at the local
# sync/files services and disable the hosted websocket endpoint before nginx
# serves any client assets.
sed -i \
  -e 's#window.defaultSyncServer = "https://api.standardnotes.com";#window.defaultSyncServer = "https://journal-sync.jdealla.com";#' \
  -e 's#window.defaultFilesHost = "https://files.standardnotes.com";#window.defaultFilesHost = "https://journal-files.jdealla.com";#' \
  -e 's#window.websocketUrl = "wss://sockets.standardnotes.com";#window.websocketUrl = "";#' \
  "$index"

grep -Fq 'window.defaultSyncServer = "https://journal-sync.jdealla.com";' "$index"
grep -Fq 'window.defaultFilesHost = "https://journal-files.jdealla.com";' "$index"
grep -Fq 'window.websocketUrl = "";' "$index"

exec nginx -g 'daemon off;'
