-- NPCsList.lua - NPC-related components
-- This file contains: CurrentLocationComponent, DungeonNPCListComponent, NPCSearchComponent, AddNPCComponent

local addonName, addon = ...

-- Ensure Components namespace exists
if not addon.Components then
    addon.Components = {}
end

local BaseComponent = addon.BaseComponent

-- Local helper function for CC type headers
local function getCCTypeHeaders()
    return {"Stun", "Disorient", "Fear", "Knock", "Incap"}
end

-- CurrentLocationComponent - Shows current dungeon status and filtering
local CurrentLocationComponent = {}
setmetatable(CurrentLocationComponent, {__index = BaseComponent})

function CurrentLocationComponent:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("CurrentLocationComponent")
    
    -- Initialize state
    instance.showOnlyCurrentDungeon = false
    
    return instance
end

function CurrentLocationComponent:buildUI()
    -- Get current dungeon info from data provider
    local currentAbbrev, currentDungeonName, instanceType = self.dataProvider and 
        self.dataProvider:getCurrentDungeonInfo() or addon.Database:GetCurrentDungeonInfo()
    
    -- Current dungeon status label
    local dungeonStatusLabel = self.AceGUI:Create("Label")
    dungeonStatusLabel:SetWidth(400)
    if currentDungeonName then
        if currentAbbrev then
            dungeonStatusLabel:SetText("|cff00ff00Currently in: " .. currentDungeonName .. " (" .. instanceType .. ")|r")
        else
            dungeonStatusLabel:SetText("|cffff8800Currently in: " .. currentDungeonName .. " (" .. instanceType .. ") - Unknown dungeon|r")
        end
    else
        if instanceType == "none" then
            dungeonStatusLabel:SetText("|cffccccccNot currently in a dungeon.|r")
        else
            dungeonStatusLabel:SetText("|cffccccccCurrently in: " .. (instanceType or "unknown") .. " - Not a supported instance type.|r")
        end
    end
    self.container:AddChild(dungeonStatusLabel)
    
    -- Current dungeon filter toggle (only show if in a known dungeon)
    if currentAbbrev and currentDungeonName then
        local filterCurrentButton = self.AceGUI:Create("Button")
        filterCurrentButton:SetText(self.showOnlyCurrentDungeon and "Show All Dungeons" or "Show Only Current Dungeon")
        filterCurrentButton:SetWidth(180)
        filterCurrentButton:SetCallback("OnClick", function()
            self.showOnlyCurrentDungeon = not self.showOnlyCurrentDungeon
            filterCurrentButton:SetText(self.showOnlyCurrentDungeon and "Show All Dungeons" or "Show Only Current Dungeon")
            
            -- Trigger callback to parent to refresh
            self:triggerCallback('onFilterChanged', self.showOnlyCurrentDungeon and currentDungeonName or nil)
        end)
        self.container:AddChild(filterCurrentButton)
        
        -- Refresh button to update dungeon status
        local refreshButton = self.AceGUI:Create("Button")
        refreshButton:SetText("Refresh Location")
        refreshButton:SetWidth(120)
        refreshButton:SetCallback("OnClick", function()
            -- Trigger callback to parent to refresh entire tab
            self:triggerCallback('onLocationRefresh')
        end)
        self.container:AddChild(refreshButton)
    end
end

-- DungeonNPCListComponent - Shows NPCs grouped by dungeon with expand/collapse
local DungeonNPCListComponent = {}
setmetatable(DungeonNPCListComponent, {__index = BaseComponent})

function DungeonNPCListComponent:new(container, callbacks, dataProvider, scrollFrame)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("DungeonNPCListComponent")
    
    -- Initialize state
    instance.collapsedDungeons = {}
    instance.filterToDungeon = nil
    instance.scrollFrame = scrollFrame
    
    -- Initialize event listeners for sync updates
    instance:Initialize()
    
    return instance
end

