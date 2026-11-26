-- BagValue for World of Warcraft: Forever (Interface 16001, client 1.60.1).
--
-- Lifecycle: saved variables are initialised on ADDON_LOADED, the window is
-- created lazily, and bag/money/merchant events schedule a throttled rescan.
-- Everything user-facing lives in Window.lua/Config.lua; pricing in Price.lua;
-- the totals in Scan.lua.

local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.version = "0.4.0"
ns.prefix = "BAGVALUE"

local DB_VERSION = 2

local DEFAULTS = {
    enabled = true,
    debug = false,
    priceSource = "auto",
    customFunction = "",
    showOnLogin = true,
    collapsed = false,
    skin = "classic",
    opacity = 0.94,
    fontSize = 0,
    dbVersion = DB_VERSION,
    window = nil,
}

local function copyDefaults(source, target)
    target = target or {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = copyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function ns.ResetDatabase()
    _G["BAGVALUE_DB"] = copyDefaults(DEFAULTS, {})
    ns.db = _G["BAGVALUE_DB"]
end

local function initialiseDatabase()
    local saved = _G["BAGVALUE_DB"]
    local previousVersion = nil
    if type(saved) == "table" then
        previousVersion = ns.SafeNumber(saved.dbVersion, nil)
    end
    _G["BAGVALUE_DB"] = copyDefaults(DEFAULTS, type(saved) == "table" and saved or {})
    ns.db = _G["BAGVALUE_DB"]

    -- v0.1.x opened the window only from the settings panel and closed it with
    -- that panel. The window is a persistent frame now, so existing installs
    -- get the login display turned on once.
    if previousVersion == nil or previousVersion < DB_VERSION then
        ns.db.showOnLogin = true
        ns.db.collapsed = false
        ns.db.dbVersion = DB_VERSION
    end
end

function ns.Print(message)
    print(("|cff33ff99%s|r: %s"):format(ADDON_NAME, tostring(message)))
end

function ns.Debug(message)
    if ns.db and ns.db.debug then
        ns.Print(message)
    end
end

-- Refresh scheduling ---------------------------------------------------------

local refreshQueued = false

-- Coalesces a burst of bag events into one scan. Hidden windows are skipped
-- unless the caller forces the refresh (login, slash command, ShowWindow).
function ns.RequestRefresh(delay, force)
    if not ns.db or not ns.db.enabled then return end
    if not force and not ns.IsWindowShown() then return end
    if refreshQueued then return end
    refreshQueued = true
    local wait = ns.SafeNumber(delay, 0.2) or 0.2
    ns.Schedule(wait, function()
        refreshQueued = false
        if ns.db and ns.db.enabled then
            ns.Refresh()
        end
    end)
end

-- Price source ---------------------------------------------------------------

function ns.ValidPriceSourceIds()
    local ids = {}
    for _, source in ipairs(ns.PriceSources or {}) do
        ids[source.id] = true
    end
    return ids
end

function ns.SetPriceSource(sourceId)
    if not sourceId or not ns.ValidPriceSourceIds()[sourceId] then
        ns.Print(("unknown source: %s"):format(tostring(sourceId)))
        return false
    end
    ns.db.priceSource = sourceId
    ns.Print(("price source: %s"):format(ns.DescribeSource(sourceId)))
    if ns.onSourceChanged then ns.onSourceChanged(sourceId) end
    ns.RequestRefresh(0, true)
    if ns.UpdateWindow and ns.lastScan then ns.UpdateWindow(ns.lastScan) end
    return true
end

function ns.OpenOptions()
    if type(Settings) == "table" and type(Settings.OpenToCategory) == "function" and ns.settingsCategory then
        local ok = pcall(Settings.OpenToCategory, ns.settingsCategory:GetID())
        if ok then return true end
    end
    ns.Print("open /bagvalue and use /bagvalue source, style or opacity")
    return false
end

-- Events ---------------------------------------------------------------------

local frame = CreateFrame("Frame")
ns.frame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            initialiseDatabase()
        end
    elseif event == "PLAYER_LOGIN" then
        if not ns.db or not ns.db.enabled then return end
        ns.Print(("v%s loaded · sources: %s"):format(ns.version, ns.DetectedSourceSummary()))
        ns.EnsureWindow()
        if ns.db.showOnLogin then
            ns.ShowWindow()
        else
            ns.Print("type /bagvalue to open the window")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.RequestRefresh(1)
    elseif event == "PLAYER_MONEY" then
        ns.RequestRefresh(0.1)
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
        ns.RequestRefresh(0.2)
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.itemLoadAttempts = 0
        ns.RequestRefresh(0.25)
    elseif event == "BAG_UPDATE" then
        ns.RequestRefresh(0.8)
    end
end)

-- Slash command --------------------------------------------------------------

