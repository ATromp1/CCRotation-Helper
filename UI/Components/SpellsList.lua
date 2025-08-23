local addonName, addon = ...

-- Ensure Components namespace exists
if not addon.Components then
    addon.Components = {}
end

local BaseComponent = addon.BaseComponent
-- AceGUI is available via BaseComponent.AceGUI (inherited)

-- Local helper functions for spell components
local function createCCTypeDropdown(AceGUI, width, defaultValue, callback)
    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel("CC Type")
    dropdown:SetWidth(width or 150)
    
    -- Use database CC type data
    local ccTypeList = {}
    for _, ccType in ipairs(addon.Database.ccTypeOrder) do
        ccTypeList[ccType] = addon.Database.ccTypeDisplayNames[ccType]
    end
    dropdown:SetList(ccTypeList)
    
    if defaultValue then
        dropdown:SetValue(defaultValue)
    end
    
    if callback then
        dropdown:SetCallback("OnValueChanged", callback)
    end
    
    return dropdown
end

local function createSpellIcon(AceGUI, spellID, size)
    local icon = AceGUI:Create("Icon")
    icon:SetWidth(size or 32)
    icon:SetHeight(size or 32)
    icon:SetImageSize(size or 32, size or 32)
    
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo and spellInfo.iconID then
        icon:SetImage(spellInfo.iconID)
    else
        icon:SetImage("Interface\\\\Icons\\\\INV_Misc_QuestionMark")
    end
    
    return icon
end

-- AddSpellForm Component
local AddSpellForm = {}
setmetatable(AddSpellForm, {__index = BaseComponent})

-- Cleanup method for AddSpellForm
function AddSpellForm:Cleanup()
    -- Clean up container
    if self.container then
        self.container:ReleaseChildren()
    end
end


function AddSpellForm:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("AddSpellForm")
    return instance
end

function AddSpellForm:buildUI()
    -- Check if editing is disabled due to party sync
    local isEditingDisabled = addon.UI and addon.UI:IsEditingDisabledByPartySync()
    
    -- Spell ID input
    local spellIDEdit = self.AceGUI:Create("EditBox")
    spellIDEdit:SetLabel(isEditingDisabled and "Spell ID (Read-only - Party Sync Active)" or "Spell ID")
    spellIDEdit:SetWidth(150)
    spellIDEdit:SetDisabled(isEditingDisabled)
    self.container:AddChild(spellIDEdit)
    
    -- Spell name input
    local spellNameEdit = self.AceGUI:Create("EditBox")
    spellNameEdit:SetLabel(isEditingDisabled and "Spell Name (Read-only - Party Sync Active)" or "Spell Name")
    spellNameEdit:SetWidth(200)
    spellNameEdit:SetDisabled(isEditingDisabled)
    self.container:AddChild(spellNameEdit)
    
    -- CC Type dropdown using local helper
    local ccTypeDropdown = createCCTypeDropdown(self.AceGUI, 150, "stun")
    ccTypeDropdown:SetDisabled(isEditingDisabled)
    self.container:AddChild(ccTypeDropdown)
    
    -- Priority input
    local priorityEdit = self.AceGUI:Create("EditBox")
    priorityEdit:SetLabel("Priority (1-50)")
    priorityEdit:SetWidth(100)
    priorityEdit:SetText("25")
    priorityEdit:SetDisabled(isEditingDisabled)
    self.container:AddChild(priorityEdit)
    
    -- Add button
    local addButton = self.AceGUI:Create("Button")
    addButton:SetText(isEditingDisabled and "Add Spell (Disabled)" or "Add Spell")
    addButton:SetWidth(100)
    addButton:SetDisabled(isEditingDisabled)
    addButton:SetCallback("OnClick", function()
        local spellID = tonumber(spellIDEdit:GetText())
        local spellName = spellNameEdit:GetText():trim()
        local ccType = ccTypeDropdown:GetValue()
        local priority = tonumber(priorityEdit:GetText()) or 25
        
        if spellID and spellName ~= "" and ccType and priority then
            -- Use data provider for spell operations
            if self.dataProvider then
                self.dataProvider.spells:addCustomSpell(spellID, spellName, ccType, priority)
            else
                -- Fallback to direct access if no data provider
                addon.Config.db.spells[spellID] = {
                    name = spellName,
                    ccType = ccType,
                    priority = priority,
                    active = true,
                    source = "custom"
                }
            end
            
            -- Clear inputs
            spellIDEdit:SetText("")
            spellNameEdit:SetText("")
            priorityEdit:SetText("25")
            
            -- Trigger callback to parent
            self:triggerCallback('onSpellAdded', spellID)
        end
    end)
    self.container:AddChild(addButton)