function DungeonNPCListComponent:Initialize()
    -- Register for profile sync events to refresh UI when sync data arrives
    addon.Config:RegisterEventListener("PROFILE_SYNC_RECEIVED", function(profileData)
        if profileData.customNPCs then
            self:refreshUI()
        end
    end)
end

function DungeonNPCListComponent:refreshUI()
    -- Clear current container and rebuild UI with updated data
    if self.container then
        self.container:ReleaseChildren()
        self:buildUI()
    end
end

function DungeonNPCListComponent:setFilter(filterToDungeon)
    self.filterToDungeon = filterToDungeon
end

function DungeonNPCListComponent:expandDungeon(dungeonName)
    self.collapsedDungeons[dungeonName] = false
end

function DungeonNPCListComponent:buildUI()
    -- Clear existing children
    self.container:ReleaseChildren()
    
    -- Get NPCs grouped by dungeon from data provider
    local sortedDungeons = self.dataProvider and 
        self.dataProvider:getNPCsByDungeon(self.filterToDungeon) or {}
    
    local ccTypes = getCCTypeHeaders()
    
    -- Display dungeons with collapsible groups
    for _, dungeon in ipairs(sortedDungeons) do
        local dungeonName = dungeon.name
        local dungeonData = dungeon.data
        
        -- Create dungeon group
        local dungeonGroup = self.AceGUI:Create("InlineGroup")
        -- Count NPCs in this dungeon
        local npcCount = 0
        for _ in pairs(dungeonData.npcs) do
            npcCount = npcCount + 1
        end
        dungeonGroup:SetTitle(dungeonName .. " (" .. npcCount .. " NPCs)")
        dungeonGroup:SetFullWidth(true)
        dungeonGroup:SetLayout("Flow")
        self.container:AddChild(dungeonGroup)
        
        -- Collapse/Expand button
        local toggleButton = self.AceGUI:Create("Button")
        -- Default to collapsed if not explicitly set
        local isCollapsed = self.collapsedDungeons[dungeonName]
        if isCollapsed == nil then
            isCollapsed = true
            self.collapsedDungeons[dungeonName] = true
        end
        toggleButton:SetText(isCollapsed and "Expand" or "Collapse")
        toggleButton:SetWidth(100)
        toggleButton:SetCallback("OnClick", function()
            self.collapsedDungeons[dungeonName] = not self.collapsedDungeons[dungeonName]
            -- Trigger callback to parent to refresh
            self:triggerCallback('onDungeonToggle', dungeonName)
        end)
        dungeonGroup:AddChild(toggleButton)
        
        -- Only show content if not collapsed
        if not isCollapsed then
            self:createDungeonContent(dungeonGroup, dungeonName, dungeonData, ccTypes)
        end
    end
    
    -- Force scroll frame to recalculate its content size after building UI
    if self.scrollFrame and self.scrollFrame.DoLayout then
        self.scrollFrame:DoLayout()
    end
end

function DungeonNPCListComponent:createDungeonContent(dungeonGroup, dungeonName, dungeonData, ccTypes)
    -- Create header for this dungeon
    local headerGroup = self.AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")
    dungeonGroup:AddChild(headerGroup)
    
    -- Headers
    local nameHeader = self.AceGUI:Create("Label")
    nameHeader:SetText("NPC Name")
    nameHeader:SetWidth(180)
    headerGroup:AddChild(nameHeader)
    
    local idHeader = self.AceGUI:Create("Label")
    idHeader:SetText("ID")
    idHeader:SetWidth(60)
    headerGroup:AddChild(idHeader)
    
    local dungeonHeader = self.AceGUI:Create("Label")
    dungeonHeader:SetText("Dungeon")
    dungeonHeader:SetWidth(100)
    headerGroup:AddChild(dungeonHeader)
    
    for i, ccType in ipairs(ccTypes) do
        local ccHeader = self.AceGUI:Create("Label")
        ccHeader:SetText(ccType)
        ccHeader:SetWidth(60)
        headerGroup:AddChild(ccHeader)
    end
    
    local actionHeader = self.AceGUI:Create("Label")
    actionHeader:SetText("Action")
    actionHeader:SetWidth(80)
    headerGroup:AddChild(actionHeader)
    
    -- Sort NPCs within dungeon by mob name
    local sortedNPCs = {}
    for npcID, npcData in pairs(dungeonData.npcs) do
        table.insert(sortedNPCs, {npcID = npcID, data = npcData})
    end
    table.sort(sortedNPCs, function(a, b) return (a.data.mobName or a.data.name) < (b.data.mobName or b.data.name) end)
    
    -- Display NPCs
    for _, npc in ipairs(sortedNPCs) do
        self:createNPCRow(dungeonGroup, npc.npcID, npc.data, dungeonName, dungeonData)
    end
