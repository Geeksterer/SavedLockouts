local AddonName = ...
local frame = CreateFrame("Frame", "SavedLockoutsFrame")

-- State Variable for Active View ("RAID" or "HEROIC")
local currentViewMode = "RAID"

-- Register Events for Instant Lockout & Talent Spec Recording
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("BOSS_KILL")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")

-------------------------------------------------------------------------------
-- BLIZZARD STATIC POPUP DIALOGS
-------------------------------------------------------------------------------

local RefreshIgnoreListUI
local ScanCharacterLockouts
local dashboardFrame

StaticPopupDialogs["SAVEDLOCKOUTS_CLEAR_IGNORE_CONFIRM"] = {
    text = "Really clear the ignore list?",
    button1 = "OK",
    button2 = "Cancel",
    OnAccept = function()
        local realm = GetRealmName()
        if SavedLockoutsDB and SavedLockoutsDB.ignoreList then
            SavedLockoutsDB.ignoreList[realm] = {}
        end
        if RefreshIgnoreListUI then
            RefreshIgnoreListUI()
        end
        if ScanCharacterLockouts then
            ScanCharacterLockouts()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SavedLockouts]|r Ignore list cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SAVEDLOCKOUTS_CLEAR_DATA_CONFIRM"] = {
    text = "Really reset all saved instance information?",
    button1 = "OK",
    button2 = "Cancel",
    OnAccept = function()
        local currentRealm = GetRealmName()
        if SavedLockoutsDB and SavedLockoutsDB.realms then
            SavedLockoutsDB.realms[currentRealm] = {}
        end
        if ScanCharacterLockouts then
            ScanCharacterLockouts()
        end
        if dashboardFrame and dashboardFrame:IsShown() then
            dashboardFrame.displayBox:SetText(GenerateColoredDashboardText(currentViewMode))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SavedLockouts]|r All saved character data wiped. Rescanned current character.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SAVEDLOCKOUTS_HELP_DIALOG"] = {
    text = "Welcome to the SavedLockouts addon. Every time you log into a character  you will see their saved lockouts in the main panel. You can select raids or heroic dungeons on that panel. If you want to hide characters from being reported, you can edit the ignore list in the config panel to ignore characters or hide certain specs (or all specs) if you want to.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS & TALENT SPEC DETECTION
-------------------------------------------------------------------------------

local function GetClassColorHex(englishClass)
    if englishClass and RAID_CLASS_COLORS[englishClass] then
        local c = RAID_CLASS_COLORS[englishClass]
        return string.format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "ffffff"
end

local function FormatRemainingTime(secondsRemaining)
    if secondsRemaining <= 0 then return "Expired" end
    local days = math.floor(secondsRemaining / 86400)
    local hours = math.floor((secondsRemaining % 86400) / 3600)
    local mins = math.floor((secondsRemaining % 3600) / 60)
    
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

local function GetSpecNameForGroup(group)
    local numTabs = GetNumTalentTabs()
    if not numTabs or numTabs == 0 then return "No Spec" end
    
    local maxPoints = -1
    local mainTabName = "No Spec"
    
    for tab = 1, numTabs do
        local name, _, pointsSpent = GetTalentTabInfo(tab, false, false, group)
        if pointsSpent and pointsSpent > maxPoints and pointsSpent > 0 then
            maxPoints = pointsSpent
            mainTabName = name
        end
    end
    return mainTabName
end

local function GetCharacterSpecs()
    local numGroups = GetNumTalentGroups and GetNumTalentGroups() or 1
    local spec1 = GetSpecNameForGroup(1)
    if numGroups > 1 then
        local spec2 = GetSpecNameForGroup(2)
        return spec1 .. "/" .. spec2
    else
        return spec1
    end
end

local function IsCharacterIgnored(realm, charName)
    if SavedLockoutsDB and SavedLockoutsDB.ignoreList and SavedLockoutsDB.ignoreList[realm] then
        local entry = SavedLockoutsDB.ignoreList[realm][charName]
        if type(entry) == "table" then
            return entry.ignored == true
        end
        return entry == true
    end
    return false
end

local function IsSpecIgnored(realm, charName, specIndex)
    if SavedLockoutsDB and SavedLockoutsDB.ignoreList and SavedLockoutsDB.ignoreList[realm] then
        local entry = SavedLockoutsDB.ignoreList[realm][charName]
        if type(entry) == "table" and entry.ignoredSpecs then
            if specIndex and entry.ignoredSpecs[specIndex] == true then
                return true
            end
        end
    end
    return false
end

local function GetFilteredSpecString(realm, charName, rawSpecs)
    if not rawSpecs or rawSpecs == "" or rawSpecs == "No Spec" then
        return ""
    end
    
    local specsList = {}
    if string.find(rawSpecs, "/") then
        for spec in string.gmatch(rawSpecs, "[^/]+") do
            table.insert(specsList, spec)
        end
    else
        table.insert(specsList, rawSpecs)
    end
    
    local activeSpecs = {}
    for idx, specName in ipairs(specsList) do
        if not IsSpecIgnored(realm, charName, idx) then
            table.insert(activeSpecs, specName)
        end
    end
    
    if #activeSpecs > 0 then
        return table.concat(activeSpecs, "/")
    else
        return ""
    end
