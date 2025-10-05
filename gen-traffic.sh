#!/usr/bin/env bash

URL=${1:-http://localhost/app/healthz}
END=$((SECONDS + 300))

while (( SECONDS < END )); do
  curl -s -o /dev/null -w "%{http_code}\n" "$URL"
  sleep 1
done