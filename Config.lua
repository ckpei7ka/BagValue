-- Configuration surface: a Settings panel when the modern Settings API exists,
-- plus the slash commands in Core.lua as the always-available fallback.

local _, ns = ...

local function buildPanel()
    if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
        return nil
    end

    local panel = CreateFrame("Frame", "BagValueOptionsPanel")
    panel.name = "BagValue"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BagValue")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Version " .. ns.version .. " · vendor and auction value of every bag")

    local enable = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    enable.Text:SetText("Enable BagValue")
    enable:SetChecked(ns.db.enabled)
    enable:SetScript("OnClick", function(self)
        ns.db.enabled = self:GetChecked() and true or false
        ns.Print("addon " .. (ns.db.enabled and "enabled" or "disabled"))
    end)

    local showOnLogin = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    showOnLogin:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 0, -6)
    showOnLogin.Text:SetText("Keep the window open (show it at login)")
    showOnLogin:SetChecked(ns.db.showOnLogin)
    showOnLogin:SetScript("OnClick", function(self)
        ns.db.showOnLogin = self:GetChecked() and true or false
        if ns.db.showOnLogin and ns.ShowWindow then
            ns.ShowWindow()
        end
    end)

    local sourceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sourceLabel:SetPoint("TOPLEFT", showOnLogin, "BOTTOMLEFT", 0, -18)
    sourceLabel:SetText("Auction price source")

    local sourceButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sourceButton:SetPoint("TOPLEFT", sourceLabel, "BOTTOMLEFT", 0, -6)
    sourceButton:SetSize(300, 24)

    local customBox

    local function refreshSourceButton()
        sourceButton:SetText("Source: " .. (ns.DescribeSource(ns.db.priceSource) or "Auto"))
    end

    sourceButton:SetScript("OnClick", function(self)
        if ns.OpenSourceMenu then ns.OpenSourceMenu(self) end
    end)
    refreshSourceButton()
    ns.onSourceChanged = function()
        refreshSourceButton()
        if customBox then customBox:SetText(ns.db.customFunction or "") end
    end

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", sourceButton, "BOTTOMLEFT", 0, -6)
    hint:SetWidth(420)
    hint:SetJustifyH("LEFT")
    hint:SetText("Auto prefers TSM, then Auctionator. Other detected sources: " .. ns.DetectedSourceSummary())

    local customLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
    customLabel:SetText("Custom price function (global Lua function name)")

    customBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    customBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -6)
    customBox:SetSize(260, 20)
    customBox:SetAutoFocus(false)
    customBox:SetMaxLetters(80)
    customBox:SetText(ns.db.customFunction or "")

    local function saveCustomFunction(self)
        ns.db.customFunction = strtrim(self:GetText() or "")
        self:ClearFocus()
    end
    customBox:SetScript("OnEnterPressed", saveCustomFunction)
    customBox:SetScript("OnEditFocusLost", saveCustomFunction)

    local customHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    customHint:SetPoint("TOPLEFT", customBox, "BOTTOMLEFT", 0, -6)
    customHint:SetWidth(420)
    customHint:SetJustifyH("LEFT")
    customHint:SetText("Called as fn(itemLink, itemID) and must return copper. Use it for scanners without a public API.")

    local showButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    showButton:SetPoint("TOPLEFT", customHint, "BOTTOMLEFT", 0, -18)
    showButton:SetSize(180, 24)
    showButton:SetText("Show the window")
    showButton:SetScript("OnClick", function()
        if ns.ShowWindow then ns.ShowWindow() end
    end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("LEFT", showButton, "RIGHT", 8, 0)
    resetButton:SetSize(200, 24)
    resetButton:SetText("Reset window size and position")
    resetButton:SetScript("OnClick", function()
        if ns.ResetLayout then ns.ResetLayout() end
    end)

    local windowHint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    windowHint:SetPoint("TOPLEFT", showButton, "BOTTOMLEFT", 0, -8)
    windowHint:SetWidth(460)
    windowHint:SetJustifyH("LEFT")
    windowHint:SetText("Drag the title bar to move the window, drag any corner to resize it diagonally, " ..
        "use the -/+ button in its top-right corner to collapse or expand it. " ..
        "The close button hides it until you open it again with /bagvalue.")

    -- Safety net for clients that hide unrelated frames when the options frame
    -- closes: restore the window if the player left it open on purpose.
    if type(SettingsPanel) == "table" and type(SettingsPanel.HookScript) == "function" then
        SettingsPanel:HookScript("OnHide", function()
            if ns.RestoreWindowIfIntended then ns.RestoreWindowIfIntended() end
        end)
    end

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
    return category
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    local ok, err = pcall(buildPanel)
    if not ok then
        if ns.Debug then ns.Debug("settings panel failed: " .. tostring(err)) end
    end
end)