end

local function IsLockoutRaid(data, key)
    if data and data.isRaid ~= nil then
        return data.isRaid == true
    end
    if key and string.find(key, "%(Heroic%)") then
        return false
    end
    return true
end

local function PurgeExpiredLockouts()
    if not SavedLockoutsDB or not SavedLockoutsDB.realms then return end
    local currentTime = time()
    
    for realm, chars in pairs(SavedLockoutsDB.realms) do
        local totalActiveLockouts = 0
        local hadAnyLockoutsTracked = false
        
        for charName, charData in pairs(chars) do
            if charData.lockouts then
                for key, data in pairs(charData.lockouts) do
                    hadAnyLockoutsTracked = true
                    if data.expiresAt and currentTime >= data.expiresAt then
                        charData.lockouts[key] = nil
                    else
                        totalActiveLockouts = totalActiveLockouts + 1
                    end
                end
            end
        end
        
        if hadAnyLockoutsTracked and totalActiveLockouts == 0 then
            SavedLockoutsDB.realms[realm] = {}
            if GetRealmName() == realm and ScanCharacterLockouts then
                ScanCharacterLockouts()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- DATA SCANNING
-------------------------------------------------------------------------------

ScanCharacterLockouts = function()
    RequestRaidInfo()
    
    local realm = GetRealmName()
    local player = UnitName("player")
    local localizedClass, englishClass = UnitClass("player")
    local englishFaction = UnitFactionGroup("player") or "Unknown"
    local specsString = GetCharacterSpecs()
    
    if not SavedLockoutsDB then SavedLockoutsDB = {} end
    if not SavedLockoutsDB.realms then SavedLockoutsDB.realms = {} end
    if not SavedLockoutsDB.realms[realm] then SavedLockoutsDB.realms[realm] = {} end
    if not SavedLockoutsDB.ignoreList then SavedLockoutsDB.ignoreList = {} end
    if not SavedLockoutsDB.ignoreList[realm] then SavedLockoutsDB.ignoreList[realm] = {} end
    
    if not SavedLockoutsDB.realms[realm][player] then
        SavedLockoutsDB.realms[realm][player] = {
            class = englishClass,
            className = localizedClass,
            faction = englishFaction,
            specs = specsString,
            lockouts = {}
        }
    else
        SavedLockoutsDB.realms[realm][player].class = englishClass
        SavedLockoutsDB.realms[realm][player].className = localizedClass
        SavedLockoutsDB.realms[realm][player].faction = englishFaction
        SavedLockoutsDB.realms[realm][player].specs = specsString
        if not SavedLockoutsDB.realms[realm][player].lockouts then
            SavedLockoutsDB.realms[realm][player].lockouts = {}
        end
    end
    
    SavedLockoutsDB.realms[realm][player].lockouts = {}
    
    if IsCharacterIgnored(realm, player) then
        local existingEntry = SavedLockoutsDB.ignoreList[realm][player]
        local existingIgnoredSpecs = (type(existingEntry) == "table" and existingEntry.ignoredSpecs) or {}
        
        SavedLockoutsDB.ignoreList[realm][player] = {
            ignored = true,
            class = englishClass,
            className = localizedClass,
            faction = englishFaction,
            specs = specsString,
            ignoredSpecs = existingIgnoredSpecs
        }
        return
    end
    
    local numInstances = GetNumSavedInstances()
    local currentTime = time()
    
    for i = 1, numInstances do
        local name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers = GetSavedInstanceInfo(i)
        
        if locked and reset and reset > 0 then
            local isRaidInstance = true
            if maxPlayers and maxPlayers == 5 then
                isRaidInstance = false
            elseif isRaid == false and (not maxPlayers or maxPlayers <= 5) then
                isRaidInstance = false
            end
            
            local displayName
            if isRaidInstance then
                displayName = name .. " " .. (maxPlayers or 10)
            else
                displayName = name .. " (Heroic)"
            end
            
            SavedLockoutsDB.realms[realm][player].lockouts[displayName] = {
                name = displayName,
                expiresAt = currentTime + reset,
                isRaid = isRaidInstance
            }
        end
    end
end

-------------------------------------------------------------------------------
-- TEXT GENERATORS (Filtered by View Mode: "RAID" or "HEROIC")
-------------------------------------------------------------------------------