end

function DungeonNPCListComponent:createNPCRow(dungeonGroup, npcID, npcData, dungeonName, dungeonData)
    local rowGroup = self.AceGUI:Create("SimpleGroup")
    rowGroup:SetFullWidth(true)
    rowGroup:SetLayout("Flow")
    dungeonGroup:AddChild(rowGroup)
    
    -- Editable mob name (without dungeon prefix)
    local mobNameEdit = self.AceGUI:Create("EditBox")
    mobNameEdit:SetText(npcData.mobName or npcData.name)
    mobNameEdit:SetWidth(180)
    mobNameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        local newMobName = text:trim()
        if newMobName ~= "" and self.dataProvider then
            self.dataProvider:updateNPCName(npcID, npcData, newMobName, dungeonName, dungeonData.abbreviation)
            -- Trigger callback to parent
            self:triggerCallback('onNPCChanged', npcID)
        end
    end)
    rowGroup:AddChild(mobNameEdit)
    
    -- NPC ID (read-only display)
    local npcIDLabel = self.AceGUI:Create("Label")
    npcIDLabel:SetText(tostring(npcID))
    npcIDLabel:SetWidth(60)
    rowGroup:AddChild(npcIDLabel)
    
    -- Dungeon dropdown (editable for custom NPCs)
    local dungeonDropdown = self.AceGUI:Create("Dropdown")
    dungeonDropdown:SetWidth(100)
    
    -- Get dungeon list from data provider
    local dungeonList = self.dataProvider and self.dataProvider:getDungeonList() or {}
    dungeonDropdown:SetList(dungeonList)
    dungeonDropdown:SetValue(dungeonName)
    
    if npcData.source == "custom" then
        dungeonDropdown:SetCallback("OnValueChanged", function(widget, event, value)
            if self.dataProvider then
                self.dataProvider:updateNPCDungeon(npcID, npcData, value)
                -- Trigger callback to parent to refresh (regroup)
                self:triggerCallback('onNPCDungeonChanged', npcID)
            end
        end)
    else
        dungeonDropdown:SetDisabled(true)
    end
    rowGroup:AddChild(dungeonDropdown)
    
    -- CC effectiveness checkboxes
    for i = 1, 5 do
        local ccCheck = self.AceGUI:Create("CheckBox")
        ccCheck:SetWidth(60)
        ccCheck:SetValue(npcData.cc[i])
        ccCheck:SetCallback("OnValueChanged", function(widget, event, value)
            if self.dataProvider then
                self.dataProvider:updateNPCCC(npcID, npcData, i, value, dungeonName)
                -- Trigger callback to parent
                self:triggerCallback('onNPCChanged', npcID)
            end
        end)
        rowGroup:AddChild(ccCheck)
    end
    
    -- Reset/Delete button
    if npcData.source == "custom" and addon.Database.defaultNPCs[npcID] then
        local resetButton = self.AceGUI:Create("Button")
        resetButton:SetText("Reset")
        resetButton:SetWidth(80)
        resetButton:SetCallback("OnClick", function()
            if self.dataProvider then
                self.dataProvider:resetNPC(npcID)
                -- Trigger callback to parent to refresh
                self:triggerCallback('onNPCChanged', npcID)
            end
        end)
        rowGroup:AddChild(resetButton)
    elseif npcData.source == "custom" then
        -- Delete button for custom-only NPCs
        local deleteButton = self.AceGUI:Create("Button")
        deleteButton:SetText("Delete")
        deleteButton:SetWidth(80)
        deleteButton:SetCallback("OnClick", function()
            if self.dataProvider then
                self.dataProvider:deleteCustomNPC(npcID)
                -- Trigger callback to parent to refresh
                self:triggerCallback('onNPCChanged', npcID)
            end
        end)
        rowGroup:AddChild(deleteButton)
    end