end

-- Helper function to apply disabled styling to text and UI elements
local function applyDisabledStyling(widget, text, isDisabled)
    if isDisabled then
        if widget.SetText then
            widget:SetText("|cff888888" .. (text or "") .. "|r")
        end
        return "|cff888888" .. (text or "") .. "|r"
    else
        if widget.SetText then
            widget:SetText(text or "")
        end
        return text or ""
    end
end

-- Helper function to clean color codes from text
local function cleanColorCodes(text)
    if not text then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end


-- QueueDisplay Component
local QueueDisplayComponent = {}
setmetatable(QueueDisplayComponent, {__index = BaseComponent})

function QueueDisplayComponent:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("QueueDisplayComponent")
    
    -- Initialize filter state - using string names that match ccTypeLookup
    instance.ccTypeFilters = {
        ["stun"] = true,
        ["disorient"] = true,
        ["fear"] = true,
        ["knock"] = true,
        ["incapacitate"] = true
    }
    
    return instance
end

function QueueDisplayComponent:buildUI()
    -- CC Type filter section
    local filterGroup = self.AceGUI:Create("InlineGroup")
    filterGroup:SetTitle("Queue Filters")
    filterGroup:SetFullWidth(true)
    filterGroup:SetLayout("Flow")
    self.container:AddChild(filterGroup)
    
    -- Use database CC type data instead of hardcoded values
    local ccTypeOrder = addon.Database.ccTypeOrder or {"stun", "disorient", "fear", "knock", "incapacitate"}
    local ccTypeDisplayNames = addon.Database.ccTypeDisplayNames or {
        ["stun"] = "Stun",
        ["disorient"] = "Disorient", 
        ["fear"] = "Fear",
        ["knock"] = "Knock",
        ["incapacitate"] = "Incapacitate"
    }
    
    -- Create filter buttons
    for _, ccType in ipairs(ccTypeOrder) do
        local filterButton = self.AceGUI:Create("Button")
        local displayName = ccTypeDisplayNames[ccType]
        filterButton:SetText(displayName)
        filterButton:SetWidth(100)
        
        -- Store the ccType and displayName on the button widget for the callback
        filterButton.ccType = ccType
        filterButton.displayName = displayName
        
        filterButton:SetCallback("OnClick", function(widget, event)
            local buttonCcType = widget.ccType
            local buttonDisplayName = widget.displayName
            
            -- Toggle filter state
            self.ccTypeFilters[buttonCcType] = not self.ccTypeFilters[buttonCcType]
            
            -- Update button appearance
            if self.ccTypeFilters[buttonCcType] then
                widget:SetText(buttonDisplayName)
            else
                widget:SetText("|cff888888" .. buttonDisplayName .. "|r")
            end
            
            -- Rebuild the actual rotation queue first
            if addon.CCRotation and addon.CCRotation.RebuildQueue then
                addon.CCRotation:RebuildQueue()
            end
            
            -- Refresh the queue display
            self:refreshQueueDisplay()
        end)
        
        filterGroup:AddChild(filterButton)
    end
    
    -- Queue display section
    self.queueGroup = self.AceGUI:Create("InlineGroup")
    self.queueGroup:SetTitle("Current Rotation Queue")
    self.queueGroup:SetFullWidth(true)
    self.queueGroup:SetLayout("Flow")
    self.container:AddChild(self.queueGroup)
    
    -- Initial queue display
    self:refreshQueueDisplay()
