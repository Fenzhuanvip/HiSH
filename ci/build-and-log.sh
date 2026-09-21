#!/bin/bash
set -x

{
  echo "=== Build $(date) ==="
  bash ci/build-hap-codearts.sh 2>&1
  echo "=== Exit: $? ==="
} | tee /tmp/build-output.txt

cp /tmp/build-output.txt ci/build-log.txt 2>/dev/null || true
git add ci/build-log.txt 2>/dev/null || true
git commit -m "Build log" 2>/dev/null || true
git push origin master 2>&1 || echo "Git push failed - trying output"
