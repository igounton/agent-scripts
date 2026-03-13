#!/usr/bin/env bash
set -euo pipefail

PRL_GUEST_PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
PRL_GUEST_NODE=/opt/homebrew/bin/node
PRL_GUEST_NPM_CLI=/opt/homebrew/lib/node_modules/npm/bin/npm-cli.js
PRL_GUEST_PNPM_CLI=/opt/homebrew/lib/node_modules/pnpm/bin/pnpm.cjs
PRL_GUEST_OPENCLAW_ROOT=/opt/homebrew/lib/node_modules/openclaw

prl_die() {
  echo "error: $*" >&2
  exit 1
}

prl_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || prl_die "$1 not found"
}

prl_require_prlctl() {
  prl_require_cmd prlctl
}

prl_require_node() {
  [[ -x "$PRL_GUEST_NODE" ]] || prl_die "guest node missing at $PRL_GUEST_NODE"
}

prl_exec_node() {
  local vm=$1
  shift
  prlctl exec "$vm" --current-user /usr/bin/env PATH="$PRL_GUEST_PATH" "$PRL_GUEST_NODE" "$@"
}

prl_exec_env_node() {
  local vm=$1
  shift
  local env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done
  prlctl exec "$vm" --current-user /usr/bin/env PATH="$PRL_GUEST_PATH" "${env_args[@]}" \
    "$PRL_GUEST_NODE" "$@"
}

prl_exec_sh() {
  local vm=$1
  shift
  prlctl exec "$vm" --current-user /usr/bin/env PATH="$PRL_GUEST_PATH" /bin/sh -lc "$*"
}

prl_guest_home() {
  local vm=$1
  prlctl exec "$vm" --current-user /usr/bin/env PATH="$PRL_GUEST_PATH" /usr/bin/printenv HOME
}

prl_ensure_pnpm() {
  local vm=$1
  local pnpm_spec=${PRL_GUEST_PNPM_SPEC:-pnpm@10.23.0}
  if prlctl exec "$vm" --current-user /bin/test -f "$PRL_GUEST_PNPM_CLI" >/dev/null 2>&1; then
    return 0
  fi
  prl_exec_node "$vm" "$PRL_GUEST_NPM_CLI" install -g "$pnpm_spec"
  prlctl exec "$vm" --current-user /bin/test -f "$PRL_GUEST_PNPM_CLI" >/dev/null 2>&1 ||
    prl_die "guest pnpm missing after install: $PRL_GUEST_PNPM_CLI"
}

prl_run_pnpm() {
  local vm=$1
  local repo_dir=$2
  shift 2
  prl_ensure_pnpm "$vm"
  prlctl exec "$vm" --current-user \
    /usr/bin/env PATH="$PRL_GUEST_PATH" \
    "$PRL_GUEST_NODE" \
    "$PRL_GUEST_PNPM_CLI" \
    --dir "$repo_dir" \
    "$@"
}

prl_resolve_openclaw_entry() {
  local vm=$1
  local candidate
  for candidate in \
    "$PRL_GUEST_OPENCLAW_ROOT/dist/entry.js" \
    "$PRL_GUEST_OPENCLAW_ROOT/dist/index.js" \
    "$PRL_GUEST_OPENCLAW_ROOT/entry.js" \
    "$PRL_GUEST_OPENCLAW_ROOT/index.js" \
    "$PRL_GUEST_OPENCLAW_ROOT/openclaw.mjs"
  do
    if prlctl exec "$vm" --current-user /bin/test -f "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

prl_run_openclaw() {
  local vm=$1
  shift
  local entry
  entry=$(prl_resolve_openclaw_entry "$vm") || prl_die "guest OpenClaw entrypoint not found"
  prl_exec_node "$vm" "$entry" "$@"
}

prl_run_openclaw_env() {
  local vm=$1
  shift
  local env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done
  local entry
  entry=$(prl_resolve_openclaw_entry "$vm") || prl_die "guest OpenClaw entrypoint not found"
  prl_exec_env_node "$vm" "${env_args[@]}" "$entry" "$@"
}

prl_resolve_repo_openclaw_entry() {
  local vm=$1
  local repo_or_entry=$2
  local candidate
  if [[ "$repo_or_entry" == *.mjs || "$repo_or_entry" == *.js || "$repo_or_entry" == *.cjs ]]; then
    candidate=$repo_or_entry
    if prlctl exec "$vm" --current-user /bin/test -f "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
    return 1
  fi
  for candidate in \
    "$repo_or_entry/openclaw.mjs" \
    "$repo_or_entry/dist/entry.js" \
    "$repo_or_entry/dist/index.js"
  do
    if prlctl exec "$vm" --current-user /bin/test -f "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

prl_download_to_guest() {
  local vm=$1
  local url=$2
  local guest_path=$3
  local guest_dir
  guest_dir=$(dirname "$guest_path")
  prlctl exec "$vm" --current-user /bin/mkdir -p "$guest_dir"
  prlctl exec "$vm" --current-user /usr/bin/curl -fsSL -o "$guest_path" "$url"
}

prl_kill_port_listener() {
  local vm=$1
  local port=$2
  prl_exec_sh "$vm" "pids=\$(/usr/sbin/lsof -tiTCP:$port -sTCP:LISTEN 2>/dev/null || true); if [ -n \"\$pids\" ]; then /bin/kill -9 \$pids >/dev/null 2>&1 || true; fi"
}

prl_spawn_detached() {
  local vm=$1
  shift
  local env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done
  local log_path=${1:?missing log path}
  shift
  prlctl exec "$vm" --current-user /usr/bin/env PATH="$PRL_GUEST_PATH" "${env_args[@]}" \
    /usr/bin/python3 -c 'import subprocess, sys
log = open(sys.argv[1], "ab", buffering=0)
proc = subprocess.Popen(
    sys.argv[2:],
    stdin=subprocess.DEVNULL,
    stdout=log,
    stderr=subprocess.STDOUT,
    start_new_session=True,
)
print(proc.pid)
' "$log_path" "$@"
}

prl_run_openclaw_detached_env() {
  local vm=$1
  shift
  local env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done
  local log_path=${1:?missing log path}
  shift
  local entry
  entry=$(prl_resolve_openclaw_entry "$vm") || prl_die "guest OpenClaw entrypoint not found"
  prl_spawn_detached "$vm" "${env_args[@]}" "$log_path" "$PRL_GUEST_NODE" "$entry" "$@"
}

prl_parse_openclaw_version() {
  local raw=$1
  local version
  version=$(printf '%s\n' "$raw" | /usr/bin/perl -ne 'if (/(20[0-9]{2}\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.]+)?)/) { print "$1\n"; exit 0 }')
  [[ -n "$version" ]] || prl_die "could not parse OpenClaw version from: $raw"
  printf '%s\n' "$version"
}
