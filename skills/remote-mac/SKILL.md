---
name: remote-mac
description: MacBook/Mac Studio remote access via SSH, Tailscale discovery, LAN fallback, and non-interactive shell hygiene.
---

# Remote Mac

Use when the user says `MacBook`, `Mac Studio`, or asks to run/check something on one of Peter's Macs.

## Discovery

1. Start with `tailscale status` and pick the matching host.
2. If Tailscale is down or SSH times out, try LAN discovery:

```bash
dns-sd -B _ssh._tcp local
arp -a
```

3. Try mDNS names such as `HOST.local` when visible.

## SSH Rules

Use non-interactive SSH by default:

```bash
ssh -o RequestTTY=no -o RemoteCommand=none HOST 'COMMAND'
```

For long-running or interactive remote work, use tmux on the remote host and keep the session name obvious.

## Safety

- Do not assume host identity from a stale IP; verify hostname/user when possible.
- Do not print secrets from remote files or shells.
- If a host is unavailable after Tailscale + LAN fallback, say what was tried.
- For OpenClaw Gateway on Peter's machine, do not start/install launchd. Ask before touching the pm2 watcher.
