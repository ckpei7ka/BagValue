-- The standalone window: three totals, the active price source, a refresh
-- button, a collapse toggle and four corner grips for diagonal resizing.
--
-- The window is a plain frame on UIParent. It is deliberately NOT registered in
-- UISpecialFrames: the client hides all special frames when the game menu is
-- opened (which is what closing the options frame does), and that is why the
-- window used to disappear together with the settings panel. Position, size and
-- the collapsed state are saved, so the frame behaves like a normal HUD window.

local _, ns = ...

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 292, 176
local MIN_WIDTH, MIN_HEIGHT = 230, 104
local COLLAPSED_HEIGHT = 28
local GRIP_SIZE = 16

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function setBackdrop(frame)
    if type(frame.SetBackdrop) ~= "function" then return end
    frame:SetBackdrop(BACKDROP)
    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(0.05, 0.05, 0.08, 0.94)
    end
    if type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(0.62, 0.52, 0.20, 1)
    end
end

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

-- UIParent size decides the resize ceiling; it can still be 0 while the client
-- is loading, so every read falls back to a sane screen size.
local function uiSize(getter, fallback)
    if type(UIParent) == "table" and type(UIParent[getter]) == "function" then
        local ok, value = pcall(UIParent[getter], UIParent)
        if ok then
            local number = ns.SafeNumber(value, nil)
            if number and number > 100 then return number end
        end
    end
    return fallback
end

local function maxWidth()
    return math.max(MIN_WIDTH + 40, uiSize("GetWidth", 1600) - 60)
end

local function maxHeight()
    return math.max(MIN_HEIGHT + 40, uiSize("GetHeight", 1000) - 60)
end

local function thresholdSize()
    return math.max(MIN_WIDTH, math.min(maxWidth(), 1200)),
        math.max(MIN_HEIGHT, math.min(maxHeight(), 900))
end

local function applyBounds(frame)
    local maxW, maxH = thresholdSize()
    if type(frame.SetResizeBounds) == "function" then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, maxW, maxH)
        return
    end
    -- Older builds (and Forever's Lua surface) may only have the two separate
    -- setters; both are best effort.
    if type(frame.SetMinResize) == "function" then
        frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
    end
    if type(frame.SetMaxResize) == "function" then
        frame:SetMaxResize(maxW, maxH)
    end
end

-- Saved layout ---------------------------------------------------------------

local function saveLayout(frame)
    if not ns.db then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.db.window = {
        point = point or "CENTER",
        relativePoint = relativePoint or point or "CENTER",
        x = ns.SafeNumber(x, 0),
        y = ns.SafeNumber(y, 0),
        width = ns.SafeNumber(frame:GetWidth(), DEFAULT_WIDTH),
        height = ns.SafeNumber(frame:GetHeight(), DEFAULT_HEIGHT),
        expandedHeight = ns.SafeNumber(frame.expandedHeight, DEFAULT_HEIGHT),
        collapsed = frame.collapsed and true or false,
    }
    ns.db.collapsed = frame.collapsed and true or false
end

-- Collapse -------------------------------------------------------------------

local function setContentShown(frame, shown)
    local content = frame.content or {}
    for index = 1, #content do
        local region = content[index]
        if shown then region:Show() else region:Hide() end
    end
end

-- Collapsed keeps the title row and the two window buttons only; the height is
-- pinned to the title row and the grips are disabled so a drag cannot stretch
-- the empty shell.
local function applyCollapsed(frame, collapsed, silent)
    collapsed = collapsed and true or false
    if frame.collapsed == collapsed then return end
    frame.collapsed = collapsed

    if collapsed then
        local height = ns.SafeNumber(frame:GetHeight(), DEFAULT_HEIGHT)
        if height > COLLAPSED_HEIGHT then frame.expandedHeight = height end
        setContentShown(frame, false)
        frame:SetResizable(false)
        frame:SetHeight(COLLAPSED_HEIGHT)
    else
        setContentShown(frame, true)
        frame:SetResizable(true)
        frame:SetHeight(clamp(ns.SafeNumber(frame.expandedHeight, DEFAULT_HEIGHT),
            MIN_HEIGHT, maxHeight()))
    end

    if frame.collapseButton then
        frame.collapseButton:SetText(collapsed and "+" or "-")
    end
    if frame.grips then
        for index = 1, #frame.grips do
            local grip = frame.grips[index]
            if collapsed then grip:Disable() else grip:Enable() end
        end
    end
    if ns.db then ns.db.collapsed = collapsed end
    if not silent then saveLayout(frame) end
end

-- Source menu ----------------------------------------------------------------

local function closeSourceMenu()
    local menu, closer = ns.sourceMenu, ns.sourceCloser
    ns.sourceMenu, ns.sourceCloser = nil, nil
    if menu then menu:Hide() end
    if closer then closer:Hide() end
end

local function openSourceMenu(anchor)
    closeSourceMenu()

    local menu = CreateFrame("Frame", "BagValueSourceMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    setBackdrop(menu)

    local sources = ns.PriceSources or {}
    local rowHeight = 20
    local height = 34 + #sources * rowHeight + 8
    menu:SetSize(300, height)
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    menu:SetClampedToScreen(true)

    local title = menu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Price source")

    local current = ns.db and ns.db.priceSource or "auto"
    for index = 1, #sources do
        local source = sources[index]
        local button = CreateFrame("Button", nil, menu)
        button:SetPoint("TOPLEFT", 10, -(30 + (index - 1) * rowHeight))
        button:SetSize(280, rowHeight - 2)

        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 4, 0)
        label:SetJustifyH("LEFT")
        label:SetWidth(270)

        local text = source.label
        if source.id ~= "auto" and source.id ~= "vendor" and not ns.IsSourceAvailable(source.id) then
            text = text .. "  (not detected)"
        end
        if source.id == current then
            text = "> " .. text
            label:SetTextColor(1, 0.82, 0)
        end
        label:SetText(text)

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")

        local sourceId = source.id
        button:SetScript("OnClick", function()
            closeSourceMenu()
            if ns.SetPriceSource then ns.SetPriceSource(sourceId) end
        end)
    end

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints(UIParent)
    closer:SetFrameStrata("FULLSCREEN")
    closer:SetScript("OnClick", closeSourceMenu)

    ns.sourceMenu, ns.sourceCloser = menu, closer
end

ns.OpenSourceMenu = openSourceMenu
ns.CloseSourceMenu = closeSourceMenu

-- Window ---------------------------------------------------------------------

local function addGrip(frame, corner)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint(corner, frame, corner, 0, 0)
    grip:SetFrameLevel(ns.SafeNumber(frame:GetFrameLevel(), 1) + 6)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    if type(grip.SetHighlightTexture) == "function" then
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function(self)
        if frame:IsResizable() then
            frame:StartSizing(corner)
            self:SetScript("OnUpdate", nil)
        end
    end)
    grip:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        saveLayout(frame)
    end)
    grip.corner = corner
    return grip
