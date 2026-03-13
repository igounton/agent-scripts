#!/usr/bin/env bash
set -euo pipefail

prl_windows_die() {
  echo "error: $*" >&2
  exit 1
}

prl_windows_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || prl_windows_die "$1 not found"
}

prl_windows_require_prlctl() {
  prl_windows_require_cmd prlctl
}

prl_windows_json_array() {
  if [[ $# -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  printf '%s\0' "$@" | /opt/homebrew/bin/node -e '
const fs = require("fs");
const raw = fs.readFileSync(0, "utf8");
if (!raw) {
  process.stdout.write("[]");
  process.exit(0);
}
const items = raw.split("\0");
if (items.length && items[items.length - 1] === "") {
  items.pop();
}
process.stdout.write(JSON.stringify(items));
'
}

prl_windows_encode_ps() {
  /opt/homebrew/bin/node -e '
const fs = require("fs");
const script = fs.readFileSync(0, "utf8");
process.stdout.write(Buffer.from(script, "utf16le").toString("base64"));
'
}

prl_windows_strip_clixml() {
  /opt/homebrew/bin/node -e '
const fs = require("fs");
let text = fs.readFileSync(0, "utf8");
text = text.replace(/^#< CLIXML\r?\n?/gm, "");
text = text.replace(/<Objs\b[\s\S]*?<\/Objs>/g, "");
text = text.replace(/\r/g, "");
process.stdout.write(text);
'
}

prl_windows_extract_json() {
  /opt/homebrew/bin/node -e '
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");

function extractJson(text) {
  for (let start = 0; start < text.length; start += 1) {
    if (text[start] !== "{") continue;
    let depth = 0;
    let inString = false;
    let escape = false;
    for (let i = start; i < text.length; i += 1) {
      const ch = text[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (ch === "\\\\") {
          escape = true;
        } else if (ch === "\"") {
          inString = false;
        }
        continue;
      }
      if (ch === "\"") {
        inString = true;
        continue;
      }
      if (ch === "{") {
        depth += 1;
        continue;
      }
      if (ch === "}") {
        depth -= 1;
        if (depth === 0) {
          const candidate = text.slice(start, i + 1);
          try {
            JSON.parse(candidate);
            process.stdout.write(candidate);
            return true;
          } catch {}
        }
      }
    }
  }
  return false;
}

if (!extractJson(input)) {
  process.exit(1);
}
'
}

prl_windows_exec_ps_script() {
  local vm=$1
  local script=$2
  local encoded
  encoded=$(printf '%s' "$script" | prl_windows_encode_ps)
  prlctl exec "$vm" --current-user powershell -NoProfile -EncodedCommand "$encoded"
}

prl_windows_build_module_runner() {
  local prefix=$1
  local env_json=$2
  local args_json=$3

  /opt/homebrew/bin/node - "$prefix" "$env_json" "$args_json" <<'EOF'
const util = require('node:util');
const [prefixInput, envInput, argsInput] = process.argv.slice(2);
const normalize = (value) => String(value).replace(/\\/g, "/").replace(/\/+$/, "");
const js = (value) =>
  util.inspect(value, { depth: null, maxArrayLength: null, breakLength: Infinity, compact: true, quoteStyle: 'single' });
const prefix = normalize(prefixInput);
const envPairs = JSON.parse(envInput);
const args = JSON.parse(argsInput);

const userMatch = prefix.match(/^([A-Za-z]:\/Users\/[^/]+)/);
const userHome = userMatch ? userMatch[1] : null;
const inferredAppData = userHome ? `${userHome}/AppData/Roaming` : null;
const inferredUserName = userHome ? userHome.split("/").at(-1) : null;

const modulePath = `${prefix}/node_modules/openclaw/openclaw.mjs`;
const moduleUrl = `file:///${modulePath}`;

process.stdout.write(`
const envPairs = ${js(envPairs)};
const inferredUserHome = ${js(userHome)};
const inferredAppData = ${js(inferredAppData)};
const inferredUserName = ${js(inferredUserName)};
const modulePath = ${js(modulePath)};
const moduleUrl = ${js(moduleUrl)};
for (const pair of envPairs) {
  if (!pair || !pair.includes('=')) continue;
  const index = pair.indexOf('=');
  const key = pair.slice(0, index);
  const value = pair.slice(index + 1);
  process.env[key] = value;
}
if (!process.env.USERPROFILE && inferredUserHome) {
  process.env.USERPROFILE = inferredUserHome;
}
if (!process.env.HOME && inferredUserHome) {
  process.env.HOME = inferredUserHome;
}
if (!process.env.USERNAME && inferredUserName) {
  process.env.USERNAME = inferredUserName;
}
if (!process.env.APPDATA && inferredAppData) {
  process.env.APPDATA = inferredAppData;
}
process.argv = ['node', modulePath, ...${js(args)}];
await import(moduleUrl);
`);
EOF
}

prl_windows_build_openclaw_script() {
  local env_json=$1
  local args_json=$2

  /opt/homebrew/bin/node - "$env_json" "$args_json" <<'EOF'
const envArgs = JSON.parse(process.argv[2]);
const args = JSON.parse(process.argv[3]);
const ps = (value) => "'" + String(value).replace(/'/g, "''") + "'";

const envList = envArgs.map(ps).join(", ");
const argList = args.map(ps).join(", ");

process.stdout.write(`$envPairs = @(${envList})
foreach ($pair in $envPairs) {
  if ([string]::IsNullOrWhiteSpace($pair)) { continue }
  $parts = $pair -split '=', 2
  if ($parts.Length -eq 2) {
    Set-Item -Path ("Env:" + $parts[0]) -Value $parts[1]
  }
}
$command = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
if (-not $command) {
  $command = Get-Command openclaw -ErrorAction SilentlyContinue
}
$knownPaths = @(
  (Join-Path $env:APPDATA "npm\\openclaw.cmd"),
  (Join-Path $env:APPDATA "npm\\openclaw"),
  (Join-Path $env:LOCALAPPDATA "pnpm\\openclaw.cmd"),
  (Join-Path $env:LOCALAPPDATA "pnpm\\openclaw"),
  (Join-Path $env:USERPROFILE "AppData\\Roaming\\npm\\openclaw.cmd"),
  (Join-Path $env:USERPROFILE "AppData\\Roaming\\npm\\openclaw")
) | Where-Object { $_ -and (Test-Path $_) }
if ((-not $command -or -not $command.Source) -and $knownPaths.Count -gt 0) {
  $command = [pscustomobject]@{ Source = $knownPaths[0] }
}
if (-not $command -or -not $command.Source) {
  throw "guest openclaw command not found"
}
$argsList = @(${argList})
& $command.Source @argsList
exit $LASTEXITCODE
`);
EOF
}

prl_windows_run_openclaw_env() {
  local vm=$1
  shift

  local env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done

  [[ $# -gt 0 ]] || prl_windows_die "missing openclaw args"

  local env_json args_json script
  env_json=$(prl_windows_json_array "${env_args[@]}")
  args_json=$(prl_windows_json_array "$@")
  script=$(prl_windows_build_openclaw_script "$env_json" "$args_json")
  prl_windows_exec_ps_script "$vm" "$script" 2>&1 | prl_windows_strip_clixml
}

prl_windows_run_openclaw_prefix_env() {
  local vm=$1
  local prefix=$2
  shift 2

  local env_args=()
  while [[ $# -gt 0 && "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done

  [[ $# -gt 0 ]] || prl_windows_die "missing openclaw args"

  local env_json args_json script
  env_json=$(prl_windows_json_array "${env_args[@]}")
  args_json=$(prl_windows_json_array "$@")
  script=$(prl_windows_build_module_runner "$prefix" "$env_json" "$args_json")
  prl_windows_wait_for_user_session "$vm"
  prlctl exec "$vm" --current-user "C:\\Program Files\\nodejs\\node.exe" --input-type=module -e "$script" 2>&1
}

prl_windows_build_install_script() {
  local install_url=$1
  local tag=$2
  local method=$3
  local git_dir=$4
  local no_onboard=$5

  /opt/homebrew/bin/node - "$install_url" "$tag" "$method" "$git_dir" "$no_onboard" <<'EOF'
const [installUrl, tag, method, gitDir, noOnboard] = process.argv.slice(2);
const ps = (value) => "'" + String(value).replace(/'/g, "''") + "'";

const lines = ["$params = @{}"];
if (tag) lines.push(`$params.Tag = ${ps(tag)}`);
if (method) lines.push(`$params.InstallMethod = ${ps(method)}`);
if (gitDir) lines.push(`$params.GitDir = ${ps(gitDir)}`);
if (noOnboard === "1") lines.push("$params.NoOnboard = $true");
lines.push(`& ([scriptblock]::Create((Invoke-RestMethod ${ps(installUrl)}))) @params`);
lines.push("exit $LASTEXITCODE");
process.stdout.write(lines.join("\n"));
EOF
}

prl_windows_build_npm_install_script() {
  local spec=$1
  local prefix=${2:-}

  /opt/homebrew/bin/node - "$spec" "$prefix" <<'EOF'
const [spec, prefix] = process.argv.slice(2);
const ps = (value) => "'" + String(value).replace(/'/g, "''") + "'";

process.stdout.write(`$portableRoot = Join-Path $env:LOCALAPPDATA "OpenClaw\\deps\\portable-git"
$portableEntries = @(
  (Join-Path $portableRoot "mingw64\\bin"),
  (Join-Path $portableRoot "usr\\bin"),
  (Join-Path $portableRoot "cmd"),
  (Join-Path $portableRoot "bin")
) | Where-Object { Test-Path $_ }
if ($portableEntries.Count -gt 0) {
  $env:Path = (($portableEntries + @($env:Path)) -join ";")
}
$env:NPM_CONFIG_LOGLEVEL = "error"
$env:NPM_CONFIG_UPDATE_NOTIFIER = "false"
$env:NPM_CONFIG_FUND = "false"
$env:NPM_CONFIG_AUDIT = "false"
$env:NPM_CONFIG_SCRIPT_SHELL = "cmd.exe"
$env:NODE_LLAMA_CPP_SKIP_DOWNLOAD = "1"
if (${JSON.stringify(Boolean(prefix))}) {
  $env:NPM_CONFIG_PREFIX = ${ps(prefix || "")}
}
& npm.cmd install -g ${ps(spec)} --force --no-fund --no-audit --loglevel=error
exit $LASTEXITCODE
`);
EOF
}

prl_windows_parse_openclaw_version() {
  local raw=$1
  local version
  version=$(printf '%s\n' "$raw" | /usr/bin/perl -ne 'if (/(20[0-9]{2}\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.]+)?)/) { print "$1\n"; exit 0 }')
  [[ -n "$version" ]] || prl_windows_die "could not parse OpenClaw version from: $raw"
  printf '%s\n' "$version"
}

prl_windows_try_parse_openclaw_version() {
  local raw=$1
  printf '%s\n' "$raw" | /usr/bin/perl -ne 'if (/(20[0-9]{2}\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.]+)?)/) { print "$1\n"; exit 0 }'
}

prl_windows_wait_for_user_session() {
  local vm=$1
  local timeout_s=${2:-120}
  local deadline=$((SECONDS + timeout_s))

  while (( SECONDS < deadline )); do
    if prlctl exec "$vm" --current-user whoami >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  prl_windows_die "guest user session not ready within ${timeout_s}s"
}
