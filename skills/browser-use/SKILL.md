---
name: browser-use
description: Existing Chrome browser automation via mcporter chrome-devtools MCP; attach to Peter's current Chrome tabs, inspect/click/type/screenshot. Do not use AppleScript fallback.
---

# Browser Use

Use this for browser tasks against Peter's existing Chrome session.

Hard rule: use `mcporter` `chrome-devtools` only. Do not fall back to AppleScript, `osascript`, GUI scripting, or macOS `open` for browser control.

## Check MCP

```bash
npx mcporter list chrome-devtools --schema
npx mcporter call chrome-devtools.list_pages --args '{}' --output text
```

If `list_pages` fails with `DevToolsActivePort`, restart the mcporter daemon and retry:

```bash
npx mcporter daemon restart
npx mcporter call chrome-devtools.list_pages --args '{}' --output text
```

If it still fails, stop and say Chrome DevTools MCP is unavailable. Do not use AppleScript.

## Typical Flow

```bash
# pick the page id from list_pages
npx mcporter call chrome-devtools.select_page pageId=9 --output text

# inspect page
npx mcporter call chrome-devtools.take_snapshot --args '{}' --output text

# navigate selected page
npx mcporter call chrome-devtools.navigate_page url=https://example.com --output text

# click an element uid from the latest snapshot
npx mcporter call chrome-devtools.click uid=1_38 includeSnapshot=true --output text

# type/fill
npx mcporter call chrome-devtools.fill uid=1_13 value='text' includeSnapshot=true --output text

# run JS, keep secrets out of output
npx mcporter call chrome-devtools.evaluate_script --args '{"function":"() => document.title"}' --output json
```

Use `take_snapshot` before actions and use current `uid` values only. Avoid `take_screenshot` unless visual layout matters.

## Secret Handling

Never print tokens/passwords from page DOM, network logs, or inputs. For token checks, return shape only: present/absent, length, status code, account/org name.
