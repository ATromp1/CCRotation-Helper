local addonName, addon = ...

-- CooldownTracker - OmniCD-inspired cooldown tracking system
-- Replaces LibOpenRaid dependency with native WoW API tracking
addon.CooldownTracker = {}
local CooldownTracker = addon.CooldownTracker

-- LibGroupInSpecT integration
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1")

-- Global debug system for CCRotationHelper
if not addon.DebugSystem then
    addon.DebugSystem = {}
    local debugFrame = nil
    local debugLines = {}
    local MAX_DEBUG_LINES = 40

    local function CreateDebugFrame()
        if debugFrame then return end
        
        debugFrame = CreateFrame("Frame", "CCRotationDebugFrame", UIParent, "BasicFrameTemplateWithInset")
        debugFrame:SetSize(800, 800)
        debugFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
        debugFrame:SetMovable(true)
        debugFrame:EnableMouse(true)
        debugFrame:RegisterForDrag("LeftButton")
        debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
        debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
        
        debugFrame.title = debugFrame:CreateFontString(nil, "OVERLAY")
        debugFrame.title:SetFontObject("GameFontHighlight")
        debugFrame.title:SetPoint("LEFT", debugFrame.TitleBg, "LEFT", 5, 0)
        debugFrame.title:SetText("CCRotationHelper Debug")
        
        -- Add copy button
        debugFrame.copyButton = CreateFrame("Button", nil, debugFrame, "UIPanelButtonTemplate")
        debugFrame.copyButton:SetSize(60, 20)
        debugFrame.copyButton:SetPoint("RIGHT", debugFrame.TitleBg, "RIGHT", -5, 0)
        debugFrame.copyButton:SetText("Copy")
        debugFrame.copyButton:SetScript("OnClick", function()
            local debugText = table.concat(debugLines, "\n")
            
            -- Create a popup frame with selectable text
            local copyFrame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
            copyFrame:SetSize(600, 400)
            copyFrame:SetPoint("CENTER")
            copyFrame:SetMovable(true)
            copyFrame:EnableMouse(true)
            copyFrame:RegisterForDrag("LeftButton")
            copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
            copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
            copyFrame:SetFrameStrata("DIALOG")
            
            copyFrame.title = copyFrame:CreateFontString(nil, "OVERLAY")
            copyFrame.title:SetFontObject("GameFontHighlight")
            copyFrame.title:SetPoint("LEFT", copyFrame.TitleBg, "LEFT", 5, 0)
            copyFrame.title:SetText("Copy Debug Text (Ctrl+A, Ctrl+C)")
            
            -- Create close button
            copyFrame.closeButton = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
            copyFrame.closeButton:SetPoint("TOPRIGHT", copyFrame, "TOPRIGHT", -5, -5)
            copyFrame.closeButton:SetScript("OnClick", function() copyFrame:Hide() end)
            
            -- Create scroll frame for the edit box
            local scrollFrame = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", copyFrame.InsetBorderTop, "BOTTOMLEFT", 10, -10)
            scrollFrame:SetPoint("BOTTOMRIGHT", copyFrame.InsetBorderBottom, "TOPRIGHT", -30, 10)
            
            -- Create the edit box
            local editBox = CreateFrame("EditBox", nil, scrollFrame)
            editBox:SetMultiLine(true)
            editBox:SetAutoFocus(true)
            editBox:SetFontObject("ChatFontNormal")
            editBox:SetText(debugText)
            editBox:SetSize(560, 350)
            editBox:SetCursorPosition(0)
            editBox:HighlightText()
            
            scrollFrame:SetScrollChild(editBox)
            
            -- Auto-select all text
            C_Timer.After(0.1, function()
                editBox:SetFocus()
                editBox:HighlightText()
            end)
            
            copyFrame:Show()
        end)
        
        -- Create scroll frame
        debugFrame.scrollFrame = CreateFrame("ScrollFrame", nil, debugFrame, "UIPanelScrollFrameTemplate")
        debugFrame.scrollFrame:SetPoint("TOPLEFT", debugFrame.InsetBorderTop, "BOTTOMLEFT", 10, -10)
        debugFrame.scrollFrame:SetPoint("BOTTOMRIGHT", debugFrame.InsetBorderBottom, "TOPRIGHT", -30, 10)
        
        -- Create content frame inside scroll frame
        debugFrame.content = CreateFrame("Frame", nil, debugFrame.scrollFrame)
        debugFrame.content:SetSize(750, 1) -- Width fixed, height will be adjusted
        debugFrame.scrollFrame:SetScrollChild(debugFrame.content)
        
        -- Create text widget inside content frame
        debugFrame.text = debugFrame.content:CreateFontString(nil, "OVERLAY")
        debugFrame.text:SetFontObject("GameFontNormalSmall")
        debugFrame.text:SetPoint("TOPLEFT", debugFrame.content, "TOPLEFT", 0, 0)
        debugFrame.text:SetPoint("TOPRIGHT", debugFrame.content, "TOPRIGHT", 0, 0)
        debugFrame.text:SetJustifyH("LEFT")
        debugFrame.text:SetJustifyV("TOP")
        debugFrame.text:SetText("Debug output will appear here...")
        
        debugFrame:Show()
    end

    function addon.DebugSystem.Print(msg, source)
        CreateDebugFrame()
        
        -- Add timestamp and source
        local timestamp = date("%H:%M:%S")
        local sourceTag = source and ("[" .. source .. "] ") or ""
        local fullMsg = "[" .. timestamp .. "] " .. sourceTag .. msg
        
        table.insert(debugLines, fullMsg)
        
        -- Keep only last MAX_DEBUG_LINES
        if #debugLines > MAX_DEBUG_LINES then
            table.remove(debugLines, 1)
        end
        
        -- Update display
        local displayText = table.concat(debugLines, "\n")
        debugFrame.text:SetText(displayText)
        
        -- Adjust content height based on text
        local textHeight = debugFrame.text:GetStringHeight()
        debugFrame.content:SetHeight(math.max(textHeight + 20, debugFrame.scrollFrame:GetHeight()))
        
        -- Auto-scroll to bottom
        C_Timer.After(0, function()
            debugFrame.scrollFrame:SetVerticalScroll(debugFrame.scrollFrame:GetVerticalScrollRange())
        end)
    end
    
    function addon.DebugSystem.Clear()
        debugLines = {}
        if debugFrame then
            debugFrame.text:SetText("Debug output will appear here...")
        end
    end
