#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

run_client=false
run_server=false

resolve_bin() {
  local name="$1"
  shift

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  for candidate in "$@"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

flutter_bin="$(resolve_bin flutter /opt/homebrew/bin/flutter "$HOME/fvm/default/bin/flutter" "$HOME/flutter/bin/flutter")"
pnpm_bin="$(resolve_bin pnpm /opt/homebrew/bin/pnpm "$HOME/Library/pnpm/pnpm")"
shell_bin="${SHELL:-/bin/zsh}"

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

    "$shell_bin" -lc "'$flutter_bin' --no-version-check analyze" &
    local analyze_pid=$!

    "$shell_bin" -lc "'$flutter_bin' --no-version-check test --concurrency='$test_jobs'" &
    local test_pid=$!

    wait "$analyze_pid" || analyze_status=$?
    wait "$test_pid" || test_status=$?

    [[ "$analyze_status" -eq 0 && "$test_status" -eq 0 ]]
  )
}

run_server_checks() {
  echo "Running server lint and tests..."
  (
    cd server
    "$shell_bin" -lc "'$pnpm_bin' email:build"
    "$shell_bin" -lc "'$pnpm_bin' lint"
    "$shell_bin" -lc "'$pnpm_bin' test"
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

client_status=0
server_status=0

if [[ "$run_client" == true ]]; then
  run_client_checks || client_status=$?
fi

if [[ "$client_status" -ne 0 ]]; then
  exit 1
fi

if [[ "$run_server" == true ]]; then
  run_server_checks || server_status=$?
fi

if [[ "$server_status" -ne 0 ]]; then
  exit 1
fi
