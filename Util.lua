-- Forever-safe helpers. Combat values can be "secret" on WoW Forever: they can be
-- passed around and displayed, but arithmetic/comparison raises a Lua error.
-- Always gate math behind issecretvalue().

local _, ns = ...

function ns.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) and true or false
end

function ns.SafeNumber(value, fallback)
    if ns.IsSecret(value) then return fallback end
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

-- Realm APIs can return an empty string on Forever. Never key saved data by an
-- unguarded realm name: fall back to a stable literal.
function ns.RealmKey()
    local realm = type(GetRealmName) == "function" and GetRealmName() or nil
    if not realm or realm == "" then realm = "Forever" end
    return realm
end

function ns.CharacterKey()
    local name = type(UnitName) == "function" and UnitName("player") or nil
    if not name or name == "" then name = "Unknown" end
    return name .. "-" .. ns.RealmKey()
end

function ns.Round(value, decimals)
    local number = ns.SafeNumber(value, 0)
    local factor = 10 ^ (decimals or 0)
    return math.floor(number * factor + 0.5) / factor
end

-- "1g 20s 05c" with the game's own coin icons when the API is available.
function ns.MoneyString(copper, emptyText)
    local number = ns.SafeNumber(copper, nil)
    if number == nil then return emptyText or "—" end
    number = math.floor(number + 0.5)
    if number < 0 then number = 0 end
    if type(C_CurrencyInfo) == "table" and type(C_CurrencyInfo.GetCoinTextureString) == "function" then
        local ok, text = pcall(C_CurrencyInfo.GetCoinTextureString, number)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    local gold = math.floor(number / 10000)
    local silver = math.floor(number / 100) % 100
    local cops = number % 100
    if gold > 0 then return ("%dg %02ds %02dc"):format(gold, silver, cops) end
    if silver > 0 then return ("%ds %02dc"):format(silver, cops) end
    return ("%dc"):format(cops)
end

function ns.TimeString()
    if type(date) == "function" then
        local ok, text = pcall(date, "%H:%M:%S")
        if ok and type(text) == "string" then return text end
    end
    return "?"
end

-- C_Timer can be missing very early during login; callers treat scheduling as
-- best effort and simply recompute on the next event if it is unavailable.
function ns.Schedule(delay, callback)
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(delay, callback)
        return true
    end
    return false
end

local function getItemInfoFunction()
    if type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function" then
        return C_Item.GetItemInfo
    end
    if type(GetItemInfo) == "function" then
        return GetItemInfo
    end
    return nil
end

local function getItemInfoInstantFunction()
    if type(C_Item) == "table" and type(C_Item.GetItemInfoInstant) == "function" then
        return C_Item.GetItemInfoInstant
    end
    if type(GetItemInfoInstant) == "function" then
        return GetItemInfoInstant
    end
    return nil
end

-- Returns a small table, or nil while the client has not loaded this item yet.
-- Item info is not guaranteed on Forever right after login: callers count nil as
-- "pending" and retry once the client has the data.
function ns.GetItemInfo(linkOrID)
    if linkOrID == nil then return nil end
    local getInfo = getItemInfoFunction()
    if not getInfo then return nil end
    local ok, name, link, quality, itemLevel, _, itemType, itemSubType, maxStack,
        _, _, sellPrice, classID, subclassID, bindType = pcall(getInfo, linkOrID)
    if not ok or type(name) ~= "string" then return nil end
    return {
        name = name,
        link = type(link) == "string" and link or nil,
        quality = ns.SafeNumber(quality, 1),
        itemLevel = ns.SafeNumber(itemLevel, 0),
        itemType = type(itemType) == "string" and itemType or "",
        itemSubType = type(itemSubType) == "string" and itemSubType or "",
        maxStack = ns.SafeNumber(maxStack, 1),
        sellPrice = ns.SafeNumber(sellPrice, nil),
        classID = ns.SafeNumber(classID, nil),
        subclassID = ns.SafeNumber(subclassID, nil),
        bindType = ns.SafeNumber(bindType, nil),
    }
end

-- 0 for a loaded item that vendors refuse, nil when the data is not loaded.
function ns.GetItemSellPrice(link, itemID)
    local info = ns.GetItemInfo(link or itemID)
    if not info then return nil end
    return info.sellPrice
end

function ns.GetItemClass(link, itemID)
    local info = ns.GetItemInfo(link or itemID)
    if info and info.classID then return info.classID, info.subclassID end
    local getInstant = getItemInfoInstantFunction()
    if not getInstant then return nil, nil end
    local ok, _, _, _, _, classID, subclassID = pcall(getInstant, link or itemID)
    if not ok then return nil, nil end
    return ns.SafeNumber(classID, nil), ns.SafeNumber(subclassID, nil)
end

-- Requests the item data so GetItemInfo can answer on a later tick.
function ns.RequestItemData(itemID)
    if type(C_Item) == "table" and type(C_Item.RequestLoadItemDataByID) == "function" then
        local id = ns.SafeNumber(itemID, nil)
        if id then pcall(C_Item.RequestLoadItemDataByID, math.floor(id)) end
    end
end

-- Container API: C_Container is the mainline surface, the legacy globals are the
-- fallback for older builds of the client.
function ns.ContainerNumSlots(bagID)
    if type(C_Container) == "table" and type(C_Container.GetContainerNumSlots) == "function" then
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bagID)
        if ok then return ns.SafeNumber(slots, 0) end
    end
    if type(GetContainerNumSlots) == "function" then
        local ok, slots = pcall(GetContainerNumSlots, bagID)
        if ok then return ns.SafeNumber(slots, 0) end
    end
    return 0
end

function ns.ContainerItemInfo(bagID, slot)
    if type(C_Container) == "table" and type(C_Container.GetContainerItemInfo) == "function" then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slot)
        if ok and type(info) == "table" then
            local itemID = ns.SafeNumber(info.itemID, nil)
            if itemID and itemID > 0 then
                return {
                    itemID = itemID,
                    hyperlink = type(info.hyperlink) == "string" and info.hyperlink or nil,
                    stackCount = ns.SafeNumber(info.stackCount, 1),
                    isLocked = info.isLocked and true or false,
                    isBound = info.isBound and true or false,
                    isAccountBound = info.isAccountBound and true or false,
                    quality = ns.SafeNumber(info.quality, 1),
                }
            end
        end
    end
    if type(GetContainerItemInfo) == "function" then
        local ok, _, count, locked, quality, _, _, link, _, _, itemID, bound =
            pcall(GetContainerItemInfo, bagID, slot)
        if ok then
            local id = ns.SafeNumber(itemID, nil)
            if id and id > 0 then
                return {
                    itemID = id,
                    hyperlink = type(link) == "string" and link or nil,
                    stackCount = ns.SafeNumber(count, 1),
                    isLocked = locked and true or false,
                    isBound = bound and true or false,
                    isAccountBound = false,
                    quality = ns.SafeNumber(quality, 1),
                }
            end
        end
    end
    return nil
end
