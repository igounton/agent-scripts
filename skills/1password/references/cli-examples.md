# op CLI examples (from op help)

## Sign in

- `op signin`
- `op signin --account <shorthand|signin-address|account-id|user-id>`

## Read

- `op read op://app-prod/db/password`
- `op read "op://app-prod/db/one-time password?attribute=otp"`
- `op read "op://app-prod/ssh key/private key?ssh-format=openssh"`
- `op read --out-file ./key.pem op://app-prod/server/ssh/key.pem`

## Run

- `export DB_PASSWORD="op://app-prod/db/password"`
- `op run --no-masking -- printenv DB_PASSWORD`
- `op run --env-file="./.env" -- printenv DB_PASSWORD`

## Inject

- `echo "db_password: {{ op://app-prod/db/password }}" | op inject`
- `op inject -i config.yml.tpl -o config.yml`

## Whoami / accounts

- `op whoami`
- `op account list`

## Peter multi-account

- Always run these inside tmux.
- Default account for Peter secrets: `--account my.1password.com`.
- Do not use `my.1password.eu` / Titan unless requested.

## Item create/edit without printing secrets

`op item create` category values may be the human category name. For API tokens, use `"API Credential"`.

```bash
TOKEN="$(pbpaste)"
op item create --account my.1password.com --category "API Credential" --title "OpenClaw Foundation Slack Clawd" "bot_token[password]=$TOKEN" >/dev/null
op item get "OpenClaw Foundation Slack Clawd" --account my.1password.com --fields label=bot_token >/dev/null
```

```bash
TOKEN="$(pbpaste)"
op item edit "OpenClaw Foundation Slack Clawd" --account my.1password.com "app_token[password]=$TOKEN" >/dev/null
op item get "OpenClaw Foundation Slack Clawd" --account my.1password.com --fields label=app_token >/dev/null
```