local function GenerateColoredDashboardText(viewMode)
    PurgeExpiredLockouts()
    local realm = GetRealmName()
    viewMode = viewMode or currentViewMode
    
    if not SavedLockoutsDB or not SavedLockoutsDB.realms or not SavedLockoutsDB.realms[realm] then
        return "|cff808080No saved lockouts recorded for " .. realm .. "|r"
    end
    
    local sortedChars = {}
    for charName, _ in pairs(SavedLockoutsDB.realms[realm]) do
        if not IsCharacterIgnored(realm, charName) then
            table.insert(sortedChars, charName)
        end
    end
    table.sort(sortedChars)
    
    if #sortedChars == 0 then
        return "|cff808080No character data recorded for " .. realm .. "|r"
    end
    
    local lines = {}
    local currentTime = time()
    
    for _, charName in ipairs(sortedChars) do
        local charData = SavedLockoutsDB.realms[realm][charName]
        local lockouts = charData.lockouts or {}
        
        local sortedLocks = {}
        for key, data in pairs(lockouts) do
            if data.expiresAt > currentTime then
                local lockoutIsRaid = IsLockoutRaid(data, key)
                local isMatch = (viewMode == "RAID" and lockoutIsRaid) or (viewMode == "HEROIC" and not lockoutIsRaid)
                
                if isMatch then
                    table.insert(sortedLocks, { key = key, timeLeft = data.expiresAt - currentTime })
                end
            end
        end
        
        local hexColor = GetClassColorHex(charData.class)
        local rawSpecStr = charData.specs or "No Spec"
        local specStr = GetFilteredSpecString(realm, charName, rawSpecStr)
        local factionStr = charData.faction or "Unknown"
        
        local headerLine
        if specStr ~= "" then
            headerLine = string.format("|cff%s%s|r (|cffffffff%s, %s|r):", hexColor, charName, specStr, factionStr)
        else
            headerLine = string.format("|cff%s%s|r (|cffffffff%s|r):", hexColor, charName, factionStr)
        end
        table.insert(lines, headerLine)
        
        if #sortedLocks > 0 then
            table.sort(sortedLocks, function(a, b) return a.key < b.key end)
            for _, lock in ipairs(sortedLocks) do
                local timeStr = FormatRemainingTime(lock.timeLeft)
                table.insert(lines, string.format("  |cffdddddd- %s|r - |cffffd100[%s]|r", lock.key, timeStr))
            end
        else
            local emptyMsg = (viewMode == "RAID") and "Character is not saved to any raid lockout for this period." or "Character is not saved to any heroic dungeon for this period."
            table.insert(lines, string.format("  |cff808080- %s|r", emptyMsg))
        end
        table.insert(lines, "")
    end
    
    return table.concat(lines, "\n")
end

local function GeneratePlainExportText(viewMode, isDiscord)
    PurgeExpiredLockouts()
    local realm = GetRealmName()
    viewMode = viewMode or currentViewMode
    
    local addonVer = (AddonName and GetAddOnMetadata(AddonName, "Version")) or "1.0"
    local lines = {}
    
    if isDiscord then
        table.insert(lines, "# SavedLockouts (" .. addonVer .. ") addon by Copper")
        local headerTitle = (viewMode == "RAID") and "Account Raid Lockouts" or "Account Heroic Lockouts"
        table.insert(lines, "### " .. headerTitle .. " (" .. realm .. ")")
        table.insert(lines, "")
    else
        table.insert(lines, "SavedLockouts (" .. addonVer .. ") addon by Copper")
        local headerTitle = (viewMode == "RAID") and "ACCOUNT RAID LOCKOUTS" or "ACCOUNT HEROIC LOCKOUTS"
        table.insert(lines, string.format("=== %s (%s) ===", headerTitle, realm))
        table.insert(lines, "")
    end
    
    if not SavedLockoutsDB or not SavedLockoutsDB.realms or not SavedLockoutsDB.realms[realm] then
        table.insert(lines, "No lockout data saved for " .. realm)
        return table.concat(lines, "\n")
    end
    
    local sortedChars = {}
    for charName, _ in pairs(SavedLockoutsDB.realms[realm]) do
        if not IsCharacterIgnored(realm, charName) then
            table.insert(sortedChars, charName)
        end
    end
    table.sort(sortedChars)
    
    if #sortedChars == 0 then
        table.insert(lines, "No character data recorded.")
        return table.concat(lines, "\n")
    end
    
    local currentTime = time()
    
    for _, charName in ipairs(sortedChars) do
        local charData = SavedLockoutsDB.realms[realm][charName]
        local lockouts = charData.lockouts or {}
        
        local sortedLocks = {}
        for key, data in pairs(lockouts) do
            if data.expiresAt > currentTime then
                local lockoutIsRaid = IsLockoutRaid(data, key)
                local isMatch = (viewMode == "RAID" and lockoutIsRaid) or (viewMode == "HEROIC" and not lockoutIsRaid)
                
                if isMatch then
                    table.insert(sortedLocks, { key = key, timeLeft = data.expiresAt - currentTime })
                end
            end
        end
        
        local rawSpecStr = charData.specs or "No Spec"
        local specStr = GetFilteredSpecString(realm, charName, rawSpecStr)
        local classStr = charData.className or charData.class or "Unknown"
        local factionStr = charData.faction or "Unknown"
        
        local headerLine
        if isDiscord then
            if specStr ~= "" then
                headerLine = string.format("### %s (%s, %s, %s)", charName, specStr, classStr, factionStr)
            else
                headerLine = string.format("### %s (%s, %s)", charName, classStr, factionStr)
            end
        else
            if specStr ~= "" then
                headerLine = string.format("%s (%s, %s, %s)", charName, specStr, classStr, factionStr)
            else
                headerLine = string.format("%s (%s, %s)", charName, classStr, factionStr)
            end
        end
        table.insert(lines, headerLine)
        
        if #sortedLocks > 0 then
            table.sort(sortedLocks, function(a, b) return a.key < b.key end)
            for _, lock in ipairs(sortedLocks) do
                local timeStr = FormatRemainingTime(lock.timeLeft)
                if isDiscord then
                    table.insert(lines, string.format("- %s - [%s]", lock.key, timeStr))
                else
                    table.insert(lines, string.format("%s - [%s]", lock.key, timeStr))
                end
            end
        else
            local emptyMsg = (viewMode == "RAID") and "Character is not saved to any raid lockout for this period." or "Character is not saved to any heroic dungeon for this period."
            if isDiscord then
                table.insert(lines, string.format("- %s", emptyMsg))
            else
                table.insert(lines, string.format("%s", emptyMsg))
            end
        end
        table.insert(lines, "")
    end
    
    return table.concat(lines, "\n")