end

-- NPCSearchComponent - Quick NPC lookup functionality
local NPCSearchComponent = {}
setmetatable(NPCSearchComponent, {__index = BaseComponent})

function NPCSearchComponent:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("NPCSearchComponent")
    return instance
end

function NPCSearchComponent:buildUI()
    -- Lookup from target for existing NPCs
    local lookupTargetButton = self.AceGUI:Create("Button")
    lookupTargetButton:SetText("Find Target in List")
    lookupTargetButton:SetWidth(130)
    self.container:AddChild(lookupTargetButton)
    
    -- Search existing NPCs
    local lookupSearchEdit = self.AceGUI:Create("EditBox")
    lookupSearchEdit:SetLabel("Search NPCs")
    lookupSearchEdit:SetWidth(200)
    self.container:AddChild(lookupSearchEdit)
    
    -- Search existing button
    local lookupSearchButton = self.AceGUI:Create("Button")
    lookupSearchButton:SetText("Find")
    lookupSearchButton:SetWidth(60)
    self.container:AddChild(lookupSearchButton)
    
    -- Lookup status
    local lookupStatusLabel = self.AceGUI:Create("Label")
    lookupStatusLabel:SetText("")
    lookupStatusLabel:SetWidth(400)
    self.container:AddChild(lookupStatusLabel)
    
    -- Lookup callbacks
    lookupTargetButton:SetCallback("OnClick", function()
        local targetInfo = self.dataProvider and self.dataProvider:getTargetNPCInfo() or nil
        if not targetInfo then
            lookupStatusLabel:SetText("|cffff0000No valid NPC target found.|r")
            return
        end
        
        -- Check if target exists in our configuration
        local abbrev, dungeonName, mobName = self.dataProvider and 
            self.dataProvider:extractDungeonInfo(targetInfo.name) or 
            addon.Database:ExtractDungeonInfo(targetInfo.name)
            
        if targetInfo.exists then
            lookupStatusLabel:SetText("|cff00ff00Found: " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ") in " .. (dungeonName or "Other") .. " dungeon section above.|r")
            
            -- Trigger callback to expand dungeon
            if dungeonName then
                self:triggerCallback('onExpandDungeon', dungeonName)
            end
        else
            lookupStatusLabel:SetText("|cffff8800Target " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ") not found in configuration. You can add it below.|r")
        end
    end)
    
    lookupSearchButton:SetCallback("OnClick", function()
        local searchTerm = lookupSearchEdit:GetText():trim()
        if searchTerm == "" then
            lookupStatusLabel:SetText("|cffff0000Enter a name to search.|r")
            return
        end
        
        local results = self.dataProvider and self.dataProvider:searchNPCsByName(searchTerm) or {}
        if #results == 0 then
            lookupStatusLabel:SetText("|cffff8800No NPCs found matching '" .. searchTerm .. "'.|r")
        else
            local resultText = "Found " .. #results .. " NPCs: "
            local dungeonsToExpand = {}
            
            for i = 1, math.min(3, #results) do
                if i > 1 then resultText = resultText .. ", " end
                local result = results[i]
                local abbrev, dungeonName, mobName = self.dataProvider and 
                    self.dataProvider:extractDungeonInfo(result.name) or 
                    addon.Database:ExtractDungeonInfo(result.name)
                resultText = resultText .. (mobName or result.name) .. " (" .. result.id .. ")"
                
                if dungeonName then
                    dungeonsToExpand[dungeonName] = true
                end
            end
            
            if #results > 3 then
                resultText = resultText .. "..."
            end
            
            lookupStatusLabel:SetText("|cff00ff00" .. resultText .. "|r")
            
            -- Trigger callback to expand relevant dungeons
            for dungeonName in pairs(dungeonsToExpand) do
                self:triggerCallback('onExpandDungeon', dungeonName)
            end
        end
    end)
    
    -- Enter key support for search
    lookupSearchEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        lookupSearchButton.frame:Click()
    end)
