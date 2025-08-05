-- SpellsList.lua - Spell-related components
-- This file will contain: TrackedSpellsList, DisabledSpellsList, AddSpellForm components

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

local function createPriorityInput(AceGUI, width, defaultValue, callback)
    local input = AceGUI:Create("EditBox")
    input:SetLabel("Priority (1-50)")
    input:SetWidth(width or 100)
    input:SetText(tostring(defaultValue or 25))
    
    if callback then
        input:SetCallback("OnEnterPressed", callback)
    end
    
    return input
end

-- AddSpellForm Component
local AddSpellForm = {}
setmetatable(AddSpellForm, {__index = BaseComponent})

function AddSpellForm:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("AddSpellForm")
    return instance
end

function AddSpellForm:buildUI()
    -- Spell ID input
    local spellIDEdit = self.AceGUI:Create("EditBox")
    spellIDEdit:SetLabel("Spell ID")
    spellIDEdit:SetWidth(150)
    self.container:AddChild(spellIDEdit)
    
    -- Spell name input
    local spellNameEdit = self.AceGUI:Create("EditBox")
    spellNameEdit:SetLabel("Spell Name")
    spellNameEdit:SetWidth(200)
    self.container:AddChild(spellNameEdit)
    
    -- CC Type dropdown using local helper
    local ccTypeDropdown = createCCTypeDropdown(self.AceGUI, 150, "stun")
    self.container:AddChild(ccTypeDropdown)
    
    -- Priority input using local helper
    local priorityEdit = createPriorityInput(self.AceGUI, 100, 25)
    self.container:AddChild(priorityEdit)
    
    -- Add button
    local addButton = self.AceGUI:Create("Button")
    addButton:SetText("Add Spell")
    addButton:SetWidth(100)
    addButton:SetCallback("OnClick", function()
        local spellID = tonumber(spellIDEdit:GetText())
        local spellName = spellNameEdit:GetText():trim()
        local ccType = ccTypeDropdown:GetValue()
        local priority = tonumber(priorityEdit:GetText()) or 25
        
        if spellID and spellName ~= "" and ccType and priority then
            -- Use data provider for spell operations
            if self.dataProvider then
                self.dataProvider:addCustomSpell(spellID, spellName, ccType, priority)
            else
                -- Fallback to direct access if no data provider
                addon.Config.db.customSpells[spellID] = {
                    name = spellName,
                    ccType = ccType,
                    priority = priority
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

-- DisabledSpellsList Component
local DisabledSpellsList = {}
setmetatable(DisabledSpellsList, {__index = BaseComponent})

function DisabledSpellsList:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("DisabledSpellsList")
    return instance
end

function DisabledSpellsList:buildUI()
    -- Get disabled spells from data provider
    local inactiveSpells = self.dataProvider and self.dataProvider:getDisabledSpells() or addon.Config.db.inactiveSpells
    
    -- Check if there are any inactive spells
    local hasInactiveSpells = false
    for _ in pairs(inactiveSpells) do
        hasInactiveSpells = true
        break
    end
    
    if not hasInactiveSpells then
        local noSpellsLabel = self.AceGUI:Create("Label")
        noSpellsLabel:SetText("|cff888888No disabled spells|r")
        noSpellsLabel:SetFullWidth(true)
        self.container:AddChild(noSpellsLabel)
        return
    end
    
    -- Display inactive spells
    for spellID, spellData in pairs(inactiveSpells) do
        local inactiveRowGroup = self.AceGUI:Create("SimpleGroup")
        inactiveRowGroup:SetFullWidth(true)
        inactiveRowGroup:SetLayout("Flow")
        self.container:AddChild(inactiveRowGroup)
        
        -- Enable button
        local enableButton = self.AceGUI:Create("Button")
        enableButton:SetText("Enable")
        enableButton:SetWidth(80)
        enableButton:SetCallback("OnClick", function()
            -- Use data provider for spell operations
            if self.dataProvider then
                self.dataProvider:enableSpell(spellID)
            else
                -- Fallback to direct access
                addon.Config.db.inactiveSpells[spellID] = nil
                if addon.DataProviders and addon.DataProviders.Spells then
                    addon.DataProviders.Spells:renumberSpellPriorities()
                end
            end
            
            -- Trigger callback to parent
            self:triggerCallback('onSpellEnabled', spellID)
        end)
        inactiveRowGroup:AddChild(enableButton)
        
        -- Spell icon using local helper
        local inactiveIcon = createSpellIcon(self.AceGUI, spellID, 32)
        inactiveRowGroup:AddChild(inactiveIcon)
        
        -- Spell info (grayed out)
        local inactiveSpellLine = self.AceGUI:Create("Label")
        local ccTypeName = addon.Config:NormalizeCCType(spellData.ccType) or "unknown"
        local ccTypeDisplay = addon.Database.ccTypeDisplayNames[ccTypeName] or ccTypeName
        inactiveSpellLine:SetText(string.format("|cff888888%s (ID: %d, Type: %s)|r", 
            spellData.name, spellID, ccTypeDisplay))
        inactiveSpellLine:SetWidth(350)
        inactiveRowGroup:AddChild(inactiveSpellLine)
        
        -- Delete button (permanent removal) - only for truly custom spells
        -- A spell is truly custom if it doesn't exist in the default database
        local isCustomSpell = (addon.Database.defaultSpells[spellID] == nil)
        if isCustomSpell then
            local deleteButton = self.AceGUI:Create("Button")
            deleteButton:SetText("Delete")
            deleteButton:SetWidth(80)
            deleteButton:SetCallback("OnClick", function()
                -- Use data provider for spell operations
                if self.dataProvider then
                    self.dataProvider:deleteCustomSpell(spellID)
                else
                    -- Fallback to direct access
                    addon.Config.db.inactiveSpells[spellID] = nil
                    addon.Config.db.customSpells[spellID] = nil
                end
                
                -- Trigger callback to parent
                self:triggerCallback('onSpellDeleted', spellID)
            end)
            inactiveRowGroup:AddChild(deleteButton)
        end
    end
end

-- TrackedSpellsList Component
local TrackedSpellsList = {}
setmetatable(TrackedSpellsList, {__index = BaseComponent})

function TrackedSpellsList:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("TrackedSpellsList")
    
    -- Initialize event listeners for sync updates
    instance:Initialize()
    
    return instance
end

function TrackedSpellsList:Initialize()
    -- Register for profile sync events to refresh UI when sync data arrives
    -- Using BaseComponent method for cleaner registration
    self:RegisterEventListener("PROFILE_SYNC_RECEIVED", function(profileData)
        if profileData.customSpells or profileData.inactiveSpells then
            -- Only refresh UI if the spells tab is currently active
            if addon.UI and addon.UI:IsConfigTabActive("spells") then
                self:refreshUI()
            end
        end
    end)
end

function TrackedSpellsList:refreshUI()
    -- Clear current container and rebuild UI with updated data
    if self.container then
        self.container:ReleaseChildren()
        self:buildUI()
    end
end

function TrackedSpellsList:buildUI()
    -- Get all active spells from data provider
    local allSpells = self.dataProvider and self.dataProvider:getActiveSpells() or {}
    
    -- Fallback to direct access if no data provider
    if not self.dataProvider then
        -- Add database spells (if not inactive)
        for spellID, data in pairs(addon.Database.defaultSpells) do
            if not addon.Config.db.inactiveSpells[spellID] then
                allSpells[spellID] = {
                    name = data.name,
                    ccType = data.ccType,
                    priority = data.priority,
                    source = "database"
                }
            end
        end
        
        -- Add custom spells (if not inactive, override database if same ID)
        for spellID, data in pairs(addon.Config.db.customSpells) do
            if not addon.Config.db.inactiveSpells[spellID] then
                allSpells[spellID] = {
                    name = data.name,
                    ccType = data.ccType,
                    priority = data.priority,
                    source = "custom"
                }
            end
        end
    end
    
    -- Sort spells by priority
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    table.sort(sortedSpells, function(a, b) return a.data.priority < b.data.priority end)
    
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
        
        -- Move up button (disabled for first item)
        local upButton = self.AceGUI:Create("Button")
        upButton:SetText("Up")
        upButton:SetWidth(60)
        if i == 1 then
            upButton:SetDisabled(true)
        else
            upButton:SetCallback("OnClick", function()
                -- Use data provider for spell operations
                self.dataProvider:moveSpellPriority(spell.spellID, spell.data, "up", sortedSpells, i)
                
                -- Trigger callbacks
                self:triggerCallback('onSpellMoved', spell.spellID, "up")
            end)
        end
        rowGroup:AddChild(upButton)
        
        -- Move down button (disabled for last item)
        local downButton = self.AceGUI:Create("Button")
        downButton:SetText("Down")
        downButton:SetWidth(70)
        if i == #sortedSpells then
            downButton:SetDisabled(true)
        else
            downButton:SetCallback("OnClick", function()
                -- Use data provider for spell operations
                self.dataProvider:moveSpellPriority(spell.spellID, spell.data, "down", sortedSpells, i)
                
                -- Trigger callbacks
                self:triggerCallback('onSpellMoved', spell.spellID, "down")
            end)
        end
        rowGroup:AddChild(downButton)
        
        -- Spell icon using local helper
        local spellIcon = createSpellIcon(self.AceGUI, spell.spellID, 32)
        rowGroup:AddChild(spellIcon)
        
        -- Editable spell name
        local spellNameEdit = self.AceGUI:Create("EditBox")
        spellNameEdit:SetText(spell.data.name)
        spellNameEdit:SetWidth(150)
        spellNameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
            local newName = text:trim()
            if newName ~= "" then
                -- Use data provider for spell operations
                if self.dataProvider then
                    self.dataProvider:updateSpell(spell.spellID, spell.data, 'name', newName)
                else
                    -- Fallback to direct access
                    if spell.data.source == "custom" then
                        addon.Config.db.customSpells[spell.spellID].name = newName
                    else
                        addon.Config.db.customSpells[spell.spellID] = {
                            name = newName,
                            ccType = spell.data.ccType,
                            priority = spell.data.priority
                        }
                    end
                end
                
                -- Trigger callback
                self:triggerCallback('onSpellEdited', spell.spellID, 'name', newName)
            end
        end)
        rowGroup:AddChild(spellNameEdit)
        
        -- Editable spell ID
        local spellIDEdit = self.AceGUI:Create("EditBox")
        spellIDEdit:SetText(tostring(spell.spellID))
        spellIDEdit:SetWidth(80)
        spellIDEdit:SetCallback("OnEnterPressed", function(widget, event, text)
            local newSpellID = tonumber(text)
            if newSpellID and newSpellID ~= spell.spellID then
                -- Update spell ID (complex operation that may require full refresh)
                self:triggerCallback('onSpellIDChanged', spell.spellID, newSpellID, spell.data)
            end
        end)
        rowGroup:AddChild(spellIDEdit)
        
        -- Editable CC type dropdown using local helper
        local ccTypeDropdown = createCCTypeDropdown(self.AceGUI, 120, addon.Config:NormalizeCCType(spell.data.ccType))
        ccTypeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
            -- Use data provider for spell operations
            if self.dataProvider then
                self.dataProvider:updateSpell(spell.spellID, spell.data, 'ccType', value)
            else
                -- Fallback to direct access
                if spell.data.source == "custom" then
                    addon.Config.db.customSpells[spell.spellID].ccType = value
                else
                    addon.Config.db.customSpells[spell.spellID] = {
                        name = spell.data.name,
                        ccType = value,
                        priority = spell.data.priority
                    }
                end
            end
            
            -- Trigger callback
            self:triggerCallback('onSpellEdited', spell.spellID, 'ccType', value)
        end)
        rowGroup:AddChild(ccTypeDropdown)
        
        -- Disable button (for all spells)
        local disableButton = self.AceGUI:Create("Button")
        disableButton:SetText("Disable")
        disableButton:SetWidth(80)
        disableButton:SetCallback("OnClick", function()
            -- Use data provider for spell operations
            if self.dataProvider then
                self.dataProvider:disableSpell(spell.spellID, spell.data)
            else
                -- Fallback to direct access
                addon.Config.db.inactiveSpells[spell.spellID] = {
                    name = spell.data.name,
                    ccType = spell.data.ccType,
                    priority = spell.data.priority,
                    source = spell.data.source
                }
                if addon.DataProviders and addon.DataProviders.Spells then
                    addon.DataProviders.Spells:renumberSpellPriorities()
                end
            end
            
            -- Trigger callback
            self:triggerCallback('onSpellDisabled', spell.spellID)
        end)
        rowGroup:AddChild(disableButton)
    end
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
    
    -- Get the full unfiltered queue by rebuilding it manually
    local fullQueue = {}
    
    if addon.CCRotation and addon.CCRotation.GUIDToUnit then
        -- Use LibOpenRaid to get all cooldowns from all units
        local lib = LibStub("LibOpenRaid-1.0", true)
        if lib then
            local allUnits = lib.GetAllUnitsCooldown()
            if allUnits then
                for unit, cds in pairs(allUnits) do
                    for spellID, info in pairs(cds) do
                        if addon.CCRotation.trackedCooldowns and addon.CCRotation.trackedCooldowns[spellID] then
                            local spellInfo = addon.CCRotation.trackedCooldowns[spellID]
                            local ccType = spellInfo.type -- This contains string values like "stun", "disorient", etc.
                                                            
                            -- Apply CC type filter
                            if not ccType or self.ccTypeFilters[ccType] then
                                local guid = UnitGUID(unit)
                                if guid then
                                    local _, _, timeLeft, charges, _, _, _, duration = lib.GetCooldownStatusFromCooldownInfo(info)
                                    local currentTime = GetTime()
                                    
                                    table.insert(fullQueue, {
                                        GUID = guid,
                                        unit = unit,
                                        spellID = spellID,
                                        priority = spellInfo.priority,
                                        expirationTime = timeLeft + currentTime,
                                        duration = duration,
                                        charges = charges,
                                        ccType = ccType
                                    })
                                end
                            end
                        end
                    end
                end
            end
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
            
            iconRow:AddChild(spellIcon)
        end
    end
end

-- Register components in addon namespace
addon.Components.AddSpellForm = AddSpellForm
addon.Components.DisabledSpellsList = DisabledSpellsList
addon.Components.TrackedSpellsList = TrackedSpellsList
addon.Components.QueueDisplayComponent = QueueDisplayComponent