local function printHelp()
    ns.Print(("v%s"):format(ns.version))
    ns.Print("/bagvalue — show or hide the window")
    ns.Print("/bagvalue collapse — collapse or expand the window")
    ns.Print("/bagvalue reset-window — reset the window size and position")
    ns.Print("/bagvalue refresh — rescan bags now")
    ns.Print("/bagvalue source — list price sources")
    ns.Print("/bagvalue source <id> — pick a price source")
    ns.Print("/bagvalue style — list window styles")
    ns.Print("/bagvalue style <id> — pick a window style")
    ns.Print("/bagvalue opacity <20-100> — set the window background opacity")
    ns.Print("/bagvalue fontsize <0|8-20> — text size (0 = keep the style size)")
    ns.Print("/bagvalue options — open settings")
    ns.Print("/bagvalue debug — toggle debug output")
    ns.Print("/bagvalue reset — reset settings")
end

local function printSources()
    local current = ns.db and ns.db.priceSource or "auto"
    local parts = {}
    for _, source in ipairs(ns.PriceSources or {}) do
        local marker = source.id == current and "*" or " "
        local available = source.id == "auto" or source.id == "vendor" or ns.IsSourceAvailable(source.id)
        parts[#parts + 1] = ("%s %s%s"):format(marker, source.id, available and "" or " (missing)")
    end
    ns.Print(table.concat(parts, ", "))
end

SLASH_BAGVALUE1 = "/bagvalue"
SlashCmdList["BAGVALUE"] = function(message)
    if not ns.db then return end
    local text = strtrim(message or "")
    local command, rest = text:match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()

    if command == "" then
        ns.ToggleWindow()
    elseif command == "collapse" or command == "свернуть" then
        ns.ToggleCollapsed()
        ns.Print(ns.IsCollapsed() and "collapsed" or "expanded")
    elseif command == "reset-window" or command == "layout" or command == "окно" then
        ns.ResetLayout()
        ns.Print("window size and position reset")
    elseif command == "refresh" or command == "обновить" then
        ns.RequestRefresh(0, true)
        ns.Print("refreshing")
    elseif command == "source" then
        if rest == "" then
            printSources()
        else
            ns.SetPriceSource(strtrim(rest):lower())
        end
    elseif command == "style" or command == "skin" or command == "стиль" then
        local skins = ns.skinList or {}
        if rest == "" then
            local current = ns.db.skin or "classic"
            local parts = {}
            for _, skin in ipairs(skins) do
                parts[#parts + 1] = (skin.id == current and "*" or " ") .. skin.id
            end
            ns.Print(table.concat(parts, ", "))
        else
            local wanted = strtrim(rest):lower()
            local found = false
            for _, skin in ipairs(skins) do
                if skin.id == wanted then found = true end
            end
            if found and ns.SetSkin then
                ns.SetSkin(wanted)
                ns.Print(("window style: %s"):format(wanted))
            else
                ns.Print("unknown style, try /bagvalue style")
            end
        end
    elseif command == "opacity" or command == "прозрачность" then
        if rest == "" then
            local opacity = ns.GetOpacity and ns.GetOpacity() or 0.94
            ns.Print(("window opacity: %d%%"):format(math.floor(opacity * 100 + 0.5)))
        else
            local percent = ns.SafeNumber(strtrim(rest), nil)
            if percent then
                ns.SetOpacity(percent / 100)
                ns.Print(("window opacity: %d%%"):format(math.floor(percent + 0.5)))
            else
                ns.Print("usage: /bagvalue opacity <20-100>")
            end
        end
    elseif command == "fontsize" or command == "font" or command == "шрифт" then
        if rest == "" then
            local size = ns.GetFontSize and ns.GetFontSize() or 0
            if size > 0 then
                ns.Print(("text size: %d"):format(size))
            else
                local effective = ns.GetEffectiveFontSize and ns.GetEffectiveFontSize() or 12
                ns.Print(("text size: style default (%d)"):format(effective))
            end
        else
            local wanted = ns.SafeNumber(strtrim(rest), nil)
            if wanted and ns.SetFontSize then
                local applied = ns.SetFontSize(wanted)
                if applied > 0 then
                    ns.Print(("text size: %d"):format(applied))
                else
                    ns.Print("text size: style default")
                end
            else
                ns.Print("usage: /bagvalue fontsize <0|8-20>")
            end
        end
    elseif command == "options" or command == "config" or command == "настройки" then
        ns.OpenOptions()
    elseif command == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("debug " .. (ns.db.debug and "on" or "off"))
    elseif command == "reset" then
        ns.ResetDatabase()
        ns.Print("settings reset")
    elseif command == "help" then
        printHelp()
    else
        ns.Print("unknown command, try /bagvalue help")
    end
end