end

-- Local convenience function
local function DebugPrint(msg)
    addon.DebugSystem.Print(msg, "CooldownTracker")
end

-- OmniCD's GetSpellLevelLearned implementation
local GetSpellLevelLearned = C_Spell and C_Spell.GetSpellLevelLearned
    or GetSpellLevelLearned
    or function() return 0 end -- Fallback for very old versions


-- Core tracking data structures
CooldownTracker.groupInfo = {}           -- Player information and available spells
CooldownTracker.activeCooldowns = {}     -- Current cooldown states
CooldownTracker.eventListeners = {}      -- Event callback system
CooldownTracker.inspectQueue = {}        -- Queue for inspecting party members
CooldownTracker.isEnabled = false        -- Tracking state

-- Combat log event frame
local CombatLogFrame = CreateFrame("Frame")

-- Inspection system
local InspectFrame = CreateFrame("Frame")
local INSPECT_INTERVAL = 2
local inspectTimer = 0
local currentInspectTarget = nil

-- Event system for decoupled communication
function CooldownTracker:RegisterEventListener(event, callback)
    if not self.eventListeners[event] then
        self.eventListeners[event] = {}
    end
    table.insert(self.eventListeners[event], callback)
end

function CooldownTracker:FireEvent(event, ...)
    if self.eventListeners[event] then
        for _, callback in ipairs(self.eventListeners[event]) do
            callback(...)
        end
    end
end

-- Initialize the cooldown tracker
function CooldownTracker:Initialize()
    if self.isEnabled then
        return
    end
    
    self:LoadCCSpellDatabase()
    self:RegisterEvents()
    self:RegisterLibGroupInSpecTCallbacks()
    self:RefreshGroupMembers()
    
    self.isEnabled = true
    print("CCRotationHelper: CooldownTracker initialized")
end

-- Shutdown the cooldown tracker
function CooldownTracker:Shutdown()
    if not self.isEnabled then
        return
    end
    
    self:UnregisterEvents()
    wipe(self.groupInfo)
    wipe(self.activeCooldowns)
    wipe(self.inspectQueue)
    
    self.isEnabled = false
end