end

-- AddNPCComponent - Add custom NPC functionality
local AddNPCComponent = {}
setmetatable(AddNPCComponent, {__index = BaseComponent})

function AddNPCComponent:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("AddNPCComponent")
    
    -- Initialize CC effectiveness state
    instance.newNPCCC = {true, true, true, true, true}
    
    return instance
end

function AddNPCComponent:buildUI()
    -- Get current dungeon info for auto-selection
    local currentAbbrev, currentDungeonName, instanceType = self.dataProvider and 
        self.dataProvider:getCurrentDungeonInfo() or addon.Database:GetCurrentDungeonInfo()
    
    -- Lookup from target button
    local targetButton = self.AceGUI:Create("Button")
    targetButton:SetText("Get from Target")
    targetButton:SetWidth(120)
    self.container:AddChild(targetButton)
    
    -- Status label for feedback
    local statusLabel = self.AceGUI:Create("Label")
    statusLabel:SetText("")
    statusLabel:SetWidth(250)
    self.container:AddChild(statusLabel)
    
    -- NPC ID input
    local npcIDEdit = self.AceGUI:Create("EditBox")
    npcIDEdit:SetLabel("NPC ID")
    npcIDEdit:SetWidth(100)
    self.container:AddChild(npcIDEdit)
    
    -- NPC name input
    local npcNameEdit = self.AceGUI:Create("EditBox")
    npcNameEdit:SetLabel("NPC Name")
    npcNameEdit:SetWidth(200)
    self.container:AddChild(npcNameEdit)
    
    -- Search button
    local searchButton = self.AceGUI:Create("Button")
    searchButton:SetText("Search")
    searchButton:SetWidth(80)
    self.container:AddChild(searchButton)
    
    -- Dungeon dropdown for new NPC
    local newNPCDungeonDropdown = self.AceGUI:Create("Dropdown")
    newNPCDungeonDropdown:SetLabel("Dungeon")
    newNPCDungeonDropdown:SetWidth(150)
    local dungeonList = self.dataProvider and self.dataProvider:getDungeonList() or {}
    newNPCDungeonDropdown:SetList(dungeonList)
    
    -- Auto-select current dungeon if we're in one
    if currentAbbrev and currentDungeonName then
        newNPCDungeonDropdown:SetValue(currentDungeonName)
    else
        newNPCDungeonDropdown:SetValue("Other")
    end
    self.container:AddChild(newNPCDungeonDropdown)
    
    -- Store references for callbacks
    self.statusLabel = statusLabel
    self.npcIDEdit = npcIDEdit
    self.npcNameEdit = npcNameEdit
    self.newNPCDungeonDropdown = newNPCDungeonDropdown
    
    -- Add target lookup functionality
    self:setupTargetLookup(targetButton)
    
    -- Add search functionality
    self:setupSearch(searchButton)
    
    -- Add NPC ID validation
    self:setupNPCIDValidation(npcIDEdit)
    
    -- Enter key support for search
    npcNameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        searchButton.frame:Click()
    end)
    
    -- CC effectiveness checkboxes for new NPC
    local ccTypes = getCCTypeHeaders()
    self.newNPCCCChecks = {}
    
    for i, ccType in ipairs(ccTypes) do
        local ccCheck = self.AceGUI:Create("CheckBox")
        ccCheck:SetLabel(ccType)
        ccCheck:SetWidth(70)
        ccCheck:SetValue(true)
        ccCheck:SetCallback("OnValueChanged", function(widget, event, value)
            self.newNPCCC[i] = value
        end)
        self.container:AddChild(ccCheck)
        self.newNPCCCChecks[i] = ccCheck
    end
    
    -- Add button
    local addButton = self.AceGUI:Create("Button")
    addButton:SetText("Add NPC")
    addButton:SetWidth(100)
    addButton:SetCallback("OnClick", function()
        self:addNPC()
    end)
    self.container:AddChild(addButton)
