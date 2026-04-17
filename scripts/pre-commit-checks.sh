#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

run_client=false
run_server=false

client_test_jobs() {
  local cpu_count=2
  local target_jobs=2

  if command -v getconf >/dev/null 2>&1; then
    cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
  elif command -v nproc >/dev/null 2>&1; then
    cpu_count="$(nproc 2>/dev/null || echo 2)"
  elif command -v sysctl >/dev/null 2>&1; then
    cpu_count="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 2)"
  fi

  if ! [[ "$cpu_count" =~ ^[0-9]+$ ]] || [[ "$cpu_count" -lt 2 ]]; then
    cpu_count=2
  fi

  target_jobs=$(( (cpu_count * 80) / 100 ))

  if [[ "$target_jobs" -lt 2 ]]; then
    target_jobs=2
  elif [[ "$target_jobs" -gt "$cpu_count" ]]; then
    target_jobs="$cpu_count"
  fi

  printf '%s\n' "$target_jobs"
}

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
  local analyze_status=0
  local test_status=0
  local test_jobs

  test_jobs="$(client_test_jobs)"

  echo "Running client lint and tests in parallel (flutter test --concurrency=$test_jobs)..."
  (
    cd client

    flutter analyze &
    local analyze_pid=$!

    flutter test --concurrency="$test_jobs" &
    local test_pid=$!

    wait "$analyze_pid" || analyze_status=$?
    wait "$test_pid" || test_status=$?

    if [[ "$analyze_status" -ne 0 || "$test_status" -ne 0 ]]; then
      return 1
    fi
  )
}

run_server_checks() {
  echo "Running server lint and tests..."
  (
    cd server
    pnpm email:build
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