end

-------------------------------------------------------------------------------
-- UI WINDOW REFERENCES
-------------------------------------------------------------------------------

local exportWindow = nil
local ignoreWindow = nil
local configWindow = nil

local OpenConfigWindow
local ToggleDashboard

-------------------------------------------------------------------------------
-- UI: IGNORE LIST PANEL
-------------------------------------------------------------------------------

local ignoreMainButtons = {}
local ignoreSpec1Buttons = {}
local ignoreSpec2Buttons = {}

RefreshIgnoreListUI = function()
    if not ignoreWindow or not ignoreWindow:IsShown() then return end
    
    local realm = GetRealmName()
    local charMap = {}
    
    if SavedLockoutsDB and SavedLockoutsDB.realms and SavedLockoutsDB.realms[realm] then
        for cName, _ in pairs(SavedLockoutsDB.realms[realm]) do
            charMap[cName] = true
        end
    end
    if SavedLockoutsDB and SavedLockoutsDB.ignoreList and SavedLockoutsDB.ignoreList[realm] then
        for cName, entry in pairs(SavedLockoutsDB.ignoreList[realm]) do
            if (type(entry) == "table" and (entry.ignored or (entry.ignoredSpecs and (entry.ignoredSpecs[1] or entry.ignoredSpecs[2])))) or entry == true then
                charMap[cName] = true
            end
        end
    end
    
    local sortedAll = {}
    for cName, _ in pairs(charMap) do
        table.insert(sortedAll, cName)
    end
    table.sort(sortedAll)
    
    for _, btn in ipairs(ignoreMainButtons) do btn:Hide() end
    for _, btn in ipairs(ignoreSpec1Buttons) do btn:Hide() end
    for _, btn in ipairs(ignoreSpec2Buttons) do btn:Hide() end
    
    local yOffset = 10
    for i, charName in ipairs(sortedAll) do
        local rData = SavedLockoutsDB.realms and SavedLockoutsDB.realms[realm] and SavedLockoutsDB.realms[realm][charName]
        local iData = SavedLockoutsDB.ignoreList and SavedLockoutsDB.ignoreList[realm] and SavedLockoutsDB.ignoreList[realm][charName]
        
        local charClass = (rData and rData.class) or (type(iData) == "table" and iData.class)
        local charSpecs = (rData and rData.specs) or (type(iData) == "table" and iData.specs) or "No Spec"
        local charFaction = (rData and rData.faction) or (type(iData) == "table" and iData.faction) or "Unknown"
        
        -- Main Character Checkbutton
        local btnMain = ignoreMainButtons[i]
        if not btnMain then
            btnMain = CreateFrame("CheckButton", "SavedLockoutsIgnoreMainCheck" .. i, ignoreWindow.scrollChild, "UICheckButtonTemplate")
            ignoreMainButtons[i] = btnMain
        end
        
        btnMain:SetSize(22, 22)
        btnMain:SetPoint("TOPLEFT", ignoreWindow.scrollChild, "TOPLEFT", 10, -yOffset)
        
        local labelText = charName
        if charClass then
            local hexColor = GetClassColorHex(charClass)
            labelText = string.format("|cff%s%s|r (|cffffffff%s|r)", hexColor, charName, charFaction)
        end
        
        local textObj = _G[btnMain:GetName() .. "Text"]
        if textObj then
            textObj:SetText("Ignore Character: " .. labelText)
            textObj:SetFontObject(ChatFontNormal)
        end
        
        btnMain:SetChecked(IsCharacterIgnored(realm, charName))
        
        btnMain:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked() == 1 or self:GetChecked() == true
            if not SavedLockoutsDB.ignoreList then SavedLockoutsDB.ignoreList = {} end
            if not SavedLockoutsDB.ignoreList[realm] then SavedLockoutsDB.ignoreList[realm] = {} end
            
            if type(SavedLockoutsDB.ignoreList[realm][charName]) ~= "table" then
                SavedLockoutsDB.ignoreList[realm][charName] = {
                    ignored = isChecked,
                    class = charClass,
                    className = (rData and rData.className) or (type(iData) == "table" and iData.className),
                    faction = charFaction,
                    specs = charSpecs,
                    ignoredSpecs = (type(iData) == "table" and iData.ignoredSpecs) or {}
                }
            else
                SavedLockoutsDB.ignoreList[realm][charName].ignored = isChecked
            end
            ScanCharacterLockouts()
        end)
        
        btnMain:Show()
        yOffset = yOffset + 24
        
        -- Spec Checkbuttons
        local spec1, spec2
        if charSpecs and charSpecs ~= "No Spec" and charSpecs ~= "" then
            if string.find(charSpecs, "/") then
                spec1, spec2 = string.match(charSpecs, "([^/]+)/([^/]+)")
            else
                spec1 = charSpecs
            end
        end
        
        if spec1 then
            local btnSpec1 = ignoreSpec1Buttons[i]
            if not btnSpec1 then
                btnSpec1 = CreateFrame("CheckButton", "SavedLockoutsIgnoreSpec1Check" .. i, ignoreWindow.scrollChild, "UICheckButtonTemplate")
                ignoreSpec1Buttons[i] = btnSpec1
            end
            
            btnSpec1:SetSize(20, 20)
            btnSpec1:SetPoint("TOPLEFT", ignoreWindow.scrollChild, "TOPLEFT", 35, -yOffset)
            
            local s1Text = _G[btnSpec1:GetName() .. "Text"]
            if s1Text then
                s1Text:SetText("Ignore Spec 1 (" .. spec1 .. ")")
                s1Text:SetFontObject(ChatFontSmall)
            end
            
            btnSpec1:SetChecked(IsSpecIgnored(realm, charName, 1))
            
            btnSpec1:SetScript("OnClick", function(self)
                local isChecked = self:GetChecked() == 1 or self:GetChecked() == true
                if not SavedLockoutsDB.ignoreList then SavedLockoutsDB.ignoreList = {} end
                if not SavedLockoutsDB.ignoreList[realm] then SavedLockoutsDB.ignoreList[realm] = {} end
                
                if type(SavedLockoutsDB.ignoreList[realm][charName]) ~= "table" then
                    SavedLockoutsDB.ignoreList[realm][charName] = {
                        ignored = IsCharacterIgnored(realm, charName),
                        class = charClass,
                        className = (rData and rData.className) or (type(iData) == "table" and iData.className),
                        faction = charFaction,
                        specs = charSpecs,
                        ignoredSpecs = {}
                    }
                end
                if not SavedLockoutsDB.ignoreList[realm][charName].ignoredSpecs then
                    SavedLockoutsDB.ignoreList[realm][charName].ignoredSpecs = {}
                end
                
                SavedLockoutsDB.ignoreList[realm][charName].ignoredSpecs[1] = isChecked or nil
                
                if dashboardFrame and dashboardFrame:IsShown() then
                    dashboardFrame.displayBox:SetText(GenerateColoredDashboardText(currentViewMode))
                end
            end)
            
            btnSpec1:Show()
            
            if spec2 then
                local btnSpec2 = ignoreSpec2Buttons[i]
                if not btnSpec2 then
                    btnSpec2 = CreateFrame("CheckButton", "SavedLockoutsIgnoreSpec2Check" .. i, ignoreWindow.scrollChild, "UICheckButtonTemplate")
                    ignoreSpec2Buttons[i] = btnSpec2
                end
                
                btnSpec2:SetSize(20, 20)
                btnSpec2:SetPoint("LEFT", btnSpec1, "RIGHT", 140, 0)
                
                local s2Text = _G[btnSpec2:GetName() .. "Text"]
                if s2Text then
                    s2Text:SetText("Ignore Spec 2 (" .. spec2 .. ")")
                    s2Text:SetFontObject(ChatFontSmall)
                end
                
                btnSpec2:SetChecked(IsSpecIgnored(realm, charName, 2))
                
                btnSpec2:SetScript("OnClick", function(self)
                    local isChecked = self:GetChecked() == 1 or self:GetChecked() == true
                    if not SavedLockoutsDB.ignoreList then SavedLockoutsDB.ignoreList = {} end
                    if not SavedLockoutsDB.ignoreList[realm] then SavedLockoutsDB.ignoreList[realm] = {} end
                    
                    if type(SavedLockoutsDB.ignoreList[realm][charName]) ~= "table" then
                        SavedLockoutsDB.ignoreList[realm][charName] = {
                            ignored = IsCharacterIgnored(realm, charName),
                            class = charClass,
                            className = (rData and rData.className) or (type(iData) == "table" and iData.className),
                            faction = charFaction,
                            specs = charSpecs,
                            ignoredSpecs = {}
                        }
                    end
                    if not SavedLockoutsDB.ignoreList[realm][charName].ignoredSpecs then
                        SavedLockoutsDB.ignoreList[realm][charName].ignoredSpecs = {}
                    end
                    
                    SavedLockoutsDB.ignoreList[realm][charName].ignoredSpecs[2] = isChecked or nil
                    
                    if dashboardFrame and dashboardFrame:IsShown() then
                        dashboardFrame.displayBox:SetText(GenerateColoredDashboardText(currentViewMode))
                    end
                end)
                
                btnSpec2:Show()
            end
            
            yOffset = yOffset + 22
        end
        
        yOffset = yOffset + 8
    end
    
    ignoreWindow.scrollChild:SetHeight(math.max(yOffset + 10, 320))
