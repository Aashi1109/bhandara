#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

run_client=false
run_server=false

classify_file() {
  local file="$1"

  case "$file" in
    client/*)
      run_client=true
      ;;
    server/*)
      run_server=true
      ;;
    docs/*|*.md)
      ;;
    *)
      run_client=true
      run_server=true
      ;;
  esac
}

run_client_checks() {
  echo "Running client lint and tests..."
  (
    cd client
    flutter analyze
    flutter test
  )
}

run_server_checks() {
  echo "Running server lint and tests..."
  (
    cd server
    pnpm lint
    pnpm test
  )
}

if [[ "${1:-}" == "--all" ]]; then
  run_client=true
  run_server=true
else
  staged_files=()
  while IFS= read -r file; do
    staged_files+=("$file")
  done < <(git diff --cached --name-only --diff-filter=ACMR)

  if [[ "${#staged_files[@]}" -eq 0 ]]; then
    echo "No staged files. Skipping pre-commit checks."
    exit 0
  fi

  for file in "${staged_files[@]}"; do
    classify_file "$file"
  done
fi

if [[ "$run_client" == false && "$run_server" == false ]]; then
  echo "No client or server code changes detected. Skipping pre-commit checks."
  exit 0
fi

if [[ "$run_client" == true ]]; then
  run_client_checks
fi

if [[ "$run_server" == true ]]; then
  run_server_checks
fi