end

function AddNPCComponent:setupTargetLookup(targetButton)
    targetButton:SetCallback("OnClick", function()
        local targetInfo = self.dataProvider and self.dataProvider:getTargetNPCInfo() or nil
        if not targetInfo then
            self.statusLabel:SetText("|cffff0000No valid NPC target found.|r")
            return
        end
        
        -- Fill in the form with target data
        self.npcIDEdit:SetText(tostring(targetInfo.id))
        self.npcNameEdit:SetText(targetInfo.name)
        
        -- Try to detect dungeon from name first
        local abbrev, dungeonName, mobName = self.dataProvider and 
            self.dataProvider:extractDungeonInfo(targetInfo.name) or 
            addon.Database:ExtractDungeonInfo(targetInfo.name)
        
        -- If no dungeon detected from name, use current location
        if not dungeonName or dungeonName == "Other" then
            local currentAbbrev, currentDungeonName, instanceType = self.dataProvider and 
                self.dataProvider:getCurrentDungeonInfo() or addon.Database:GetCurrentDungeonInfo()
            if currentDungeonName and currentAbbrev then
                dungeonName = currentDungeonName
                abbrev = currentAbbrev
                mobName = targetInfo.name -- Use full name since no prefix detected
                self.statusLabel:SetText("|cff00ffff Target loaded from current dungeon: " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ")|r")
            end
        end
        
        -- Set dungeon and clean up name
        if dungeonName and dungeonName ~= "Other" then
            self.newNPCDungeonDropdown:SetValue(dungeonName)
            if mobName then
                self.npcNameEdit:SetText(mobName) -- Use just the mob name without prefix
            end
        end
        
        -- Check if NPC already exists
        if targetInfo.exists then
            self.statusLabel:SetText("|cffff8800NPC already exists in database.|r")
        else
            -- Only override status if we haven't already set a "current dungeon" message
            local currentDungeonName = self.dataProvider and 
                self.dataProvider:getCurrentDungeonInfo() or nil
            local currentStatusSet = (dungeonName and currentDungeonName and dungeonName == currentDungeonName)
            if not currentStatusSet then
                self.statusLabel:SetText("|cff00ff00Target loaded: " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ")|r")
            end
        end
    end)
end