end

local function OpenIgnoreWindow()
    if dashboardFrame and dashboardFrame:IsShown() then
        dashboardFrame:Hide()
    end
    if configWindow and configWindow:IsShown() then
        configWindow:Hide()
    end
    if exportWindow and exportWindow:IsShown() then
        exportWindow:Hide()
    end
    
    if not ignoreWindow then
        local f = CreateFrame("Frame", "SavedLockoutsIgnoreWindow", UIParent)
        f:SetSize(600, 450)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameLevel(UIParent:GetFrameLevel() + 20)
        
        tinsert(UISpecialFrames, "SavedLockoutsIgnoreWindow")
        
        f:SetScript("OnHide", function()
            if dashboardFrame and dashboardFrame:IsShown() then
                dashboardFrame:Hide()
            end
        end)
        
        local titleBg = f:CreateTexture(nil, "HIGH")
        titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        titleBg:SetSize(440, 64)
        titleBg:SetPoint("TOP", f, "TOP", 0, 12)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", titleBg, "TOP", 0, -14)
        title:SetText("SavedLockouts Addon Ignore List")
        
        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
        
        local innerPanel = CreateFrame("Frame", nil, f)
        innerPanel:SetSize(560, 340)
        innerPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -45)
        innerPanel:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        innerPanel:SetBackdropColor(0, 0, 0, 0.6)
        
        local scrollArea = CreateFrame("ScrollFrame", "SavedLockoutsIgnoreScroll", innerPanel, "UIPanelScrollFrameTemplate")
        scrollArea:SetPoint("TOPLEFT", innerPanel, "TOPLEFT", 10, -10)
        scrollArea:SetPoint("BOTTOMRIGHT", innerPanel, "BOTTOMRIGHT", -28, 10)
        
        local scrollChild = CreateFrame("Frame", nil, scrollArea)
        scrollChild:SetSize(510, 320)
        scrollArea:SetScrollChild(scrollChild)
        f.scrollChild = scrollChild
        
        local clearIgnoreBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearIgnoreBtn:SetSize(160, 24)
        clearIgnoreBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
        clearIgnoreBtn:SetText("Clear Ignore List")
        clearIgnoreBtn:SetScript("OnClick", function()
            StaticPopup_Show("SAVEDLOCKOUTS_CLEAR_IGNORE_CONFIRM")
        end)
        
        ignoreWindow = f
    end
    
    ignoreWindow:Show()
    RefreshIgnoreListUI()