end

-- Declared before createWindow so the closure can reference the window.
local openWindowSourceMenu = openSourceMenu

local function createWindow()
    local frame = CreateFrame("Frame", "BagValueFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    setBackdrop(frame)
    applyBounds(frame)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveLayout(self)
    end)
    frame:HookScript("OnHide", closeSourceMenu)

    local content = {}
    local grips = {}

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("BagValue")
    content[#content + 1] = title

    -- Top-right buttons: close first, collapse to its left. Both stay visible
    -- while the window is collapsed, so the frame can be reopened.
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() ns.HideWindow() end)

    local collapse = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    collapse:SetSize(18, 18)
    collapse:SetPoint("TOPRIGHT", close, "TOPLEFT", 2, 1)
    collapse:SetText("-")
    collapse:SetScript("OnClick", function()
        applyCollapsed(frame, not frame.collapsed)
    end)
    collapse:SetScript("OnEnter", function(self)
        if type(GameTooltip) ~= "table" then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(frame.collapsed and "Expand" or "Collapse")
    end)
    collapse:SetScript("OnLeave", function()
        if type(GameTooltip) == "table" then GameTooltip:Hide() end
    end)
    frame.collapseButton = collapse

    local rows = {}
    local rowLabels = { "Carried money", "Vendor value", "Auction value" }
    local rowColors = {
        { 1.00, 0.85, 0.25 },
        { 0.55, 0.85, 0.55 },
        { 0.45, 0.70, 1.00 },
    }
    for index = 1, 3 do
        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 14, -36 - (index - 1) * 22)
        label:SetText(rowLabels[index])
        content[#content + 1] = label

        local value = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        value:SetPoint("TOPRIGHT", -14, -34 - (index - 1) * 22)
        value:SetJustifyH("RIGHT")
        value:SetTextColor(rowColors[index][1], rowColors[index][2], rowColors[index][3])
        value:SetText("—")
        content[#content + 1] = value

        rows[index] = { label = label, value = value }
    end

    -- Both text lines anchor to the frame's left and right edges, so they wrap
    -- when the window is narrowed instead of sticking out.
    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("BOTTOMLEFT", 14, 60)
    status:SetPoint("BOTTOMRIGHT", -14, 60)
    status:SetJustifyH("LEFT")
    status:SetText("…")
    content[#content + 1] = status

    local counts = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    counts:SetPoint("BOTTOMLEFT", 14, 46)
    counts:SetPoint("BOTTOMRIGHT", -14, 46)
    counts:SetJustifyH("LEFT")
    counts:SetText("")
    content[#content + 1] = counts

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(84, 20)
    refresh:SetPoint("BOTTOMLEFT", 18, 8)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        if ns.RequestRefresh then ns.RequestRefresh(0, true) end
    end)
    content[#content + 1] = refresh

    local source = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    source:SetPoint("BOTTOMLEFT", refresh, "BOTTOMRIGHT", 6, 0)
    source:SetPoint("BOTTOMRIGHT", -18, 8)
    source:SetHeight(20)
    source:SetText("Source: Auto")
    source:SetScript("OnClick", function(self) openWindowSourceMenu(self) end)
    content[#content + 1] = source

    for _, corner in ipairs({ "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT" }) do
        local grip = addGrip(frame, corner)
        grips[#grips + 1] = grip
        content[#content + 1] = grip
    end

    frame.content = content
    frame.grips = grips
    frame.collapsed = false
    frame.expandedHeight = DEFAULT_HEIGHT

    local function update(result)
        if not result then return end
        rows[1].value:SetText(ns.MoneyString(result.money))
        rows[2].value:SetText(ns.MoneyString(result.vendor))
        if result.auction ~= nil then
            rows[3].value:SetText(ns.MoneyString(result.auction))
            rows[3].value:SetTextColor(rowColors[3][1], rowColors[3][2], rowColors[3][3])
        else
            rows[3].value:SetText("—")
            rows[3].value:SetTextColor(0.6, 0.6, 0.6)
        end

        source:SetText("Source: " .. (ns.DescribeSource(result.sourceId, result.used) or "Auto"))

        local line = ("%s · %s"):format(ns.DescribeSource(result.sourceId, result.used), result.stamp or "")
        if result.noPriceData then
            line = line .. " · no prices yet, scan the auction house in your price addon"
        elseif not result.hasSource then
            line = line .. " · no auction source, vendor only"
        end
        status:SetText(line)

        local countsText = ("%d stacks · %d items · %d auctionable priced"):format(
            result.itemSlots or 0, result.stackCount or 0, result.pricedSlots or 0)
        if (result.unpricedSlots or 0) > 0 then
            countsText = countsText .. (" · %d without price"):format(result.unpricedSlots)
        end
        if (result.boundSlots or 0) > 0 then
            countsText = countsText .. (" · %d soulbound"):format(result.boundSlots)
        end
        counts:SetText(countsText)
    end

    frame.update = update

    -- Restore the saved layout. The window is intentionally absent from
    -- UISpecialFrames, so nothing hides it when the options frame or the game
    -- menu closes.
    local saved = ns.db and ns.db.window
    if type(saved) == "table" then
        local width = clamp(ns.SafeNumber(saved.width, DEFAULT_WIDTH), MIN_WIDTH, maxWidth())
        local height = clamp(ns.SafeNumber(saved.height, DEFAULT_HEIGHT), MIN_HEIGHT, maxHeight())
        frame.expandedHeight = clamp(ns.SafeNumber(saved.expandedHeight, height), MIN_HEIGHT, maxHeight())
        frame:SetSize(width, height)
        if type(saved.point) == "string" then
            frame:ClearAllPoints()
            frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point,
                ns.SafeNumber(saved.x, 0), ns.SafeNumber(saved.y, 0))
        end
        if saved.collapsed then
            applyCollapsed(frame, true, true)
        end
    end

    return frame
end

function ns.EnsureWindow()
    if not ns.window then
        ns.window = createWindow()
    end
    return ns.window
end

function ns.UpdateWindow(result)
    if ns.window and ns.window.update then
        ns.window.update(result)
    end
end

-- Visibility intent ----------------------------------------------------------
-- windowIntent records what the player asked for: shown (login, slash command,
-- settings button) or hidden (the close button). It lets the addon restore the
-- window if a client-side routine hides it as a side effect of closing another
-- frame.

function ns.ShowWindow()
    local frame = ns.EnsureWindow()
    ns.windowIntent = true
    frame:Show()
    if frame.update and ns.lastScan then
        frame.update(ns.lastScan)
    end
    if ns.RequestRefresh then ns.RequestRefresh(0, true) end
end

function ns.HideWindow()
    ns.windowIntent = false
    if ns.window then ns.window:Hide() end
end

function ns.ToggleWindow()
    if ns.IsWindowShown() then
        ns.HideWindow()
    else
        ns.ShowWindow()
    end
end

function ns.IsWindowShown()
    return ns.window ~= nil and ns.window:IsShown()
end

-- Re-shows the window after an unrelated frame closed, but only when the player
-- left it open on purpose.
function ns.RestoreWindowIfIntended()
    if ns.windowIntent and ns.window and not ns.window:IsShown() then
        ns.window:Show()
    end
end

-- Collapse / layout ----------------------------------------------------------

function ns.SetCollapsed(collapsed)
    local frame = ns.EnsureWindow()
    applyCollapsed(frame, collapsed)
end

function ns.ToggleCollapsed()
    local frame = ns.EnsureWindow()
    applyCollapsed(frame, not frame.collapsed)
end

function ns.IsCollapsed()
    return ns.window ~= nil and ns.window.collapsed and true or false
end

function ns.ResetLayout()
    local frame = ns.EnsureWindow()
    frame.collapsed = false
    frame.expandedHeight = DEFAULT_HEIGHT
    frame:SetResizable(true)
    setContentShown(frame, true)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    if frame.collapseButton then frame.collapseButton:SetText("-") end
    if frame.grips then
        for index = 1, #frame.grips do frame.grips[index]:Enable() end
    end
    if ns.db then
        ns.db.window = nil
        ns.db.collapsed = false
    end
    saveLayout(frame)
end
