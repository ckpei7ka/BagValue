-- Bag scan and totals.
--
-- One pass over every bag slot produces all three numbers:
--   money   - copper the character carries right now
--   vendor  - what a vendor pays for every item in the bags
--   auction - what the selected price source says the auctionable items are
--             worth (soulbound items cannot be auctioned and are skipped)
--
-- Stacks are multiplied by their count, and an item whose data the client has
-- not loaded yet is counted as pending: the client is asked for the data and
-- the scan is retried a few times.

local _, ns = ...

local MAX_BAG_INDEX = 6
local MAX_ITEM_LOAD_ATTEMPTS = 8

-- backpack + the four bag slots + the reagent bag (when the client has one)
function ns.BagIDs()
    local ids = { 0 }
    local slots = ns.SafeNumber(NUM_BAG_SLOTS, 4) or 4
    if slots > MAX_BAG_INDEX then slots = MAX_BAG_INDEX end
    for index = 1, slots do
        ids[#ids + 1] = index
    end
    -- Only follow Enum.BagIndex: blindly scanning a high bag index could pick
    -- up bank bags on clients that do not have a reagent bag.
    if type(Enum) == "table" and type(Enum.BagIndex) == "table" then
        local reagentBag = ns.SafeNumber(Enum.BagIndex.ReagentBag, nil)
        if reagentBag and reagentBag > 0 then
            local already = false
            for i = 1, #ids do
                if ids[i] == reagentBag then already = true end
            end
            if not already then ids[#ids + 1] = reagentBag end
        end
    end
    return ids
end

local function readMoney()
    if type(GetMoney) ~= "function" then return nil end
    local ok, money = pcall(GetMoney)
    if not ok then return nil end
    return ns.SafeNumber(money, nil)
end

function ns.ScanBags()
    local sourceId = (ns.db and ns.db.priceSource) or "auto"
    local priceAvailable = ns.HasPriceSource(sourceId)

    local result = {
        money = readMoney() or 0,
        vendor = 0,
        auction = priceAvailable and 0 or nil,
        hasSource = priceAvailable,
        itemSlots = 0,
        stackCount = 0,
        pricedSlots = 0,
        unpricedSlots = 0,
        boundSlots = 0,
        pending = 0,
        used = {},
        sourceId = sourceId,
        stamp = ns.TimeString(),
    }

    local bags = ns.BagIDs()
    for b = 1, #bags do
        local bag = bags[b]
        local slotCount = ns.ContainerNumSlots(bag)
        if slotCount and slotCount > 0 then
            for slot = 1, slotCount do
                local info = ns.ContainerItemInfo(bag, slot)
                if info and not info.isLocked and info.itemID and info.itemID > 0 then
                    local count = ns.SafeNumber(info.stackCount, 1)
                    if not count or count < 1 then count = 1 end

                    result.itemSlots = result.itemSlots + 1
                    result.stackCount = result.stackCount + count

                    local sell = ns.GetItemSellPrice(info.hyperlink, info.itemID)
                    if sell ~= nil then
                        result.vendor = result.vendor + sell * count
                    else
                        result.pending = result.pending + 1
                        ns.RequestItemData(info.itemID)
                    end

                    local bound = info.isBound or info.isAccountBound
                    if bound then
                        result.boundSlots = result.boundSlots + 1
                    elseif priceAvailable then
                        local price = ns.LookupPrice(sourceId, info.hyperlink, info.itemID, result.used)
                        if price then
                            result.auction = (result.auction or 0) + price * count
                            result.pricedSlots = result.pricedSlots + 1
                        else
                            result.unpricedSlots = result.unpricedSlots + 1
                        end
                    end
                end
            end
        end
    end

    -- A detected source that has no price for anything at all (e.g. TSM is
    -- installed but the auction house was never scanned) must read as "no
    -- data", not as a real total of zero.
    if priceAvailable and result.pricedSlots == 0 and result.itemSlots > 0 then
        result.auction = nil
        result.noPriceData = true
    end

    return result
end

-- Recompute and push the result into the window. Safe to call from events and
-- from a scheduled retry; it never throws on missing API.
function ns.Refresh()
    if not ns.db or not ns.db.enabled then return nil end
    local ok, result = pcall(ns.ScanBags)
    if not ok or type(result) ~= "table" then
        if ns.Debug then ns.Debug("scan failed: " .. tostring(result)) end
        return nil
    end
    ns.lastScan = result
    if ns.UpdateWindow then ns.UpdateWindow(result) end

    if result.pending and result.pending > 0 then
        local attempts = (ns.itemLoadAttempts or 0) + 1
        ns.itemLoadAttempts = attempts
        if attempts <= MAX_ITEM_LOAD_ATTEMPTS then
            ns.Schedule(0.9, function()
                if ns.db and ns.db.enabled and ns.window and ns.window:IsShown() then
                    ns.Refresh()
                end
            end)
        end
    else
        ns.itemLoadAttempts = 0
    end

    return result
end