end

-------------------------------------------------------------------------------
-- UI: CONFIG PANEL
-------------------------------------------------------------------------------

OpenConfigWindow = function()
    if dashboardFrame and dashboardFrame:IsShown() then
        dashboardFrame:Hide()
    end
    if ignoreWindow and ignoreWindow:IsShown() then
        ignoreWindow:Hide()
    end
    if exportWindow and exportWindow:IsShown() then
        exportWindow:Hide()
    end

    if not configWindow then
        local f = CreateFrame("Frame", "SavedLockoutsConfigWindow", UIParent)
        f:SetSize(380, 260)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameLevel(UIParent:GetFrameLevel() + 20)
        
        tinsert(UISpecialFrames, "SavedLockoutsConfigWindow")
        
        local titleBg = f:CreateTexture(nil, "HIGH")
        titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        titleBg:SetSize(320, 64)
        titleBg:SetPoint("TOP", f, "TOP", 0, 12)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", titleBg, "TOP", 0, -14)
        title:SetText("SavedLockouts Config")
        
        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
        
        local ignoreBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ignoreBtn:SetSize(220, 28)
        ignoreBtn:SetPoint("TOP", f, "TOP", 0, -50)
        ignoreBtn:SetText("Edit Ignore List")
        ignoreBtn:SetScript("OnClick", function()
            OpenIgnoreWindow()
        end)
        
        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(220, 28)
        clearBtn:SetPoint("TOP", ignoreBtn, "BOTTOM", 0, -12)
        clearBtn:SetText("Clear All Saved Data")
        clearBtn:SetScript("OnClick", function()
            StaticPopup_Show("SAVEDLOCKOUTS_CLEAR_DATA_CONFIRM")
        end)
        
        local helpBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        helpBtn:SetSize(220, 28)
        helpBtn:SetPoint("TOP", clearBtn, "BOTTOM", 0, -12)
        helpBtn:SetText("Help")
        helpBtn:SetScript("OnClick", function()
            StaticPopup_Show("SAVEDLOCKOUTS_HELP_DIALOG")
        end)

        local mainPanelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        mainPanelBtn:SetSize(220, 28)
        mainPanelBtn:SetPoint("TOP", helpBtn, "BOTTOM", 0, -12)
        mainPanelBtn:SetText("Open Main Instances Panel")
        mainPanelBtn:SetScript("OnClick", function()
            ToggleDashboard()
        end)

        configWindow = f
    end

    configWindow:Show()
end

