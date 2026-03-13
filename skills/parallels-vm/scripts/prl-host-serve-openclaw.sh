#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: prl-host-serve-openclaw.sh <repo-dir> [--port <port>] [--host <host>] [--out-dir <dir>] [--json]
EOF
  exit "${1:-64}"
}

[[ $# -ge 1 ]] || usage

case "${1:-}" in
  -h|--help)
    usage 0
    ;;
esac

repo_dir=$1
shift

detect_host_ip() {
  local explicit="${PRL_HOST_IP:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  /sbin/ifconfig 2>/dev/null | awk '
    /^[a-z0-9]+: / {
      iface=$1
      sub(/:$/, "", iface)
      next
    }
    $1 == "inet" && iface ~ /^vnic/ && $2 != "127.0.0.1" {
      print $2
      exit 0
    }
  '
}

port=8141
host=
out_dir=/private/tmp
json_mode=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      port=${2:?missing port}
      shift 2
      ;;
    --host)
      host=${2:?missing host}
      shift 2
      ;;
    --out-dir)
      out_dir=${2:?missing out dir}
      shift 2
      ;;
    --json)
      json_mode=1
      shift
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$host" ]]; then
  host="$(detect_host_ip || true)"
fi
[[ -n "$host" ]] || {
  echo "error: could not detect a Parallels host IP; pass --host <host-ip> or set PRL_HOST_IP" >&2
  exit 1
}

[[ -d "$repo_dir" ]] || { echo "error: repo dir not found: $repo_dir" >&2; exit 1; }
[[ -f "$repo_dir/package.json" ]] || { echo "error: package.json not found under: $repo_dir" >&2; exit 1; }

mkdir -p "$out_dir"

head_sha=$(git -C "$repo_dir" rev-parse HEAD)
head_short=$(git -C "$repo_dir" rev-parse --short HEAD)
timestamp=$(date +%s)
build_mode=prepack

existing_build_commit=
if [[ -f "$repo_dir/dist/build-info.json" ]]; then
  existing_build_commit=$(
    /opt/homebrew/bin/node -e '
const fs = require("node:fs");
const path = process.argv[1];
try {
  const parsed = JSON.parse(fs.readFileSync(path, "utf8"));
  process.stdout.write(parsed.commit || "");
} catch {}
' "$repo_dir/dist/build-info.json"
  )
fi

pack_args=(pack --json --pack-destination "$out_dir")
if [[ -n "$existing_build_commit" && "$existing_build_commit" == "$head_sha" ]]; then
  pack_args=(pack --json --ignore-scripts --pack-destination "$out_dir")
  build_mode=reuse-built-dist
fi

pack_json=$(cd "$repo_dir" && npm "${pack_args[@]}")
pack_name=$(
  printf '%s\n' "$pack_json" | /opt/homebrew/bin/node -e '
const fs = require("node:fs");
const parsed = JSON.parse(fs.readFileSync(0, "utf8"));
const entry = Array.isArray(parsed) ? parsed[0] : parsed;
process.stdout.write(entry?.filename || "");
'
)
[[ -n "$pack_name" ]] || { echo "error: npm pack did not return a tarball name" >&2; exit 1; }

src_tgz="$out_dir/$pack_name"
[[ -f "$src_tgz" ]] || { echo "error: packed tarball missing: $src_tgz" >&2; exit 1; }

serve_name="openclaw-main-${head_short}-${timestamp}.tgz"
serve_tgz="$out_dir/$serve_name"
mv -f "$src_tgz" "$serve_tgz"

build_info_json=$(tar -xOf "$serve_tgz" package/dist/build-info.json 2>/dev/null || true)
[[ -n "$build_info_json" ]] || { echo "error: package/dist/build-info.json missing in $serve_tgz" >&2; exit 1; }

embedded_commit=$(
  printf '%s\n' "$build_info_json" | /opt/homebrew/bin/node -e '
const fs = require("node:fs");
const parsed = JSON.parse(fs.readFileSync(0, "utf8"));
process.stdout.write(parsed.commit || "");
'
)
[[ -n "$embedded_commit" ]] || { echo "error: embedded build-info commit missing in $serve_tgz" >&2; exit 1; }
[[ "$embedded_commit" == "$head_sha" ]] || {
  echo "error: embedded commit mismatch: expected $head_sha got $embedded_commit" >&2
  exit 1
}

pkill -f "http.server $port" >/dev/null 2>&1 || true
server_log="$out_dir/prl-host-serve-openclaw-${port}.log"
/usr/bin/python3 -c 'import subprocess, sys
workdir, log_path, port = sys.argv[1:4]
with open(log_path, "ab", buffering=0) as log:
    proc = subprocess.Popen(
        ["python3", "-m", "http.server", port, "--bind", "0.0.0.0"],
        cwd=workdir,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    print(proc.pid)
' "$out_dir" "$server_log" "$port" >/dev/null

url="http://${host}:${port}/${serve_name}"
server_ready=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsI --max-time 10 "http://127.0.0.1:${port}/${serve_name}" >/dev/null 2>&1; then
    server_ready=1
    break
  fi
  sleep 1
done
[[ "$server_ready" == "1" ]] || { echo "error: host web server did not become ready on port $port" >&2; exit 1; }

if [[ "$json_mode" == "1" ]]; then
  /opt/homebrew/bin/node -e '
const [repoDir, url, tarball, commit, buildMode, logPath] = process.argv.slice(1);
process.stdout.write(
  JSON.stringify(
    {
      repoDir,
      url,
      tarball,
      commit,
      buildMode,
      serverLog: logPath,
    },
    null,
    2,
  ) + "\n",
);
' "$repo_dir" "$url" "$serve_tgz" "$head_sha" "$build_mode" "$server_log"
  exit 0
fi

printf '%s\n' "$url"