-- Register for necessary WoW events
function CooldownTracker:RegisterEvents()
    -- Combat log for spell cast detection
    CombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Group composition changes
    CombatLogFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    CombatLogFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Talent and equipment changes
    CombatLogFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    CombatLogFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    CombatLogFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    
    -- Set up event handlers
    CombatLogFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            CooldownTracker:COMBAT_LOG_EVENT_UNFILTERED()
        elseif event == "GROUP_ROSTER_UPDATE" then
            CooldownTracker:GROUP_ROSTER_UPDATE()
        elseif event == "PLAYER_ENTERING_WORLD" then
            CooldownTracker:PLAYER_ENTERING_WORLD()
        elseif event == "PLAYER_TALENT_UPDATE" then
            CooldownTracker:PLAYER_TALENT_UPDATE()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            CooldownTracker:PLAYER_SPECIALIZATION_CHANGED()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            CooldownTracker:PLAYER_EQUIPMENT_CHANGED(...)
        end
    end)
    
    -- Inspection system
    InspectFrame:RegisterEvent("INSPECT_READY")
    InspectFrame:SetScript("OnEvent", function(self, event, guid)
        CooldownTracker:INSPECT_READY(guid)
    end)
    
    InspectFrame:SetScript("OnUpdate", function(self, elapsed)
        CooldownTracker:OnInspectUpdate(elapsed)
    end)
end

-- Unregister all events
function CooldownTracker:UnregisterEvents()
    CombatLogFrame:UnregisterAllEvents()
    CombatLogFrame:SetScript("OnEvent", nil)
    
    InspectFrame:UnregisterAllEvents()
    InspectFrame:SetScript("OnEvent", nil)
    InspectFrame:SetScript("OnUpdate", nil)
end

-- Register LibGroupInSpecT callbacks
function CooldownTracker:RegisterLibGroupInSpecTCallbacks()
    LGIST.RegisterCallback(self, "GroupInSpecT_Update", "OnLibGroupInSpecTUpdate")
    LGIST.RegisterCallback(self, "GroupInSpecT_Remove", "OnLibGroupInSpecTRemove")
end

-- Handle LibGroupInSpecT talent/spec updates
function CooldownTracker:OnLibGroupInSpecTUpdate(event, guid, unit, info)
    if not self.isEnabled then return end
    
    local playerInfo = self.groupInfo[guid]
    if not playerInfo then return end
    
    -- Update player info with LibGroupInSpecT data
    if info.class_id then
        playerInfo.class = info.class
    end
    
    if info.global_spec_id then
        playerInfo.spec = info.global_spec_id
    end
    
    -- Convert LibGroupInSpecT talent format to our format
    if info.talents then
        wipe(playerInfo.talentData)
        for talentId, talentInfo in pairs(info.talents) do
            if talentInfo.spell_id then
                playerInfo.talentData[talentInfo.spell_id] = true
            end
        end
    end
    
    -- Force rebuild of available spells since talents changed
    wipe(playerInfo.availableSpells)
    self:BuildAvailableSpells(playerInfo)
    
    addon.DebugSystem.Print("LibGroupInSpecT updated player: " .. (info.name or "Unknown") .. " (" .. guid .. ")", "CooldownTracker")
    
    -- Notify rotation system of changes
    if addon.CCRotation then
        C_Timer.After(0.1, function()
            -- Clear stale spells first, then rebuild queue
            if addon.CCRotation.ClearStaleSpellCooldowns then
                addon.CCRotation:ClearStaleSpellCooldowns()
            end
            if addon.CCRotation.RebuildQueue then
                addon.CCRotation:RebuildQueue()
            end
        end)
    end
end

-- Handle LibGroupInSpecT player removal
function CooldownTracker:OnLibGroupInSpecTRemove(event, guid)
    if not self.isEnabled then return end
    
    -- Clean up our tracking data
    if self.groupInfo[guid] then
        self.groupInfo[guid] = nil
        addon.DebugSystem.Print("LibGroupInSpecT removed player: " .. guid, "CooldownTracker")
    end
    
    -- Clean up cooldowns for this player
    for key, cooldownData in pairs(self.activeCooldowns) do
        if cooldownData.guid == guid then
            self.activeCooldowns[key] = nil
        end
    end
end

-- Helper function to get table keys for debugging
function CooldownTracker:TableKeys(tbl)
    local keys = {}
    for k, v in pairs(tbl) do
        table.insert(keys, tostring(k))
    end
    return table.concat(keys, ", ")
end

-- Helper function to count talents for debugging
function CooldownTracker:CountTalents(talentData)
    local count = 0
    for k, v in pairs(talentData) do
        if v then
            count = count + 1
        end
    end
    return count .. " talents"
end