local function ToggleConfigWindow()
    if configWindow and configWindow:IsShown() then
        configWindow:Hide()
    else
        OpenConfigWindow()
    end
end

-------------------------------------------------------------------------------
-- UI: EXPORT POPUP WINDOW
-------------------------------------------------------------------------------

local function OpenExportWindow()
    if dashboardFrame and dashboardFrame:IsShown() then
        dashboardFrame:Hide()
    end
    if configWindow and configWindow:IsShown() then
        configWindow:Hide()
    end
    if ignoreWindow and ignoreWindow:IsShown() then
        ignoreWindow:Hide()
    end

    if not exportWindow then
        local f = CreateFrame("Frame", "SavedLockoutsExportWindow", UIParent)
        f:SetSize(600, 440)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameLevel(UIParent:GetFrameLevel() + 20)
        
        tinsert(UISpecialFrames, "SavedLockoutsExportWindow")
        
        f:SetScript("OnHide", function()
            if dashboardFrame and dashboardFrame:IsShown() then
                dashboardFrame:Hide()
            end
        end)
        
        local titleBg = f:CreateTexture(nil, "HIGH")
        titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        titleBg:SetSize(380, 64)
        titleBg:SetPoint("TOP", f, "TOP", 0, 12)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", titleBg, "TOP", 0, -14)
        f.titleText = title
        
        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
        
        local innerPanel = CreateFrame("Frame", nil, f)
        innerPanel:SetSize(560, 290)
        innerPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -45)
        innerPanel:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        innerPanel:SetBackdropColor(0, 0, 0, 0.6)
        
        local scrollArea = CreateFrame("ScrollFrame", "SavedLockoutsExportScroll", innerPanel, "UIPanelScrollFrameTemplate")
        scrollArea:SetPoint("TOPLEFT", innerPanel, "TOPLEFT", 10, -10)
        scrollArea:SetPoint("BOTTOMRIGHT", innerPanel, "BOTTOMRIGHT", -28, 10)
        
        local editBox = CreateFrame("EditBox", "SavedLockoutsExportEditBox", scrollArea)
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(99999)
        editBox:EnableMouse(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(510)
        
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            f:Hide()
        end)
        
        scrollArea:SetScrollChild(editBox)
        f.editBox = editBox
        
        -- Discord Output Checkbox
        local discordCheck = CreateFrame("CheckButton", "SavedLockoutsDiscordCheck", f, "UICheckButtonTemplate")
        discordCheck:SetSize(24, 24)
        discordCheck:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 16)
        
        local dText = _G[discordCheck:GetName() .. "Text"]
        if dText then
            dText:SetText("Discord Output")
            dText:SetFontObject(GameFontNormal)
        end
        
        discordCheck:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked() == 1 or self:GetChecked() == true
            f.editBox:SetText(GeneratePlainExportText(currentViewMode, isChecked))
            f.editBox:SetFocus()
            f.editBox:HighlightText()
        end)
        f.discordCheck = discordCheck
        
        local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        selectBtn:SetSize(120, 24)
        selectBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)
        selectBtn:SetText("Select All")
        selectBtn:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        
        exportWindow = f
    end
    
    local viewTitle = (currentViewMode == "RAID") and "Export Raids (Ctrl+C)" or "Export Heroics (Ctrl+C)"
    exportWindow.titleText:SetText(viewTitle)
    
    exportWindow.discordCheck:SetChecked(false)
    exportWindow.editBox:SetText(GeneratePlainExportText(currentViewMode, false))
    exportWindow:Show()
    exportWindow.editBox:SetFocus()
    exportWindow.editBox:HighlightText()
end

-------------------------------------------------------------------------------
-- UI: MAIN DASHBOARD VIEWING WINDOW (RUT Style 720x520)
-------------------------------------------------------------------------------

