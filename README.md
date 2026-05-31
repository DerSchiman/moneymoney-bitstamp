# Bitstamp-MoneyMoney

Fetches balances from Bitstamp API and returns them as securities

## Setup

* Download Bitstamp extension bitstamp.lua
* In MoneyMoney app open “Help” Menu and hit “Show database in finder” (https://moneymoney-app.com/extensions/#installation)
* Copy bitstamp.lua in extensions folder
* In MoneyMoney app open “Preferences” > “Extensions” and make sure “bitstamp” show up (to use unsigned extension uncheck “verify digital signatures of extensions” at the bottom)
* Login to bitstamp.net
* To get an API key, go to "Account" > "Security" > "API Access"
* Check permission “Account Balance” (other fields can stay blank) and hit “Generate key”
* On the next screen hit “Active key” and confirm link in bitstamp email
* Finally in MoneyMoney add new bitstamp account and use your bitstamp customer id, API key and API secret

### MoneyMoney

Add a new account (type Bitstamp Account”)

## Known Issues and Limitations

* Always assumes EUR as base currency
* **Bitstamp Earn balances are not shown.** The `/api/v2/earn/subscriptions/` and `/api/v2/earn/transactions/` endpoints return HTTP 401 "Authentication Failed" for all API keys regardless of which permissions are granted in the Bitstamp UI. MoneyMoney also intercepts HTTP 401 responses at the application level before Lua error handling can suppress them, so these calls cannot be silenced with `pcall`. If Bitstamp ever exposes Earn via the public REST API, the extension can be extended — see the TODO comment in `RefreshAccount`.

## API Notes (as of 2026-05)

The extension was migrated from the deprecated v1/v2 POST-body HMAC auth to the current header-based auth scheme:

| | Old (deprecated) | New (current) |
|---|---|---|
| Balance endpoint | `POST /api/v2/balance/` | `POST /api/v2/account_balances/` |
| Response format | Flat dict `{btc_balance: "0.001", ...}` | Array `[{currency, total, available, reserved}]` |
| Auth | POST body: `nonce`, `key`, `signature` | Headers: `X-Auth`, `X-Auth-Signature`, `X-Auth-Nonce`, `X-Auth-Timestamp`, `X-Auth-Version` |
| Signature input | `UPPERCASE_HEX(HMAC256(secret, nonce+customerId+apiKey))` | `UPPERCASE_HEX(HMAC256(secret, "BITSTAMP "+key+verb+host+path+query+nonce+timestamp+"v2"+body))` |

The old endpoint silently returns all-zero balances rather than an explicit error — this is the root cause of the "everything shows 0€" bug.
