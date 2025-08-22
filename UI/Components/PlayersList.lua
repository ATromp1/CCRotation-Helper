-- PlayersList.lua - Player-related components
-- This file contains: PriorityPlayersList, AddPlayerForm, RemovePlayerForm components

local addonName, addon = ...

-- Ensure Components namespace exists
if not addon.Components then
    addon.Components = {}
end

local BaseComponent = addon.BaseComponent

-- PriorityPlayersList Component
local PriorityPlayersList = {}
setmetatable(PriorityPlayersList, {__index = BaseComponent})

function PriorityPlayersList:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("PriorityPlayersList")
    
    -- Initialize event listeners for sync updates
    instance:Initialize()
    
    return instance
end

function PriorityPlayersList:Initialize()
    -- Register for profile sync events to refresh UI when sync data arrives
    -- Using BaseComponent method for standardized registration
    self:RegisterEventListener("PROFILE_SYNC_RECEIVED", function(profileData)
        if profileData.priorityPlayers then
            -- Only refresh UI if the players tab is currently active
            if addon.UI and addon.UI:IsConfigTabActive("players") then
                self:refreshDisplay()
            end
        end
    end)
end

function PriorityPlayersList:buildUI()
    -- Store container reference for refresh
    self.playersContainer = self.container
    
    -- Initial display
    self:refreshDisplay()
end

function PriorityPlayersList:refreshDisplay()
    if not self.playersContainer then
        return
    end
    
    -- Clear existing children
    self.playersContainer:ReleaseChildren()
    
    -- Get priority players from data provider
    local priorityPlayers = self.dataProvider and self.dataProvider.players:getPriorityPlayersArray() or {}
    
    -- Fallback to direct access if no data provider
    if not self.dataProvider then
        priorityPlayers = {}
        for name in pairs(addon.Config.db.priorityPlayers) do
            table.insert(priorityPlayers, name)
        end
        table.sort(priorityPlayers)
    end
    
    if #priorityPlayers == 0 then
        local noPlayersLabel = self.AceGUI:Create("Label")
        noPlayersLabel:SetText("|cff888888No priority players set|r")
        noPlayersLabel:SetFullWidth(true)
        self.playersContainer:AddChild(noPlayersLabel)
        return
    end
    
    -- Display each player on its own row with delete button
    for _, playerName in ipairs(priorityPlayers) do
        local playerRowGroup = self.AceGUI:Create("SimpleGroup")
        playerRowGroup:SetFullWidth(true)
        playerRowGroup:SetLayout("Flow")
        self.playersContainer:AddChild(playerRowGroup)
        
        -- Player name label
        local playerLabel = self.AceGUI:Create("Label")
        playerLabel:SetText(playerName)
        playerLabel:SetWidth(200)
        playerRowGroup:AddChild(playerLabel)
        
        -- Delete button for this specific player
        local deleteButton = self.AceGUI:Create("Button")
        deleteButton:SetText("Remove")
        deleteButton:SetWidth(80)
        deleteButton:SetCallback("OnClick", function()
            -- Use data provider for player operations
            local success = false
            if self.dataProvider then
                success = self.dataProvider.players:removePriorityPlayer(playerName)
            else
                -- Fallback to direct access
                addon.Config:RemovePriorityPlayer(playerName)
                success = true
            end
            
            if success then
                -- Refresh the display to show updated list
                self:refreshDisplay()
                -- Trigger callback to parent
                self:triggerCallback('onPlayerRemoved', playerName)
            end
        end)
        playerRowGroup:AddChild(deleteButton)
    end
end

-- AddPlayerForm Component
local AddPlayerForm = {}
setmetatable(AddPlayerForm, {__index = BaseComponent})

function AddPlayerForm:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("AddPlayerForm")
    return instance
end

function AddPlayerForm:buildUI()
    -- Add player editbox
    local addPlayerEdit = self.AceGUI:Create("EditBox")
    addPlayerEdit:SetLabel("Add Player")
    addPlayerEdit:SetWidth(200)
    
    local addPlayerFunction = function()
        local name = addPlayerEdit:GetText():trim()
        if name ~= "" then
            -- Use data provider for player operations
            local success = false
            if self.dataProvider then
                success = self.dataProvider.players:addPriorityPlayer(name)
            else
                -- Fallback to direct access
                addon.Config:AddPriorityPlayer(name)
                success = true
            end
            
            if success then
                addPlayerEdit:SetText("")
                -- Trigger callback to parent
                self:triggerCallback('onPlayerAdded', name)
            end
        end
    end
    
    addPlayerEdit:SetCallback("OnEnterPressed", addPlayerFunction)
    self.container:AddChild(addPlayerEdit)
    
    -- Add player button
    local addButton = self.AceGUI:Create("Button")
    addButton:SetText("Add")
    addButton:SetWidth(80)
    addButton:SetCallback("OnClick", addPlayerFunction)
    self.container:AddChild(addButton)
end

-- RemovePlayerForm Component
local RemovePlayerForm = {}
setmetatable(RemovePlayerForm, {__index = BaseComponent})

function RemovePlayerForm:new(container, callbacks, dataProvider)
    local instance = BaseComponent:new(container, callbacks, dataProvider)
    setmetatable(instance, {__index = self})
    instance:validateImplementation("RemovePlayerForm")
    return instance
end

function RemovePlayerForm:buildUI()
    -- Remove player editbox
    local removePlayerEdit = self.AceGUI:Create("EditBox")
    removePlayerEdit:SetLabel("Remove Player")
    removePlayerEdit:SetWidth(200)
    
    local removePlayerFunction = function()
        local name = removePlayerEdit:GetText():trim()
        if name ~= "" then
            -- Use data provider for player operations
            local success = false
            if self.dataProvider then
                success = self.dataProvider.players:removePriorityPlayer(name)
            else
                -- Fallback to direct access
                addon.Config:RemovePriorityPlayer(name)
                success = true
            end
            
            if success then
                removePlayerEdit:SetText("")
                -- Trigger callback to parent
                self:triggerCallback('onPlayerRemoved', name)
            end
        end
    end
    
    removePlayerEdit:SetCallback("OnEnterPressed", removePlayerFunction)
    self.container:AddChild(removePlayerEdit)
    
    -- Remove player button
    local removeButton = self.AceGUI:Create("Button")
    removeButton:SetText("Remove")
    removeButton:SetWidth(80)
    removeButton:SetCallback("OnClick", removePlayerFunction)
    self.container:AddChild(removeButton)
end

-- Register components in addon namespace
addon.Components.PriorityPlayersList = PriorityPlayersList
addon.Components.AddPlayerForm = AddPlayerForm
addon.Components.RemovePlayerForm = RemovePlayerForm