end

function QueueDisplayComponent:refreshQueueDisplay()
    if not self.queueGroup then
        return
    end
    
    self.queueGroup:ReleaseChildren()
    
    if not addon.CCRotation then
        local noRotationText = self.AceGUI:Create("Label")
        noRotationText:SetText("Rotation system not initialized.")
        noRotationText:SetFullWidth(true)
        self.queueGroup:AddChild(noRotationText)
        return
    end
    
    -- Get the actual queue from CCRotation (same as what's displayed in-game)
    local fullQueue = {}
    
    if addon.CCRotation then
        -- Use the actual queue that CCRotation has already built with all filtering applied
        local actualQueue = addon.CCRotation.cooldownQueue or {}
        local unavailableQueue = addon.CCRotation.unavailableQueue or {}
        
        -- Debug: Show raw queue data
        if addon.Config:Get("debugMode") then
            print("SpellsList Debug - actualQueue size: " .. #actualQueue)
            print("SpellsList Debug - unavailableQueue size: " .. #unavailableQueue)
        end
        
        -- Combine both queues but mark unavailable ones
        for _, spellData in ipairs(actualQueue) do
            -- Apply CC type filter to preview
            local spellInfo = addon.Database.defaultSpells[spellData.spellID]
            local ccType = spellInfo and spellInfo.ccType
            local ccTypeString = ccType -- ccType is already a string in the database
            
            -- Debug: Show CC type conversion
            if addon.Config:Get("debugMode") then
                print("SpellsList Debug - Spell " .. spellData.spellID .. " (" .. (spellInfo and spellInfo.name or "Unknown") .. "): ccType=" .. tostring(ccType))
            end
            
            if not ccType or self.ccTypeFilters[ccTypeString] then
                table.insert(fullQueue, {
                    GUID = spellData.GUID,
                    unit = addon.CCRotation.GUIDToUnit[spellData.GUID],
                    spellID = spellData.spellID,
                    priority = spellData.priority or (spellInfo and spellInfo.priority) or 5,
                    expirationTime = spellData.expirationTime,
                    duration = spellData.duration,
                    charges = spellData.charges or 1,
                    ccType = ccTypeString,
                    isAvailable = true
                })
            end
        end
        
        -- Add unavailable spells if configured to show them
        for _, spellData in ipairs(unavailableQueue) do
            local spellInfo = addon.Database.defaultSpells[spellData.spellID]
            local ccType = spellInfo and spellInfo.ccType
            local ccTypeString = ccType -- ccType is already a string in the database
            
            if not ccType or self.ccTypeFilters[ccTypeString] then
                table.insert(fullQueue, {
                    GUID = spellData.GUID,
                    unit = addon.CCRotation.GUIDToUnit[spellData.GUID],
                    spellID = spellData.spellID,
                    priority = spellData.priority or (spellInfo and spellInfo.priority) or 5,
                    expirationTime = spellData.expirationTime,
                    duration = spellData.duration,
                    charges = spellData.charges or 1,
                    ccType = ccTypeString,
                    isAvailable = false
                })
            end
        end
    end
    
    -- Debug: Show final queue
    if addon.Config:Get("debugMode") then
        print("SpellsList Debug - Final queue size: " .. #fullQueue)
        for i, entry in ipairs(fullQueue) do
            print("SpellsList Debug - Entry " .. i .. ": " .. entry.spellID .. " (" .. tostring(entry.ccType) .. ") - " .. (entry.isAvailable and "Available" or "Unavailable"))
        end
    end
    
    -- Sort queue by priority and availability
    table.sort(fullQueue, function(a, b)
        local aReady = (a.expirationTime <= GetTime())
        local bReady = (b.expirationTime <= GetTime())
        
        if aReady and not bReady then
            return true
        elseif not aReady and bReady then
            return false
        else
            return a.priority < b.priority
        end
    end)
    
    if #fullQueue == 0 then
        local noQueueText = self.AceGUI:Create("Label")
        noQueueText:SetText("No spells in rotation queue.")
        noQueueText:SetFullWidth(true)
        self.queueGroup:AddChild(noQueueText)
    else
        -- Create a horizontal container for the spell icons
        local iconRow = self.AceGUI:Create("SimpleGroup")
        iconRow:SetFullWidth(true)
        iconRow:SetLayout("Flow")
        self.queueGroup:AddChild(iconRow)
        
        -- Display spell icons in a row
        for i, entry in ipairs(fullQueue) do
            local spellIcon = self.AceGUI:Create("Icon")
            spellIcon:SetWidth(32)
            spellIcon:SetHeight(32)
            spellIcon:SetImageSize(32, 32)
            
            -- Get spell icon from WoW API
            local spellInfo = C_Spell.GetSpellInfo(entry.spellID)
            if spellInfo and spellInfo.iconID then
                spellIcon:SetImage(spellInfo.iconID)
            else
                spellIcon:SetImage("Interface\\\\Icons\\\\INV_Misc_QuestionMark")
            end
            
            -- Show availability status
            local playerInfo = addon.CooldownTracker.groupInfo[entry.GUID]
            local playerName = playerInfo and playerInfo.name or "Unknown"
            local currentTime = GetTime()
            local remaining = math.max(0, entry.expirationTime - currentTime)
            local statusText = entry.isAvailable and "Available" or "Unavailable"
            
            -- Set tooltip with spell info
            local tooltipText = string.format("%s\\n%s\\nPlayer: %s\\nCooldown: %.1fs\\nStatus: %s", 
                spellInfo and spellInfo.name or ("Spell " .. entry.spellID),
                entry.ccType or "unknown",
                playerName,
                remaining,
                statusText
            )
            -- Don't set label as text - just use for tooltip
            spellIcon:SetCallback("OnEnter", function(widget)
                GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
                GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            spellIcon:SetCallback("OnLeave", function(widget)
                GameTooltip:Hide()
            end)
            
            -- Dim unavailable spells
            if not entry.isAvailable then
                spellIcon:SetImageSize(24, 24) -- Make smaller
                -- TODO: Could add desaturation if AceGUI supports it
            end
            
            iconRow:AddChild(spellIcon)
        end
    end
end

-- Cleanup method for QueueDisplayComponent
function QueueDisplayComponent:Cleanup()
    -- Clean up container
    if self.container then
        self.container:ReleaseChildren()
    end
    
    -- Clean up queue group
    if self.queueGroup then
        self.queueGroup:ReleaseChildren()
        self.queueGroup = nil
    end
end

-- UnifiedSpellsList Component - Consolidates enabled and disabled spells into a single list
local UnifiedSpellsList = {}
setmetatable(UnifiedSpellsList, {__index = BaseComponent})

function UnifiedSpellsList:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("UnifiedSpellsList")
    
    -- Initialize event listeners
    instance:Initialize()
    
    return instance
end

function UnifiedSpellsList:Initialize()
    -- Register for profile sync events to refresh UI when sync data arrives
    self:RegisterEventListener("PROFILE_SYNC_RECEIVED", function(profileData)
        if addon.UI and addon.UI:IsConfigTabActive("spells") then
            self:refreshUI()
        end
    end)
    
    -- Register for direct profile data changes (from current profile updates)
    self:RegisterEventListener("PROFILE_DATA_CHANGED", function(dataType, value)
        if addon.UI and addon.UI:IsConfigTabActive("spells") and 
           (dataType == "spells" or dataType == "customSpells" or dataType == "inactiveSpells") then
            self:refreshUI()
        end
    end)
    
    -- Register for WoW group events since we're using simple sync now
    local AceEvent = LibStub("AceEvent-3.0")
    AceEvent:Embed(self)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupChanged")
    self:RegisterEvent("PARTY_LEADER_CHANGED", "OnGroupChanged")
end

function UnifiedSpellsList:OnGroupChanged()
    -- Delay UI operations to avoid taint issues with Blizzard frames
    C_Timer.After(0.1, function()
        -- Only refresh UI if the spells tab is currently active
        if addon.UI and addon.UI:IsConfigTabActive("spells") then
            self:refreshUI()
        end
    end)
end

-- Cleanup method for UnifiedSpellsList
function UnifiedSpellsList:Cleanup()
    -- Cancel any pending refresh
    self.isRefreshing = false
    
    -- Unregister events
    if self.UnregisterAllEvents then
        self:UnregisterAllEvents()
    end
    
    -- Clean up container
    if self.container then
        self.container:ReleaseChildren()
    end
end

function UnifiedSpellsList:refreshUI()
    -- Only refresh if the spells tab is currently active
    if not (addon.UI and addon.UI:IsConfigTabActive("spells")) then
        return
    end
    
    -- Prevent multiple concurrent refreshes
    if self.isRefreshing then return end
    self.isRefreshing = true
    
    -- Delay refresh slightly to avoid race conditions with other components
    C_Timer.After(0.1, function()
        if self.container and addon.UI and addon.UI:IsConfigTabActive("spells") then
            -- Use scroll preservation if container supports it and ScrollHelper is available
            if self.container.SetScroll and addon.ScrollHelper then
                addon.ScrollHelper:refreshWithScrollPreservation(self.container, function()
                    self.container:ReleaseChildren()
                    self:buildUI()
                end)
            else
                -- Fallback to normal refresh
                self.container:ReleaseChildren()
                self:buildUI()
            end
        end
        self.isRefreshing = false
    end)
end

function UnifiedSpellsList:buildUI()
    -- Check if editing is disabled due to party sync
    local isEditingDisabled = addon.UI and addon.UI:IsEditingDisabledByPartySync()
    
    -- Get all spells (both active and disabled) from data provider
    local allSpells = {}
    local activeSpells = self.dataProvider and self.dataProvider.spells:getActiveSpells() or {}
    local disabledSpells = self.dataProvider and self.dataProvider.spells:getDisabledSpells() or {}
    
    -- Combine active and disabled spells
    for spellID, spell in pairs(activeSpells) do
        allSpells[spellID] = {
            name = spell.name,
            ccType = spell.ccType,
            priority = spell.priority,
            source = spell.source or "unknown",
            active = true
        }
    end
    
    for spellID, spell in pairs(disabledSpells) do
        allSpells[spellID] = {
            name = spell.name,
            ccType = spell.ccType,
            priority = spell.priority or 50, -- Default priority for disabled spells
            source = spell.source or "unknown",
            active = false
        }
    end
    
    -- Fallback to direct access if no data provider
    if not self.dataProvider then
        -- Use unified spells table from config
        for spellID, spell in pairs(addon.Config.db.spells or {}) do
            allSpells[spellID] = {
                name = spell.name,
                ccType = spell.ccType,
                priority = spell.priority,
                source = spell.source or "unknown",
                active = spell.active
            }
        end
    end
    
    -- Sort spells by priority only (keeping disabled spells in-place)
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    table.sort(sortedSpells, function(a, b)
        return a.data.priority < b.data.priority
    end)
    
    -- Create header row
    local headerGroup = self.AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")
    self.container:AddChild(headerGroup)
    
    -- Header columns
    local headerSpacer = self.AceGUI:Create("Label")
    headerSpacer:SetText("Actions")
    headerSpacer:SetWidth(140)
    headerGroup:AddChild(headerSpacer)
    
    local iconHeader = self.AceGUI:Create("Label")
    iconHeader:SetText("Icon")
    iconHeader:SetWidth(40)
    headerGroup:AddChild(iconHeader)
    
    local nameHeader = self.AceGUI:Create("Label")
    nameHeader:SetText("Spell Name")
    nameHeader:SetWidth(150)
    headerGroup:AddChild(nameHeader)
    
    local idHeader = self.AceGUI:Create("Label")
    idHeader:SetText("Spell ID")
    idHeader:SetWidth(80)
    headerGroup:AddChild(idHeader)
    
    local typeHeader = self.AceGUI:Create("Label")
    typeHeader:SetText("CC Type")
    typeHeader:SetWidth(120)
    headerGroup:AddChild(typeHeader)
    
    local actionHeader = self.AceGUI:Create("Label")
    actionHeader:SetText("Action")
    actionHeader:SetWidth(80)
    headerGroup:AddChild(actionHeader)
    
    -- Display spells as tabular rows
    for i, spell in ipairs(sortedSpells) do
        local rowGroup = self.AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("Flow")
        self.container:AddChild(rowGroup)
        
        -- Move up button (disabled for first spell or party sync)
        local upButton = self.AceGUI:Create("Button")
        upButton:SetText(isEditingDisabled and "Up (Disabled)" or "Up")
        upButton:SetWidth(60)
        if i == 1 or isEditingDisabled then
            upButton:SetDisabled(true)
        else
            upButton:SetCallback("OnClick", function()
                -- Use data provider for spell operations
                self.dataProvider.spells:moveSpellPriority(spell.spellID, "up")
                
                -- Trigger callbacks
                self:triggerCallback('onSpellMoved', spell.spellID, "up")
            end)
        end
        rowGroup:AddChild(upButton)
        
        -- Move down button (disabled for last spell or party sync)
        local downButton = self.AceGUI:Create("Button")
        downButton:SetText(isEditingDisabled and "Down (Disabled)" or "Down")
        downButton:SetWidth(70)
        if i == #sortedSpells or isEditingDisabled then
            downButton:SetDisabled(true)
        else
            downButton:SetCallback("OnClick", function()
                -- Use data provider for spell operations
                self.dataProvider.spells:moveSpellPriority(spell.spellID, "down")
                
                -- Trigger callbacks
                self:triggerCallback('onSpellMoved', spell.spellID, "down")
            end)
        end
        rowGroup:AddChild(downButton)
        
        -- Spell icon using local helper
        local spellIcon = createSpellIcon(self.AceGUI, spell.spellID, 32)
        -- Apply visual effect for disabled spells by reducing opacity
        if not spell.data.active then
            -- Get the underlying frame and set alpha to make it appear faded
            if spellIcon.image and spellIcon.image.SetAlpha then
                spellIcon.image:SetAlpha(0.4)
            end
        end
        rowGroup:AddChild(spellIcon)
        
        -- Editable spell name for all spells
        local spellNameEdit = self.AceGUI:Create("EditBox")
        applyDisabledStyling(spellNameEdit, spell.data.name, not spell.data.active)
        spellNameEdit:SetWidth(150)
        spellNameEdit:SetDisabled(isEditingDisabled)
        spellNameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
            local newName = cleanColorCodes(text:trim())
            if newName ~= "" then
                -- Use data provider for spell operations
                if self.dataProvider then
                    self.dataProvider.spells:updateSpell(spell.spellID, 'name', newName)
                else
                    -- Fallback to direct access
                    if addon.Config.db.spells[spell.spellID] then
                        addon.Config.db.spells[spell.spellID].name = newName
                    end
                end
                
                -- Trigger callback
                self:triggerCallback('onSpellEdited', spell.spellID, 'name', newName)
            end
        end)
        rowGroup:AddChild(spellNameEdit)
        
        -- Editable spell ID for all spells
        local spellIDEdit = self.AceGUI:Create("EditBox")
        applyDisabledStyling(spellIDEdit, tostring(spell.spellID), not spell.data.active)
        spellIDEdit:SetWidth(80)
        spellIDEdit:SetDisabled(isEditingDisabled)
        local function handleSpellIDChange(widget, event, text)
            local newSpellID = tonumber(cleanColorCodes(text))
            if newSpellID and newSpellID ~= spell.spellID then
                -- Update spell ID (complex operation that may require full refresh)
                self:triggerCallback('onSpellIDChanged', spell.spellID, newSpellID, spell.data)
            end
        end
        
        spellIDEdit:SetCallback("OnEnterPressed", handleSpellIDChange)
        spellIDEdit:SetCallback("OnEditFocusLost", handleSpellIDChange)
        rowGroup:AddChild(spellIDEdit)
        
        -- Editable CC Type for all spells
        local ccTypeDropdown = createCCTypeDropdown(self.AceGUI, 120, addon.Config:NormalizeCCType(spell.data.ccType))
        ccTypeDropdown:SetDisabled(isEditingDisabled)
        -- Apply visual styling for disabled spells
        if not spell.data.active then
            local ccTypeName = addon.Config:NormalizeCCType(spell.data.ccType) or "unknown"
            local ccTypeDisplay = addon.Database.ccTypeDisplayNames[ccTypeName] or ccTypeName
            applyDisabledStyling(ccTypeDropdown, ccTypeDisplay, true)
        end
        ccTypeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
            -- Use data provider for spell operations
            if self.dataProvider then
                self.dataProvider.spells:updateSpell(spell.spellID, 'ccType', value)
            else
                -- Fallback to direct access
                if addon.Config.db.spells[spell.spellID] then
                    addon.Config.db.spells[spell.spellID].ccType = value
                end
            end
            
            -- Trigger callback
            self:triggerCallback('onSpellEdited', spell.spellID, 'ccType', value)
        end)
        rowGroup:AddChild(ccTypeDropdown)
        
        -- Action button - Enable/Disable based on current state, plus Delete for custom spells
        if spell.data.active then
            -- Disable button for active spells
            local disableButton = self.AceGUI:Create("Button")
            disableButton:SetText(isEditingDisabled and "Disable (Disabled)" or "Disable")
            disableButton:SetWidth(80)
            disableButton:SetDisabled(isEditingDisabled)
            disableButton:SetCallback("OnClick", function()
                -- Use data provider for spell operations
                if self.dataProvider then
                    self.dataProvider.spells:disableSpell(spell.spellID)
                else
                    -- Fallback to direct access
                    if addon.Config.db.spells[spell.spellID] then
                        addon.Config.db.spells[spell.spellID].active = false
                    end
                end
                
                -- Trigger callback
                self:triggerCallback('onSpellDisabled', spell.spellID)
            end)
            rowGroup:AddChild(disableButton)
        else
            -- Enable button for disabled spells
            local enableButton = self.AceGUI:Create("Button")
            enableButton:SetText(isEditingDisabled and "Enable (Disabled)" or "Enable")
            enableButton:SetWidth(80)
            enableButton:SetDisabled(isEditingDisabled)
            enableButton:SetCallback("OnClick", function()
                -- Use data provider for spell operations
                if self.dataProvider then
                    self.dataProvider.spells:enableSpell(spell.spellID)
                else
                    -- Fallback to direct access
                    if addon.Config.db.spells[spell.spellID] then
                        addon.Config.db.spells[spell.spellID].active = true
                    end
                end
                
                -- Trigger callback to parent
                self:triggerCallback('onSpellEnabled', spell.spellID)
            end)
            rowGroup:AddChild(enableButton)
            
            -- Delete button for custom disabled spells (add as second button)
            local isCustomSpell = (addon.Database.defaultSpells[spell.spellID] == nil)
            if isCustomSpell then
                local deleteButton = self.AceGUI:Create("Button")
                deleteButton:SetText(isEditingDisabled and "Del (Disabled)" or "Del")
                deleteButton:SetWidth(40)
                deleteButton:SetDisabled(isEditingDisabled)
                deleteButton:SetCallback("OnClick", function()
                    -- Use data provider for spell operations
                    if self.dataProvider then
                        self.dataProvider.spells:deleteCustomSpell(spell.spellID)
                    else
                        -- Fallback to direct access
                        addon.Config.db.spells[spell.spellID] = nil
                    end
                    
                    -- Trigger callback to parent
                    self:triggerCallback('onSpellDeleted', spell.spellID)
                end)
                rowGroup:AddChild(deleteButton)
            end
        end
    end
end

addon.Components.AddSpellForm = AddSpellForm
addon.Components.UnifiedSpellsList = UnifiedSpellsList
addon.Components.QueueDisplayComponent = QueueDisplayComponent