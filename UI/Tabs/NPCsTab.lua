local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local NPCsTab = {}

-- Create NPCs tab content using component-based architecture
function NPCsTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Create data provider for components
    local dataProvider = addon.DataProviders and addon.DataProviders.NPCs
    
    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("Manage NPC crowd control effectiveness. Configure which types of CC work on each NPC.")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)
    
    -- Current location and filtering using CurrentLocationComponent
    local currentLocationGroup = addon.BaseComponent:createInlineGroup("Current Location", scroll)
    
    if not addon.Components or not addon.Components.CurrentLocationComponent then
        error("CurrentLocationComponent not loaded. Make sure UI/Components/NPCsList.lua is loaded first.")
    end
    
    -- Forward declarations for cross-component communication
    local dungeonNPCList
    
    local currentLocationComponent = addon.Components.CurrentLocationComponent:new(currentLocationGroup, {
        onFilterChanged = function(filterToDungeon)
            -- Update filter and refresh dungeon list
            if dungeonNPCList then
                dungeonNPCList:setFilter(filterToDungeon)
                dungeonNPCList:buildUI()
            end
        end,
        onLocationRefresh = function()
            -- Refresh entire tab
            container:ReleaseChildren()
            NPCsTab.create(container)
        end
    }, dataProvider)
    
    currentLocationComponent:buildUI()
    
    -- NPC list grouped by dungeon using DungeonNPCListComponent
    local dungeonNPCGroup = addon.BaseComponent:createInlineGroup("NPCs by Dungeon", scroll)
    
    if not addon.Components or not addon.Components.DungeonNPCListComponent then
        error("DungeonNPCListComponent not loaded. Make sure UI/Components/NPCsList.lua is loaded first.")
    end
    
    dungeonNPCList = addon.Components.DungeonNPCListComponent:new(dungeonNPCGroup, {
        onDungeonToggle = function(dungeonName)
            -- Refresh to show/hide dungeon content
            dungeonNPCList:buildUI()
        end,
        onNPCChanged = function(npcID)
            -- Refresh dungeon list to show changes
            dungeonNPCList:buildUI()
        end,
        onNPCDungeonChanged = function(npcID)
            -- Full refresh needed when NPC changes dungeon (regroup)
            container:ReleaseChildren()
            NPCsTab.create(container)
        end
    }, dataProvider)
    
    dungeonNPCList:buildUI()
    
    -- Quick NPC lookup using NPCSearchComponent
    local lookupGroup = addon.BaseComponent:createInlineGroup("Quick NPC Lookup", scroll)
    
    if not addon.Components or not addon.Components.NPCSearchComponent then
        error("NPCSearchComponent not loaded. Make sure UI/Components/NPCsList.lua is loaded first.")
    end
    
    local npcSearchComponent = addon.Components.NPCSearchComponent:new(lookupGroup, {
        onExpandDungeon = function(dungeonName)
            -- Expand the dungeon in the NPC list
            if dungeonNPCList then
                dungeonNPCList:expandDungeon(dungeonName)
                dungeonNPCList:buildUI()
            end
        end
    }, dataProvider)
    
    npcSearchComponent:buildUI()
    
    -- Add custom NPC using AddNPCComponent
    local addNPCGroup = addon.BaseComponent:createInlineGroup("Add Custom NPC", scroll)
    
    if not addon.Components or not addon.Components.AddNPCComponent then
        error("AddNPCComponent not loaded. Make sure UI/Components/NPCsList.lua is loaded first.")
    end
    
    local addNPCComponent = addon.Components.AddNPCComponent:new(addNPCGroup, {
        onNPCAdded = function(npcID)
            -- Refresh entire tab to show new NPC
            container:ReleaseChildren()
            NPCsTab.create(container)
        end
    }, dataProvider)
    
    addNPCComponent:buildUI()
    
    -- Help text for NPC management
    local manageHelpText = AceGUI:Create("Label")
    manageHelpText:SetText("NPCs are grouped by dungeon with Expand/Collapse buttons. Current Location shows where you are and offers filtering. 'Find Target in List' locates your target, 'Search NPCs' finds existing ones. 'Get from Target' auto-fills from your current target and detects dungeon. When in a dungeon, the addon auto-selects that dungeon for new NPCs. Use Reset to revert database NPCs, Delete to remove custom ones.")
    manageHelpText:SetFullWidth(true)
    scroll:AddChild(manageHelpText)
end

-- Register NPCsTab module for ConfigFrame to load
addon.NPCsTabModule = NPCsTab

return NPCsTab