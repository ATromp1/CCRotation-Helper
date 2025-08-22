local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local PlayersTab = {}

-- Create Players tab content using component-based architecture
function PlayersTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Validate DataManager is available
    if not addon.Components or not addon.Components.DataManager then
        error("DataManager not loaded. Make sure UI/Components/DataManager.lua is loaded first.")
    end
    local dataProvider = addon.Components.DataManager
    
    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("Players listed here will be prioritized in the rotation order.")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)
    
    -- Add player form using AddPlayerForm component (placed above the list)
    local addPlayerGroup = addon.BaseComponent:createInlineGroup("Add Priority Player", scroll)
    
    if not addon.Components or not addon.Components.AddPlayerForm then
        error("AddPlayerForm component not loaded. Make sure UI/Components/PlayersList.lua is loaded first.")
    end
    
    -- Forward declaration for priorityPlayersList
    local priorityPlayersList
    
    local addPlayerForm = addon.Components.AddPlayerForm:new(addPlayerGroup, {
        onPlayerAdded = function(playerName)
            -- Refresh the priority players display
            if priorityPlayersList and priorityPlayersList.refreshDisplay then
                priorityPlayersList:refreshDisplay()
            end
        end
    }, dataProvider)
    
    addPlayerForm:buildUI()
    
    -- Current priority players display using PriorityPlayersList component
    local priorityPlayersGroup = addon.BaseComponent:createInlineGroup("Priority Players", scroll)
    
    if not addon.Components or not addon.Components.PriorityPlayersList then
        error("PriorityPlayersList component not loaded. Make sure UI/Components/PlayersList.lua is loaded first.")
    end
    
    priorityPlayersList = addon.Components.PriorityPlayersList:new(priorityPlayersGroup, {}, dataProvider)
    priorityPlayersList:buildUI()
end

-- Register PlayersTab module for ConfigFrame to load
addon.PlayersTabModule = PlayersTab

return PlayersTab