-- Helper function to count keys in table
function CooldownTracker:CountKeys(tbl)
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Load CC spell database from separate module
function CooldownTracker:LoadCCSpellDatabase()
    -- Reference the spell database - use Database.lua as single source of truth
    self.ccSpellDatabase = addon.Database.defaultSpells
    
    -- Build spellsByClass lookup for compatibility
    self.spellsByClass = {}
    for spellID, spellData in pairs(self.ccSpellDatabase) do
        local class = spellData.class
        if class then
            if not self.spellsByClass[class] then
                self.spellsByClass[class] = {}
            end
            self.spellsByClass[class][spellID] = spellData
        end
    end
    
end

-- Refresh group member information
function CooldownTracker:RefreshGroupMembers()
    local oldGroupInfo = {}
    for guid, info in pairs(self.groupInfo) do
        oldGroupInfo[guid] = info
        if info.availableSpells then
        end
    end
    
    wipe(self.groupInfo)
    
    -- Add player
    local playerGUID = UnitGUID("player")
    if playerGUID then
        self:AddGroupMember("player", playerGUID)
    end
    
    -- Add party/raid members (only if we're in a group)
    if IsInGroup() then
        local groupType = IsInRaid() and "raid" or "party"
        local maxMembers = IsInRaid() and 40 or 4
        
        for i = 1, maxMembers do
            local unit = groupType .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    self:AddGroupMember(unit, guid)
                end
            end
        end
    end
    
    -- Queue inspection for new members, but preserve existing inspection data
    for guid, info in pairs(self.groupInfo) do
        if not oldGroupInfo[guid] then
            -- Try to get cached data from LibGroupInSpecT first
            local cachedInfo = LGIST:GetCachedInfo(guid)
            if cachedInfo then
                self:OnLibGroupInSpecTUpdate("GroupInSpecT_Update", guid, info.unit, cachedInfo)
            else
                self:QueueInspection(guid, info.unit)
            end
        else
            -- Preserve inspection data from previous version
            local oldInfo = oldGroupInfo[guid]
            if oldInfo.availableSpells and self:CountKeys(oldInfo.availableSpells) > 0 then
                info.availableSpells = oldInfo.availableSpells
                info.spec = oldInfo.spec
                info.talentData = oldInfo.talentData
                info.itemData = oldInfo.itemData
                info.lastInspected = oldInfo.lastInspected
            end
        end
    end
    
    -- Clean up cooldowns for members who left
    self:CleanupStaleData(oldGroupInfo)
    
    -- Fire group update event
    self:FireEvent("GROUP_UPDATED")
end

-- Add a group member to tracking
function CooldownTracker:AddGroupMember(unit, guid)
    local name = UnitName(unit)
    local class, classFilename = UnitClass(unit)
    local level = UnitLevel(unit)

    self.groupInfo[guid] = {
        guid = guid,
        unit = unit,
        name = name,
        class = classFilename,   -- Use classFilename (token) not localized name
        level = level,
        spec = nil,              -- Will be filled by inspection
        talentData = {},         -- Talent information
        itemData = {},           -- Equipment information
        availableSpells = {},    -- CC spells this player can use
        lastInspected = 0        -- Timestamp of last inspection
    }
end

-- Queue a player for inspection
function CooldownTracker:QueueInspection(guid, unit)
    -- Don't inspect ourselves - we can get our data directly
    if guid == UnitGUID("player") then
        self:InspectPlayer()
        return
    end
    
    -- Add to inspection queue if not already queued
    for _, queuedGuid in ipairs(self.inspectQueue) do
        if queuedGuid == guid then
            return -- Already queued
        end
    end
    
    table.insert(self.inspectQueue, guid)
end

-- Inspect update handler
function CooldownTracker:OnInspectUpdate(elapsed)
    inspectTimer = inspectTimer + elapsed
    
    if inspectTimer >= INSPECT_INTERVAL then
        inspectTimer = 0
        self:ProcessInspectQueue()
    end
end

-- Process the inspection queue
function CooldownTracker:ProcessInspectQueue()
    if #self.inspectQueue == 0 then
        return
    end
    
    -- Clear any pending inspection
    if currentInspectTarget then
        ClearInspectPlayer()
        currentInspectTarget = nil
    end
    
    -- Get next player to inspect
    local guid = table.remove(self.inspectQueue, 1)
    local info = self.groupInfo[guid]
    
    if not info then
        return -- Player no longer in group
    end

    -- Check if we can inspect this unit
    if not UnitIsConnected(info.unit) or not CanInspect(info.unit) then
        -- Fallback: assume basic class spells without inspection
        self:BuildBasicSpellsForPlayer(info)
        return
    end
    
    -- Start inspection
    currentInspectTarget = guid
    NotifyInspect(info.unit)
end

-- Handle INSPECT_READY event
function CooldownTracker:INSPECT_READY(guid)
    if guid ~= currentInspectTarget then
        return
    end
    
    local info = self.groupInfo[guid]
    if not info then
        return
    end

    -- Get specialization
    local specIndex = GetInspectSpecialization and GetInspectSpecialization(info.unit)
    if specIndex and specIndex > 0 then
        local specID, specName = GetSpecializationInfo(specIndex)
        info.spec = specID

        -- Get talent data
        info.talentData = self:GetInspectTalentData(info.unit)

        -- Get equipment data
        info.itemData = self:GetInspectEquipmentData(info.unit)
        
        -- Build available spells for this player
        self:BuildAvailableSpells(info)
        
        info.lastInspected = GetTime()
        
        -- Fire inspection complete event
        self:FireEvent("PLAYER_INSPECTED", guid, info)
    else
        -- Fallback to basic spells if inspection failed
        self:BuildBasicSpellsForPlayer(info)
    end
    
    -- Clear inspection target
    ClearInspectPlayer()
    currentInspectTarget = nil
end

-- Inspect our own player (no inspection needed)
function CooldownTracker:InspectPlayer()
    local playerGUID = UnitGUID("player")
    local info = self.groupInfo[playerGUID]
    
    if not info then
        return
    end
    
    -- Get our own spec
    local specIndex = GetSpecialization()
    if specIndex and specIndex > 0 then
        local specID = GetSpecializationInfo(specIndex)
        info.spec = specID
        
        -- Get our own talent data
        info.talentData = self:GetPlayerTalentData()

        -- Get our own equipment
        info.itemData = self:GetPlayerEquipmentData()
        
        -- Build our available spells
        self:BuildAvailableSpells(info)
        
        info.lastInspected = GetTime()
        
        -- Fire inspection complete event
        self:FireEvent("PLAYER_INSPECTED", playerGUID, info)
    else
        -- Still try to build basic spells without spec requirement
        self:BuildBasicSpellsForPlayer(info)
        self:FireEvent("PLAYER_INSPECTED", playerGUID, info)
    end
end

-- Get talent data for inspection (using OmniCD's approach)
function CooldownTracker:GetInspectTalentData(unit)
    local talents = {}
    
    -- Use OmniCD's method: GetTalentInfo with isInspect=true
    local MAX_TALENT_TIERS = 7
    local NUM_TALENT_COLUMNS = 3
    local specGroupIndex = 1
    local isInspect = true
    
    for tier = 1, MAX_TALENT_TIERS do
        for column = 1, NUM_TALENT_COLUMNS do
            local _,_,_, selected, _, spellID = GetTalentInfo(tier, column, specGroupIndex, isInspect, unit)
            if selected and spellID then
                talents[spellID] = true
                break
            end
        end
    end
    
    return talents
end

-- Get equipment data for inspection (simplified)
function CooldownTracker:GetInspectEquipmentData(unit)
    local equipment = {}
    
    -- Check for relevant trinkets and gear (simplified)
    for slot = 1, 19 do
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            local itemID = GetItemInfoFromHyperlink(itemLink)
            if itemID then
                equipment[itemID] = true
            end
        end
    end
    
    return equipment
end

-- Get our own talent data (using OmniCD's approach)
function CooldownTracker:GetPlayerTalentData()
    local talents = {}
    
    -- Use OmniCD's method: GetTalentInfo but for our own player (no isInspect needed)
    local MAX_TALENT_TIERS = 7
    local NUM_TALENT_COLUMNS = 3
    local specGroupIndex = 1
    
    for tier = 1, MAX_TALENT_TIERS do
        for column = 1, NUM_TALENT_COLUMNS do
            local _,_,_, selected, _, spellID = GetTalentInfo(tier, column, specGroupIndex)
            if selected and spellID then
                talents[spellID] = true
                break
            end
        end
    end
    
    return talents
end

-- Get our own equipment data
function CooldownTracker:GetPlayerEquipmentData()
    local equipment = {}
    
    -- Check our equipped items
    for slot = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local itemID = GetItemInfoFromHyperlink(itemLink)
            if itemID then
                equipment[itemID] = true
            end
        end
    end
    
    return equipment
end

-- Build basic spell list for players we can't inspect properly
function CooldownTracker:BuildBasicSpellsForPlayer(playerInfo)
    
    -- Don't overwrite if we already have spells from full inspection
    local currentCount = self:CountKeys(playerInfo.availableSpells)
    if currentCount > 0 then
        return
    end
    
    wipe(playerInfo.availableSpells)

    local classSpells = self.spellsByClass[playerInfo.class]
    if not classSpells then
        return
    end

    -- Add basic class spells without spec/talent requirements
    local basicSpellsCount = 0
    for spellID, spellData in pairs(classSpells) do
        -- Only include spells that don't require specific spec or talents
        if not spellData.spec and not spellData.talent then
            basicSpellsCount = basicSpellsCount + 1
            -- Assume they have the spell if they're high enough level
            if playerInfo.level >= 10 then -- Basic assumption for max level players
                playerInfo.availableSpells[spellID] = {
                    spellID = spellID,
                    name = spellData.name,
                    baseCooldown = spellData.baseCooldown,
                    actualCooldown = spellData.baseCooldown, -- No talent/gear modifiers
                    ccType = spellData.ccType,
                    charges = spellData.charges or 1,
                    priority = spellData.priority or 5
                }
            end
        end
    end
    
end

-- Build list of available CC spells for a player
function CooldownTracker:BuildAvailableSpells(playerInfo)
    
    -- If we already have spells, don't rebuild unless forced
    local currentSpellCount = self:CountKeys(playerInfo.availableSpells)
    if currentSpellCount > 0 then
        return
    else
    end
    
    wipe(playerInfo.availableSpells)

    local classSpells = self.spellsByClass[playerInfo.class]
    if not classSpells then
        return
    end


    for spellID, spellData in pairs(classSpells) do
        local isAvailable = false

        -- Check spec requirement
        if spellData.spec then
            if playerInfo.spec ~= spellData.spec then
                print("CCRotationHelper: SKIP", spellData.name, "- wrong spec")
            else
                -- Check talent requirement
                if spellData.talent then
                    if not playerInfo.talentData[spellData.talent] then
                        print("CCRotationHelper CooldownTracker: Skipping", spellData.name, "- talent", spellData.talent, "not found for", playerInfo.name)
                    else
                        print("CCRotationHelper CooldownTracker: Talent", spellData.talent, "found for", spellData.name, "on", playerInfo.name)
                        -- Continue with spell availability check
                        isAvailable = self:CheckSpellAvailability(playerInfo, spellID, spellData)
                    end
                else
                    -- No talent requirement, continue with spell availability check
                    isAvailable = self:CheckSpellAvailability(playerInfo, spellID, spellData)
                end
            end
        else
            -- No spec requirement, check talent requirement
            if spellData.talent then
                if not playerInfo.talentData[spellData.talent] then
                    print("CCRotationHelper: SKIP", spellData.name, "- talent", spellData.talent, "not found")
                else
                    print("CCRotationHelper: TALENT OK", spellData.name)
                    isAvailable = self:CheckSpellAvailability(playerInfo, spellID, spellData)
                end
            else
                isAvailable = self:CheckSpellAvailability(playerInfo, spellID, spellData)
            end
        end
        
        -- Process available spells
        if isAvailable then
            local actualCooldown = self:CalculateActualCooldown(playerInfo, spellID, spellData.baseCooldown)
            local actualCharges = spellData.charges or 1
            local displayName = spellData.name
            local actualBaseCooldown = spellData.baseCooldown
            
            
            playerInfo.availableSpells[spellID] = {
                spellID = spellID,
                name = displayName,
                baseCooldown = actualBaseCooldown,
                actualCooldown = actualCooldown,
                ccType = spellData.ccType,
                charges = actualCharges,
                priority = spellData.priority or 5
            }
        end
    end
    
end

-- Check if a spell is available for a player
function CooldownTracker:CheckSpellAvailability(playerInfo, spellID, spellData)
    -- For inspecting other players, we can't use IsSpellKnown reliably
    -- Instead, we'll assume they have class spells and check other requirements
    if playerInfo.guid == UnitGUID("player") then
        -- For our own player, we can check spell knowledge
        if IsSpellKnown(spellID, false) or IsSpellKnown(spellID, true) then
            local spellLevel = GetSpellLevelLearned(spellID)
            if playerInfo.level >= spellLevel then
                return true
            end
        end
    else
        -- For other players, assume they have class spells if they meet level requirement
        local spellLevel = GetSpellLevelLearned(spellID)
        if spellLevel and playerInfo.level >= spellLevel then
            return true
        end
    end
    
    return false
end

-- Calculate actual cooldown with talent/gear modifiers
function CooldownTracker:CalculateActualCooldown(playerInfo, spellID, baseCooldown)
    -- For now, just return base cooldown - talent/gear modifiers can be added later
    return baseCooldown
end

-- Clean up data for players who left the group
function CooldownTracker:CleanupStaleData(oldGroupInfo)
    -- Remove cooldowns for players no longer in group
    for key, cooldownData in pairs(self.activeCooldowns) do
        if not self.groupInfo[cooldownData.guid] then
            self.activeCooldowns[key] = nil
        end
    end
    
    -- Remove from inspect queue
    for i = #self.inspectQueue, 1, -1 do
        local guid = self.inspectQueue[i]
        if not self.groupInfo[guid] then
            table.remove(self.inspectQueue, i)
        end
    end
end

-- Event handlers
function CooldownTracker:GROUP_ROSTER_UPDATE()
    self:RefreshGroupMembers()
end

function CooldownTracker:PLAYER_ENTERING_WORLD()
    self:RefreshGroupMembers()
end

function CooldownTracker:PLAYER_TALENT_UPDATE()
    -- Force rebuild of available spells by clearing them first
    local playerInfo = self.groupInfo[UnitGUID("player")]
    if playerInfo then
        wipe(playerInfo.availableSpells)
    end
    
    -- Re-inspect ourselves
    C_Timer.After(0.5, function()
        self:InspectPlayer()
    end)
end

function CooldownTracker:PLAYER_SPECIALIZATION_CHANGED()
    -- Re-inspect ourselves
    C_Timer.After(0.5, function()
        self:InspectPlayer()
    end)
end

function CooldownTracker:PLAYER_EQUIPMENT_CHANGED(slot)
    -- Re-inspect ourselves
    C_Timer.After(0.5, function()
        self:InspectPlayer()
    end)
end

-- Combat log event processing (next step)
function CooldownTracker:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, event, _, srcGUID, _, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    
    -- Quick debug - print any spell cast success events
    if event == "SPELL_CAST_SUCCESS" then
        DebugPrint("SPELL_CAST_SUCCESS detected - spell " .. tostring(spellID))
        -- Special debug for Typhoon
        if spellID == 61391 or spellID == 132469 then
            DebugPrint("*** TYPHOON DETECTED in combat log! (ID: " .. spellID .. ") ***")
        end
    end
    
    -- Only process relevant events and group members
    if event ~= "SPELL_CAST_SUCCESS" then
        return
    end
    
    -- Only process events from tracked players
    local playerInfo = self.groupInfo[srcGUID]
    if not playerInfo then
        DebugPrint("Player not found in groupInfo for GUID: " .. tostring(srcGUID))
        return
    end
    DebugPrint("Found player: " .. playerInfo.name)
    
    -- Use generic spell ID resolution system
    local spellData, mappedSpellID, castSpellCooldown = addon.Database:GetSpellData(spellID)
    if not spellData then
        DebugPrint("Spell " .. tostring(spellID) .. " not found in database (mapped to " .. tostring(mappedSpellID) .. ")")
        return
    end
    
    -- Check if the spell is in our tracking database
    if not self.ccSpellDatabase[mappedSpellID] then
        DebugPrint("Mapped spell " .. tostring(mappedSpellID) .. " not found in ccSpellDatabase")
        return
    end
    
    if spellID ~= mappedSpellID then
        DebugPrint("Mapped cast spell " .. spellID .. " to base spell " .. mappedSpellID .. " (" .. spellData.name .. ")")
    else
        DebugPrint("Found spell data: " .. spellData.name)
    end
    
    -- Check if this player actually has this spell available
    local availableSpell = playerInfo.availableSpells[mappedSpellID]
    if not availableSpell then
        DebugPrint("Spell " .. tostring(mappedSpellID) .. " not in player's availableSpells")
        return
    else
        DebugPrint("Player has spell available")
    end
    
    -- Record the cooldown using the base spell ID (resolved from generic mapping system)
    local baseSpellID = mappedSpellID
    
    local cooldownKey = baseSpellID .. ":" .. srcGUID
    -- Use GetTime() instead of combat log timestamp for consistency with WoW APIs
    local currentTime = GetTime()
    
    -- Use the cast spell's cooldown (e.g., Gravity Lapse = 40s instead of Supernova = 45s)
    local actualDuration = castSpellCooldown or availableSpell.actualCooldown
    local expirationTime = currentTime + actualDuration
    
    DebugPrint("Recording cooldown with baseSpellID " .. baseSpellID .. " (original: " .. spellID .. ")")
    
    self.activeCooldowns[cooldownKey] = {
        spellID = baseSpellID,  -- Use base spell ID for consistency
        guid = srcGUID,
        playerName = playerInfo.name,
        expirationTime = expirationTime,
        duration = actualDuration,
        ccType = spellData.ccType,
        timestamp = currentTime
    }
    
    -- Fire cooldown update event using base spell ID
    local cooldownSource = (castSpellCooldown and castSpellCooldown ~= availableSpell.actualCooldown) 
        and ("cast spell: " .. castSpellCooldown) or ("available: " .. availableSpell.actualCooldown)
    DebugPrint("Recording cooldown for " .. spellData.name .. " duration " .. tostring(actualDuration) .. " (" .. cooldownSource .. ")")
    self:FireEvent("COOLDOWN_STARTED", baseSpellID, srcGUID, expirationTime, actualDuration)
end

-- Get all current cooldowns (LibOpenRaid replacement)
function CooldownTracker:GetAllCooldowns()
    
    local result = {}
    local currentTime = GetTime()
    
    for guid, playerInfo in pairs(self.groupInfo) do
        result[guid] = {}
        
        
        -- Include all available spells for this player
        for spellID, spellInfo in pairs(playerInfo.availableSpells) do
            -- Check if this spell is currently on cooldown
            local cooldownData = nil
            addon.DebugSystem.Print("Looking for cooldown: spellID=" .. spellID .. " guid=" .. guid, "CooldownTracker")
            for key, cd in pairs(self.activeCooldowns) do
                addon.DebugSystem.Print("  Checking activeCooldown: key=" .. key .. " cd.spellID=" .. cd.spellID .. " cd.guid=" .. cd.guid, "CooldownTracker")
                if cd.guid == guid and cd.spellID == spellID then
                    local remaining = cd.expirationTime - currentTime
                    if remaining > 0 then
                        cooldownData = cd
                    else
                        -- Cooldown expired, remove it
                        self.activeCooldowns[key] = nil
                    end
                    break
                end
            end
            
            if cooldownData then
                -- Spell is on cooldown
                result[guid][spellID] = {
                    expirationTime = cooldownData.expirationTime,
                    duration = cooldownData.duration,
                    remaining = cooldownData.expirationTime - currentTime,
                    charges = cooldownData.charges or 1,
                    ccType = cooldownData.ccType
                }
            else
                -- Spell is ready (not on cooldown)
                result[guid][spellID] = {
                    expirationTime = currentTime, -- Ready now
                    duration = spellInfo.actualCooldown,
                    remaining = 0, -- No time remaining
                    charges = spellInfo.charges or 1,
                    ccType = spellInfo.ccType
                }
            end
        end
    end
    
    return result
end

-- Get available spells for a specific player
function CooldownTracker:GetPlayerSpells(guid)
    local playerInfo = self.groupInfo[guid]
    if not playerInfo then
        return {}
    end
    
    return playerInfo.availableSpells
end

-- Check if a player is in our group
function CooldownTracker:IsPlayerInGroup(guid)
    return self.groupInfo[guid] ~= nil
end

-- Get player information
function CooldownTracker:GetPlayerInfo(guid)
    return self.groupInfo[guid]
end

-- GetCooldownStatusFromCooldownInfo - LibOpenRaid API compatibility
function CooldownTracker:GetCooldownStatusFromCooldownInfo(cooldownInfo)
    if not cooldownInfo then
        return false, 0, 0, 0, 0, 0, 0, 0
    end
    
    local currentTime = GetTime()
    local timeLeft = math.max(0, cooldownInfo.expirationTime - currentTime)
    local isReady = timeLeft <= 0
    local charges = cooldownInfo.charges or 1
    local duration = cooldownInfo.duration or 0
    
    -- Calculate normalized percent (0 = ready, 1 = just cast)
    local normalizedPercent = 0
    if duration > 0 and timeLeft > 0 then
        normalizedPercent = 1 - (timeLeft / duration)
    end
    
    -- Time values for progress bars (LibOpenRaid format)
    local minValue = cooldownInfo.expirationTime - duration  -- startTime
    local maxValue = cooldownInfo.expirationTime            -- expirationTime
    local currentValue = currentTime                         -- GetTime()
    
    -- Return: isReady, normalizedPercent, timeLeft, charges, minValue, maxValue, currentValue, duration
    return isReady, normalizedPercent, timeLeft, charges, minValue, maxValue, currentValue, duration
end