function AddNPCComponent:setupSearch(searchButton)
    searchButton:SetCallback("OnClick", function()
        local searchTerm = self.npcNameEdit:GetText():trim()
        if searchTerm == "" then
            self.statusLabel:SetText("|cffff0000Enter a name to search.|r")
            return
        end
        
        local results = self.dataProvider and self.dataProvider:searchNPCsByName(searchTerm) or {}
        if #results == 0 then
            self.statusLabel:SetText("|cffff8800No NPCs found matching '" .. searchTerm .. "'.|r")
        elseif #results == 1 then
            -- Single result - auto fill
            local result = results[1]
            self.npcIDEdit:SetText(tostring(result.id))
            self.npcNameEdit:SetText(result.name)
            
            -- Try to detect dungeon
            local abbrev, dungeonName, mobName = self.dataProvider and 
                self.dataProvider:extractDungeonInfo(result.name) or 
                addon.Database:ExtractDungeonInfo(result.name)
            if dungeonName and dungeonName ~= "Other" then
                self.newNPCDungeonDropdown:SetValue(dungeonName)
                self.npcNameEdit:SetText(mobName)
            end
            
            self.statusLabel:SetText("|cff00ff00Found: " .. result.name .. " (ID: " .. result.id .. ", " .. result.source .. ")|r")
        else
            -- Multiple results - show first few
            local resultText = "Found " .. #results .. " results: "
            for i = 1, math.min(3, #results) do
                if i > 1 then resultText = resultText .. ", " end
                resultText = resultText .. results[i].name .. " (" .. results[i].id .. ")"
            end
            if #results > 3 then
                resultText = resultText .. "..."
            end
            self.statusLabel:SetText("|cff00ffff" .. resultText .. "|r")
            
            -- Auto-fill with first result
            local result = results[1]
            self.npcIDEdit:SetText(tostring(result.id))
            self.npcNameEdit:SetText(result.name)
            
            -- Try to detect dungeon
            local abbrev, dungeonName, mobName = self.dataProvider and 
                self.dataProvider:extractDungeonInfo(result.name) or 
                addon.Database:ExtractDungeonInfo(result.name)
            if dungeonName and dungeonName ~= "Other" then
                self.newNPCDungeonDropdown:SetValue(dungeonName)
                self.npcNameEdit:SetText(mobName)
            end
        end
    end)
end

function AddNPCComponent:setupNPCIDValidation(npcIDEdit)
    npcIDEdit:SetCallback("OnTextChanged", function(widget, event, text)
        local npcID = tonumber(text)
        if npcID then
            local exists, source = self.dataProvider and 
                self.dataProvider:npcExists(npcID) or addon.Database:NPCExists(npcID)
            if exists then
                self.statusLabel:SetText("|cffff8800NPC ID " .. npcID .. " already exists (" .. source .. ").|r")
            else
                self.statusLabel:SetText("")
            end
        end
    end)
end

function AddNPCComponent:addNPC()
    local npcID = tonumber(self.npcIDEdit:GetText())
    local npcName = self.npcNameEdit:GetText():trim()
    local selectedDungeon = self.newNPCDungeonDropdown:GetValue()
    
    if not npcID then
        self.statusLabel:SetText("|cffff0000Please enter a valid NPC ID.|r")
        return
    end
    
    if npcName == "" then
        self.statusLabel:SetText("|cffff0000Please enter an NPC name.|r")
        return
    end
    
    -- Check if NPC already exists
    local exists, source = self.dataProvider and 
        self.dataProvider:npcExists(npcID) or addon.Database:NPCExists(npcID)
    if exists then
        self.statusLabel:SetText("|cffff0000NPC ID " .. npcID .. " already exists in " .. source .. ". Use Reset button to modify database NPCs.|r")
        return
    end
    
    -- Add NPC via data provider
    local fullName = ""
    if self.dataProvider then
        fullName = self.dataProvider:addCustomNPC(npcID, npcName, selectedDungeon, self.newNPCCC)
    end
    
    self.statusLabel:SetText("|cff00ff00Successfully added " .. fullName .. " (ID: " .. npcID .. ")|r")
    
    -- Clear inputs
    self:clearForm()
    
    -- Trigger callback to parent to refresh
    self:triggerCallback('onNPCAdded', npcID)
end

function AddNPCComponent:clearForm()
    self.npcIDEdit:SetText("")
    self.npcNameEdit:SetText("")
    
    -- Reset to current dungeon if we're in one, otherwise "Other"
    local currentAbbrev, currentDungeonName, instanceType = self.dataProvider and 
        self.dataProvider:getCurrentDungeonInfo() or addon.Database:GetCurrentDungeonInfo()
    if currentAbbrev and currentDungeonName then
        self.newNPCDungeonDropdown:SetValue(currentDungeonName)
    else
        self.newNPCDungeonDropdown:SetValue("Other")
    end
    
    -- Reset checkboxes to default (all true)
    for i, check in ipairs(self.newNPCCCChecks) do
        check:SetValue(true)
        self.newNPCCC[i] = true
    end
end

-- Register components in addon namespace
addon.Components.CurrentLocationComponent = CurrentLocationComponent
addon.Components.DungeonNPCListComponent = DungeonNPCListComponent
addon.Components.NPCSearchComponent = NPCSearchComponent
addon.Components.AddNPCComponent = AddNPCComponent