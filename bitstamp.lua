-- Inofficial Bitstamp Extension (www.bitstamp.net) for MoneyMoneyApp
-- Fetches balances from Bitstamp API and returns them as securities
--
-- Username: Bitstamp Customer ID (kept for UI compatibility, no longer used in auth)
-- Username2: Bitstamp API Key
-- Password: Bitstamp API Secret
--
-- Copyright (c) 2017 beanieboi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking {
    version = 1.2,
    url = "https://www.bitstamp.net",
    description = "Fetch balances from Bitstamp API and list them as securities",
    services = { "Bitstamp Account" },
}

local apiKey
local apiSecret
local apiVersion = "v2"
local currency = "EUR"
local market = "Bitstamp"
local accountName = "Balances"
local accountNumber = "Main"

local currencyNames = {
    BTC  = "Bitcoin",
    BCH  = "Bitcoin Cash",
    ETH  = "Ether",
    LTC  = "Litecoin",
    XRP  = "Ripple",
    EUR  = "Euro",
    USD  = "US Dollar",
    SOL  = "Solana",
    ADA  = "Cardano",
    DOT  = "Polkadot",
    LINK = "Chainlink",
    UNI  = "Uniswap",
    DOGE = "Dogecoin",
    AVAX = "Avalanche",
    MATIC = "Polygon",
    POL  = "Polygon",
    SHIB = "Shiba Inu",
    USDC = "USD Coin",
    USDT = "Tether",
    DAI  = "Dai",
    PEPE = "Pepe",
    BONK = "Bonk",
    SUI  = "Sui",
    INJ  = "Injective",
    NEAR = "NEAR Protocol",
    ATOM = "Cosmos",
    ARB  = "Arbitrum",
    OP   = "Optimism",
    TON  = "Toncoin",
    HYPE = "HyperLiquid",
    ENA  = "Ethena",
    JUP  = "Jupiter",
    WIF  = "Dogwifhat",
    TRX  = "Tron",
    APT  = "Aptos",
    BNB  = "BNB",
}

-- EUR-pegged stablecoins priced at 1 EUR
local eurStablecoins = {
    EURC = true, EURCV = true, VEUR = true,
}

-- USD stablecoins priced via EUR/USD rate
local usdStablecoins = {
    USDC = true, USDT = true, GUSD = true, PYUSD = true, DAI = true,
}

local eurUsdRate = nil

function SupportsBank(protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "Bitstamp Account"
end

function InitializeSession(protocol, bankCode, username, username2, password, username3)
    apiKey    = username2
    apiSecret = password
    -- username (Customer ID) kept for UI compatibility but unused in new header-based auth
end

function ListAccounts(knownAccounts)
    local account = {
        name          = accountName,
        accountNumber = accountNumber,
        currency      = currency,
        portfolio     = true,
        type          = "AccountTypePortfolio",
    }
    return { account }
end

function RefreshAccount(account, since)
    local balanceList = queryPrivate("account_balances")
    local securities = {}

    for _, entry in pairs(balanceList) do
        if type(entry) ~= "table" then goto continue end

        local curr  = entry.currency and entry.currency:upper() or nil
        local total = tonumber(entry.total)

        if not curr or not total or total <= 0 then goto continue end

        local price = getPrice(curr)

        if price and price > 0 then
            local name = currencyNames[curr] or curr
            securities[#securities + 1] = {
                name     = name,
                market   = market,
                currency = nil,
                quantity = total,
                price    = price,
            }
        end

        ::continue::
    end

    return { securities = securities }
end

function EndSession()
end

function getPrice(curr)
    if curr == "EUR" then
        return 1.0
    end

    if eurStablecoins[curr] then
        return 1.0
    end

    if usdStablecoins[curr] then
        if not eurUsdRate then
            local ok, ticker = pcall(queryPublic, "ticker/eurusd")
            if ok and ticker and tonumber(ticker.vwap) and tonumber(ticker.vwap) ~= 0 then
                eurUsdRate = 1.0 / tonumber(ticker.vwap)
            end
        end
        return eurUsdRate
    end

    -- Try {curr}EUR ticker dynamically for any other currency
    local ok, ticker = pcall(queryPublic, "ticker/" .. curr:lower() .. "eur")
    if ok and ticker and tonumber(ticker.vwap) and tonumber(ticker.vwap) > 0 then
        return tonumber(ticker.vwap)
    end

    return nil
end

-- New header-based authentication (Bitstamp API v2, replaces deprecated POST-body auth)
function queryPrivate(method)
    local path        = string.format("/api/%s/%s/", apiVersion, method)
    local nonce       = generateUUID()
    local timestamp   = string.format("%d", math.floor(MM.time() * 1000))
    local authVersion = "v2"
    local host        = "www.bitstamp.net"

    -- Per Bitstamp docs: Content-Type omitted when body is empty
    -- "BITSTAMP " + api_key + verb + host + path + query + nonce + timestamp + version + body
    local message = "BITSTAMP " .. apiKey
        .. "POST"
        .. host
        .. path
        .. ""           -- empty query string
        .. nonce
        .. timestamp
        .. authVersion
        .. ""           -- empty body

    local signature = string.upper(bin2hex(MM.hmac256(apiSecret, message)))

    local headers = {
        ["X-Auth"]           = "BITSTAMP " .. apiKey,
        ["X-Auth-Signature"] = signature,
        ["X-Auth-Nonce"]     = nonce,
        ["X-Auth-Timestamp"] = timestamp,
        ["X-Auth-Version"]   = authVersion,
    }

    local connection = Connection()
    local content = connection:request("POST", url .. path, nil, nil, headers)
    return JSON(content):dictionary()
end

function queryPublic(method)
    local path = string.format("/api/%s/%s/", apiVersion, method)
    local connection = Connection()
    local content = connection:request("GET", url .. path)
    return JSON(content):dictionary()
end

function generateUUID()
    local r = bin2hex(MM.random(16))
    return string.format("%s-%s-%s-%s-%s",
        r:sub(1, 8),
        r:sub(9, 12),
        r:sub(13, 16),
        r:sub(17, 20),
        r:sub(21, 32))
end

function bin2hex(s)
    return (s:gsub(".", function(byte)
        return string.format("%02x", string.byte(byte))
    end))
end
