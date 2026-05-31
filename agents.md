# Agent Context — bitstamp-moneymoney

This file gives future AI agents full context to continue work on this repo without re-deriving history.

## What this project is

A MoneyMoney (macOS banking app) Lua extension that fetches Bitstamp crypto account balances and displays them as securities in a portfolio account.

- **Live extension path:** `/Users/derschiman/Library/Containers/com.moneymoney-app.retail/Data/Library/Application Support/MoneyMoney/Extensions/bitstamp.lua`
- **Upstream repo:** `https://github.com/beanieboi/moneymoney-bitstamp`
- **Fork:** `https://github.com/DerSchiman/moneymoney-bitstamp`
- **Working branch:** `fix/new-api-auth-and-account-balances-endpoint`

## Current state (2026-05-31)

The trading wallet auth and balance fetch is **working**. The extension was migrated to Bitstamp's new header-based API auth and the new `account_balances` endpoint. However, the user's funds are in **Bitstamp Earn** (staking), not the trading wallet — so MoneyMoney currently shows ~€0 even though the real balance is ~€3,568.

No PR has been opened to upstream because the Earn limitation makes the fix incomplete.

## What works

- `POST /api/v2/account_balances/` with new header auth → returns array of `{currency, total, available, reserved}`
- Dynamic EUR price fetching per currency via `GET /api/v2/ticker/{currency}eur/`
- EUR/USD stablecoin handling (no extra ticker call needed)
- UUID nonce generation via `MM.random(16)`

## What is blocked — Earn balance

`GET /api/v2/earn/subscriptions/` and `GET /api/v2/earn/transactions/` both return HTTP 401 "Authentication Failed" for all API key permission combinations. This was tested exhaustively:

- GET with new header auth → 401
- POST with new header auth → 401
- With all API key permissions enabled → 401
- After re-activating API key → 401

**MoneyMoney behavior:** HTTP 401 responses are intercepted at the C application layer and shown as a fatal error dialog. Lua's `pcall` does NOT catch these — the session aborts. Earn endpoint calls must therefore be omitted entirely until a working auth path is found.

**Hypothesis for next session:** Inspect browser network traffic on `bitstamp.net/bitstamp-earn/` while logged in to find which internal API endpoint the Bitstamp web UI uses to show the Earn balance. It likely differs from the public REST API. Could also contact Bitstamp support to ask for API access to Earn data.

## Auth implementation details

### Signature construction (POST, empty body)
```
message = "BITSTAMP " + api_key
        + "POST"
        + "www.bitstamp.net"
        + path                    -- e.g. "/api/v2/account_balances/"
        + ""                      -- query string (empty)
        + nonce                   -- UUID from MM.random(16)
        + timestamp               -- UTC ms as string
        + "v2"                    -- auth version
        + ""                      -- body (empty)
-- Note: Content-Type omitted from message when body is empty (per Bitstamp docs)

signature = UPPERCASE_HEX(HMAC-SHA256(api_secret, message))
```

### Required headers
```
X-Auth:           BITSTAMP {api_key}
X-Auth-Signature: {signature}
X-Auth-Nonce:     {uuid}
X-Auth-Timestamp: {utc_ms}
X-Auth-Version:   v2
```

### MoneyMoney-specific quirks
- `connection:request("POST", url, body, contentType, headers)` — body and contentType must be strings, not nil (pass `""` for empty POST)
- `connection:request("GET", url, nil, nil, headers)` — nil is fine for GET body/contentType
- HTTP 401 responses abort the session at app level; pcall cannot suppress them
- `MM.random(n)` returns n random bytes as a binary string
- `MM.hmac256(key, message)` returns raw bytes; wrap with `bin2hex()` and uppercase for hex signature
- `MM.time()` returns seconds as float; multiply by 1000 and floor for ms timestamp

## Files
- `bitstamp.lua` — the extension (single file, no dependencies)
- `README.md` — setup instructions + API notes
- `agents.md` — this file
