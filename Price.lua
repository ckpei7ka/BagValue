-- Auction price sources.
--
-- Every adapter is defensive: another addon may be absent, may expose a
-- different shape, or may throw on unexpected arguments. Never let a third
-- party addon take the BagValue window down with it — feature-detect, pcall,
-- and validate that the result is a positive number.
--
-- Verified API shapes (checked against the addons' own source):
--   TSM_API.ToItemString(link) -> "i:12345"
--   TSM_API.GetCustomPriceValue(priceSource, itemString) -> copper | nil
--   Auctionator.API.v1.GetAuctionPriceByItemLink(callerID, link) -> copper | nil
--   Auctionator.API.v1.GetAuctionPriceByItemID(callerID, itemID) -> copper | nil
-- Both callerID (string) and itemID (number) are type-checked by those addons.

local _, ns = ...

local CALLER_ID = "BagValue"

local function asPrice(value)
    local number = ns.SafeNumber(value, nil)
    if number and number > 0 then return math.floor(number + 0.5) end
    return nil
end

local function pcallPrice(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    return asPrice(value)
end

-- TSM ------------------------------------------------------------------------

local function tsmAvailable()
    return type(TSM_API) == "table" and type(TSM_API.GetCustomPriceValue) == "function"
end

local function itemStringFor(link, itemID)
    if type(link) == "string" and type(TSM_API) == "table" and type(TSM_API.ToItemString) == "function" then
        local ok, text = pcall(TSM_API.ToItemString, link)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    local id = ns.SafeNumber(itemID, nil)
    if id then return "i:" .. tostring(math.floor(id)) end
    return nil
end

-- TSM has no single "market value" call; DBMinBuyout and DBMarket are the
-- realm-wide prices TSM keeps for its own UI. Prefer the cheaper of the two.
local function tsmPrice(link, itemID)
    if not tsmAvailable() then return nil end
    local itemString = itemStringFor(link, itemID)
    if not itemString then return nil end
    local best
    local keys = { "DBMinBuyout", "DBMarket" }
    for i = 1, #keys do
        local price = pcallPrice(TSM_API.GetCustomPriceValue, keys[i], itemString)
        if price and (not best or price < best) then best = price end
    end
    return best
end

-- Auctionator ----------------------------------------------------------------

local function auctionatorApi()
    local root = type(Auctionator) == "table" and Auctionator or nil
    local api = root and root.API or nil
    local v1 = type(api) == "table" and api.v1 or nil
    if type(v1) ~= "table" then return nil end
    return v1
end

local function auctionatorAvailable()
    local api = auctionatorApi()
    if not api then return nil end
    return type(api.GetAuctionPriceByItemLink) == "function"
        or type(api.GetAuctionPriceByItemID) == "function"
end

local function auctionatorPrice(link, itemID)
    local api = auctionatorApi()
    if not api then return nil end
    if type(link) == "string" and type(api.GetAuctionPriceByItemLink) == "function" then
        local price = pcallPrice(api.GetAuctionPriceByItemLink, CALLER_ID, link)
        if price then return price end
    end
    local id = ns.SafeNumber(itemID, nil)
    if id and type(api.GetAuctionPriceByItemID) == "function" then
        return pcallPrice(api.GetAuctionPriceByItemID, CALLER_ID, math.floor(id))
    end
    return nil
end

-- Auctinator -----------------------------------------------------------------
-- Auctinator has no public source tree and its in-game API is not documented.
-- Try the shapes it could plausibly expose, in decreasing order of confidence.

local function auctinatorRoot()
    return type(Auctinator) == "table" and Auctinator or nil
end

local function auctinatorApi()
    local root = auctinatorRoot()
    local api = root and root.API or nil
    local v1 = type(api) == "table" and api.v1 or nil
    return type(v1) == "table" and v1 or nil
end

local function auctinatorAvailable()
    local api = auctinatorApi()
    if api and (type(api.GetAuctionPriceByItemLink) == "function" or type(api.GetAuctionPriceByItemID) == "function") then
        return true
    end
    local root = auctinatorRoot()
    if root then
        local names = { "GetAuctionPrice", "GetPrice", "GetMarketValue" }
        for i = 1, #names do
            if type(root[names[i]]) == "function" then return true end
        end
    end
    if type(Auctinator_GetPrice) == "function" then return true end
    return type(AuctinatorDB) == "table"
end

local function auctinatorPrice(link, itemID)
    local api = auctinatorApi()
    if api then
        if type(link) == "string" and type(api.GetAuctionPriceByItemLink) == "function" then
            local price = pcallPrice(api.GetAuctionPriceByItemLink, CALLER_ID, link)
            if price then return price end
        end
        local id = ns.SafeNumber(itemID, nil)
        if id and type(api.GetAuctionPriceByItemID) == "function" then
            local price = pcallPrice(api.GetAuctionPriceByItemID, CALLER_ID, math.floor(id))
            if price then return price end
        end
    end
    local root = auctinatorRoot()
    if root then
        local names = { "GetAuctionPrice", "GetPrice", "GetMarketValue" }
        for i = 1, #names do
            local fn = root[names[i]]
            if type(fn) == "function" then
                local price = pcallPrice(fn, link or itemID)
                if not price then price = pcallPrice(fn, root, link or itemID) end
                if price then return price end
            end
        end
    end
    if type(Auctinator_GetPrice) == "function" then
        local price = pcallPrice(Auctinator_GetPrice, link or itemID)
        if price then return price end
    end
    local id = ns.SafeNumber(itemID, nil)
    if id and type(AuctinatorDB) == "table" then
        local entry = AuctinatorDB[id]
        if type(entry) == "table" then
            entry = entry.price or entry.buyout or entry.minBuyout
        end
        return asPrice(entry)
    end
    return nil
end

-- Auctioneer (Auc-Advanced) --------------------------------------------------

local function auctioneerApi()
    local root = type(AucAdvanced) == "table" and AucAdvanced or nil
    local api = root and root.API or nil
    return type(api) == "table" and api or nil
end

local function auctioneerAvailable()
    local api = auctioneerApi()
    if not api then return nil end
    local names = { "GetMarketValue", "GetItemPrice", "GetBuyout" }
    for i = 1, #names do
        if type(api[names[i]]) == "function" then return true end
    end
    return false
end

local function auctioneerPrice(link, itemID)
    local api = auctioneerApi()
    if not api then return nil end
    local names = { "GetMarketValue", "GetItemPrice", "GetBuyout" }
    for i = 1, #names do
        local fn = api[names[i]]
        if type(fn) == "function" then
            local price = pcallPrice(fn, link or itemID)
            if not price then price = pcallPrice(fn, api, link or itemID) end
            if price then return price end
        end
    end
    return nil
end

-- AHDB (mooreatv/AuctionDB) --------------------------------------------------

local function ahdbAvailable()
    return type(AuctionDB) == "table"
end

local function ahdbPrice(link, itemID)
    local adb = type(AuctionDB) == "table" and AuctionDB or nil
    if not adb then return nil end
    local id = ns.SafeNumber(itemID, nil)
    if not id then return nil end
    local names = { "GetPrice", "GetMarketValue", "GetAuctionPrice" }
    for i = 1, #names do
        local fn = adb[names[i]]
        if type(fn) == "function" then
            local price = pcallPrice(fn, adb, math.floor(id))
            if not price then price = pcallPrice(fn, math.floor(id)) end
            if price then return price end
        end
    end
    -- Fall back to the stored daily price. houses is account-wide and keyed by
    -- "region-forever-ruleset House", so scan a few houses rather than guess.
    local sv = adb.sv
    local houses = type(sv) == "table" and sv.houses or nil
    if type(houses) == "table" then
        local seen = 0
        for _, house in pairs(houses) do
            seen = seen + 1
            if seen > 8 then break end
            local daily = type(house) == "table" and house.daily or nil
            if type(daily) == "table" then
                local value = daily[id]
                if type(value) == "table" then value = value.price or value[1] end
                local price = asPrice(value)
                if price then return price end
            end
        end
    end
    return nil
end

-- Wowecon --------------------------------------------------------------------

local function woweconApi()
    local root = type(Wowecon) == "table" and Wowecon or nil
    local api = root and root.API or nil
    return type(api) == "table" and api or nil
end

local function woweconAvailable()
    local api = woweconApi()
    return api ~= nil and type(api.GetAuctionPrice_ByLink) == "function"
end

local function woweconPrice(link, itemID)
    local api = woweconApi()
    if not api or type(link) ~= "string" then return nil end
    local price = pcallPrice(api.GetAuctionPrice_ByLink, link, api.GLOBAL_PRICE)
    if price then return price end
    local id = ns.SafeNumber(itemID, nil)
    if id and type(api.GetAuctionPrice_ByID) == "function" then
        return pcallPrice(api.GetAuctionPrice_ByID, math.floor(id), api.GLOBAL_PRICE)
    end
    return nil
end

-- Generic Tekkub-style sell-value API ---------------------------------------

local function genericAvailable()
    return type(GetAuctionBuyout) == "function"
end

local function genericPrice(link, itemID)
    if type(GetAuctionBuyout) ~= "function" then return nil end
    local price = pcallPrice(GetAuctionBuyout, link or itemID)
    if price then return price end
    return pcallPrice(GetAuctionBuyout, itemID)
end

-- Custom global function ------------------------------------------------------

local function customFunction()
    local name = ns.db and ns.db.customFunction
    if type(name) ~= "string" or name == "" then return nil end
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    return fn
end

local function customAvailable()
    return customFunction() ~= nil
end

local function customPrice(link, itemID)
    local fn = customFunction()
    if not fn then return nil end
    local ok, value = pcall(fn, link, itemID)
    if ok then
        local price = asPrice(value)
        if price then return price end
    end
    ok, value = pcall(fn, itemID, link)
    return ok and asPrice(value) or nil
end

-- Registry -------------------------------------------------------------------

local DEFINITIONS = {
    { id = "tsm", label = "TSM", available = tsmAvailable, price = tsmPrice },
    { id = "auctionator", label = "Auctionator", available = auctionatorAvailable, price = auctionatorPrice },
    { id = "auctinator", label = "Auctinator (best effort)", available = auctinatorAvailable, price = auctinatorPrice },
    { id = "auctioneer", label = "Auctioneer", available = auctioneerAvailable, price = auctioneerPrice },
    { id = "ahdb", label = "AHDB (AuctionDB)", available = ahdbAvailable, price = ahdbPrice },
    { id = "wowecon", label = "Wowecon", available = woweconAvailable, price = woweconPrice },
    { id = "generic", label = "GetAuctionBuyout", available = genericAvailable, price = genericPrice },
    { id = "custom", label = "Custom function", available = customAvailable, price = customPrice },
}

local byId = {}
for i = 1, #DEFINITIONS do
    byId[DEFINITIONS[i].id] = DEFINITIONS[i]
end

ns.PriceSources = {
    { id = "auto", label = "Auto (best available)" },
    { id = "tsm", label = "TSM" },
    { id = "auctionator", label = "Auctionator" },
    { id = "auctinator", label = "Auctinator (best effort)" },
    { id = "auctioneer", label = "Auctioneer" },
    { id = "ahdb", label = "AHDB (AuctionDB)" },
    { id = "wowecon", label = "Wowecon" },
    { id = "generic", label = "GetAuctionBuyout" },
    { id = "custom", label = "Custom function" },
    { id = "vendor", label = "Vendor only" },
}

function ns.GetPriceSourceDefinition(id)
    return byId[id]
end

local function autoPrice(link, itemID, used)
    for i = 1, #DEFINITIONS do
        local entry = DEFINITIONS[i]
        if type(entry.available) == "function" and entry.available() then
            local price = entry.price(link, itemID)
            if price then
                if used then used[entry.id] = (used[entry.id] or 0) + 1 end
                return price, entry.id
            end
        end
    end
    return nil
end

-- Returns unit copper for one item, or nil when the selected source has no data.
function ns.LookupPrice(sourceId, link, itemID, used)
    if sourceId == "vendor" then return nil end
    if sourceId == nil or sourceId == "auto" then return autoPrice(link, itemID, used) end
    local entry = byId[sourceId]
    if not entry then return nil end
    if type(entry.available) == "function" and entry.available() then
        return entry.price(link, itemID)
    end
    return nil
end

function ns.HasPriceSource(sourceId)
    if sourceId == "vendor" then return false end
    if not sourceId or sourceId == "auto" then
        for i = 1, #DEFINITIONS do
            local entry = DEFINITIONS[i]
            if type(entry.available) == "function" and entry.available() then return true end
        end
        return false
    end
    local entry = byId[sourceId]
    return entry ~= nil and type(entry.available) == "function" and entry.available() and true or false
end

function ns.IsSourceAvailable(sourceId)
    return ns.HasPriceSource(sourceId)
end

-- Human readable name for the status line. For Auto, name the source that
-- actually answered the most items in this scan.
function ns.DescribeSource(sourceId, used)
    if sourceId == "vendor" then return "vendor only" end
    if sourceId ~= "auto" then
        local entry = byId[sourceId]
        local label = entry and entry.label or tostring(sourceId)
        if entry and not (type(entry.available) == "function" and entry.available()) then
            return label .. " (not detected)"
        end
        return label
    end
    local bestId, bestCount
    if type(used) == "table" then
        for id, count in pairs(used) do
            if not bestCount or count > bestCount then
                bestId, bestCount = id, count
            end
        end
    end
    if bestId and byId[bestId] then
        return "Auto: " .. byId[bestId].label
    end
    return "Auto (no data)"
end

function ns.DetectedSourceSummary()
    local found = {}
    for i = 1, #DEFINITIONS do
        local entry = DEFINITIONS[i]
        if type(entry.available) == "function" and entry.available() then
            found[#found + 1] = entry.label
        end
    end
    if #found == 0 then return "none detected" end
    return table.concat(found, ", ")
end