local function CreateMainDashboard()
    if dashboardFrame then return dashboardFrame end
    
    local f = CreateFrame("Frame", "SavedLockoutsDashboard", UIParent)
    f:SetSize(720, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    
    tinsert(UISpecialFrames, "SavedLockoutsDashboard")
    
    local titleBg = f:CreateTexture(nil, "HIGH")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetSize(480, 64)
    titleBg:SetPoint("TOP", f, "TOP", 0, 12)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", titleBg, "TOP", 0, -14)
    title:SetText("SavedLockouts Addon by Copper")
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    
    -- Top Command Bar Buttons
    local configBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    configBtn:SetSize(120, 24)
    configBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -35)
    configBtn:SetText("Config Panel")
    configBtn:SetScript("OnClick", function()
        OpenConfigWindow()
    end)

    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(100, 24)
    refreshBtn:SetPoint("LEFT", configBtn, "RIGHT", 8, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        ScanCharacterLockouts()
        f.displayBox:SetText(GenerateColoredDashboardText(currentViewMode))
    end)

    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(130, 24)
    exportBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -35)
    exportBtn:SetText("Export Data")
    exportBtn:SetScript("OnClick", function()
        OpenExportWindow()
    end)
    
    -- View Selector Tabs (Raids vs Heroic 5-Mans)
    local raidTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    raidTab:SetSize(130, 22)
    raidTab:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -66)
    raidTab:SetText("Raids")
    
    local heroicTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    heroicTab:SetSize(140, 22)
    heroicTab:SetPoint("LEFT", raidTab, "RIGHT", 6, 0)
    heroicTab:SetText("Heroic 5-Mans")
    
    local function UpdateTabSelection()
        if currentViewMode == "RAID" then
            raidTab:LockHighlight()
            heroicTab:UnlockHighlight()
        else
            heroicTab:LockHighlight()
            raidTab:UnlockHighlight()
        end
        ScanCharacterLockouts()
        f.displayBox:SetText(GenerateColoredDashboardText(currentViewMode))
    end
    
    raidTab:SetScript("OnClick", function()
        currentViewMode = "RAID"
        UpdateTabSelection()
    end)
    
    heroicTab:SetScript("OnClick", function()
        currentViewMode = "HEROIC"
        UpdateTabSelection()
    end)
    
    -- RUT Inner Dark Inset Box
    local innerPanel = CreateFrame("Frame", nil, f)
    innerPanel:SetSize(680, 400)
    innerPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -92)
    innerPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    innerPanel:SetBackdropColor(0, 0, 0, 0.6)
    
    local scrollArea = CreateFrame("ScrollFrame", "SavedLockoutsDashScroll", innerPanel, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", innerPanel, "TOPLEFT", 10, -10)
    scrollArea:SetPoint("BOTTOMRIGHT", innerPanel, "BOTTOMRIGHT", -28, 10)
    
    local displayBox = CreateFrame("EditBox", nil, scrollArea)
    displayBox:SetMultiLine(true)
    displayBox:SetMaxLetters(99999)
    displayBox:EnableMouse(true)
    displayBox:SetAutoFocus(false)
    displayBox:SetFontObject(ChatFontNormal)
    displayBox:SetWidth(630)
    
    scrollArea:SetScrollChild(displayBox)
    f.displayBox = displayBox
    f.UpdateTabSelection = UpdateTabSelection
    
    -- Read metadata dynamically using vararg AddonName (fallback to 1.0)
    local addonVer = (AddonName and GetAddOnMetadata(AddonName, "Version")) or "1.0"
    
    local footerText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 10)
    footerText:SetText("SavedLockouts v" .. addonVer)
    
    dashboardFrame = f
    return dashboardFrame
end

ToggleDashboard = function()
    if configWindow and configWindow:IsShown() then
        configWindow:Hide()
    end
    if ignoreWindow and ignoreWindow:IsShown() then
        ignoreWindow:Hide()
    end
    if exportWindow and exportWindow:IsShown() then
        exportWindow:Hide()
    end
    
    local win = CreateMainDashboard()
    if win:IsShown() then
        win:Hide()
    else
        win.UpdateTabSelection()
        win:Show()
    end
end

-------------------------------------------------------------------------------
-- MINIMAP BUTTON (Left Click = Main Panel, Right Click = Config)
-------------------------------------------------------------------------------

local minimapBtn = nil

local function UpdateMinimapButtonPosition()
    if not minimapBtn then return end
    
    if minimapBtn:GetParent() ~= Minimap then return end
    
    local angle = math.rad(SavedLockoutsDB.minimapAngle or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if minimapBtn then return end
    
    local btn = CreateFrame("Button", "SavedLockoutsMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\spell_shadow_unholyfrenzy")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -11, 11)
    
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton", "RightButton")
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("SavedLockouts", 1, 1, 1)
        GameTooltip:AddLine("Left-Click: Open Main Instances Panel", 0.2, 1, 0.2)
        GameTooltip:AddLine("Right-Click: Open Config Panel", 0.2, 1, 0.2)
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    btn:SetScript("OnClick", function(self, buttonPressed)
        if buttonPressed == "LeftButton" then
            ToggleDashboard()
        elseif buttonPressed == "RightButton" then
            ToggleConfigWindow()
        end
    end)
    
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            SavedLockoutsDB.minimapAngle = angle
            UpdateMinimapButtonPosition()
        end)
    end)
    
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    minimapBtn = btn
    UpdateMinimapButtonPosition()
end

-------------------------------------------------------------------------------
-- EVENTS & SLASH COMMANDS
-------------------------------------------------------------------------------

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == AddonName then
            if not SavedLockoutsDB then SavedLockoutsDB = {} end
            if not SavedLockoutsDB.minimapAngle then SavedLockoutsDB.minimapAngle = 45 end
            if not SavedLockoutsDB.ignoreList then SavedLockoutsDB.ignoreList = {} end
            
            PurgeExpiredLockouts()
            CreateMinimapButton()
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_INSTANCE_INFO" or event == "BOSS_KILL" or event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" then
        ScanCharacterLockouts()
    end
end)

SLASH_SAVEDLOCKOUTS1 = "/lockouts"
SLASH_SAVEDLOCKOUTS2 = "/sl"
SlashCmdList["SAVEDLOCKOUTS"] = function(msg)
    local cmd = string.lower(strtrim(msg or ""))
    if cmd == "config" or cmd == "options" or cmd == "opt" then
        OpenConfigWindow()
    else
        ToggleDashboard()
    end
end
