local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local SpellsTab = {}

function SpellsTab.create(container)
    -- Clean up any existing components to prevent duplicates
    if container.spellsTabComponents then
        for _, component in pairs(container.spellsTabComponents) do
            if component.Cleanup then
                component:Cleanup()
            end
        end
        container.spellsTabComponents = nil
    end
    
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Initialize component tracking
    container.spellsTabComponents = {}
    
    -- Validate DataManager is available
    if not addon.Components or not addon.Components.DataManager then
        error("DataManager not loaded. Make sure UI/Components/DataManager.lua is loaded first.")
    end
    local dataProvider = addon.Components.DataManager
    
    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("Manage which spells are tracked in the rotation.")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)
    
    -- Queue display with integrated filters using QueueDisplayComponent
    local queueDisplayGroup = AceGUI:Create("SimpleGroup")
    queueDisplayGroup:SetFullWidth(true)
    queueDisplayGroup:SetLayout("Flow")
    scroll:AddChild(queueDisplayGroup)
    
    -- Load and create QueueDisplayComponent
    if not addon.Components or not addon.Components.QueueDisplayComponent then
        error("QueueDisplayComponent not loaded. Make sure UI/Components/SpellsList.lua is loaded first.")
    end
    
    local queueDisplayComponent = addon.Components.QueueDisplayComponent:new(queueDisplayGroup, {}, dataProvider)
    
    -- Store component reference for cleanup
    container.spellsTabComponents.queueDisplayComponent = queueDisplayComponent
    
    -- Initialize the component
    queueDisplayComponent:buildUI()
    
    -- Store reference for other components to trigger queue refresh
    local refreshQueueDisplay = function()
        if queueDisplayComponent and queueDisplayComponent.refreshQueueDisplay then
            queueDisplayComponent:refreshQueueDisplay()
        end
    end

    -- Unified spells display using UnifiedSpellsList component
    local spellListGroup = addon.BaseComponent:createInlineGroup("All Spells", scroll)
    
    -- Load and create UnifiedSpellsList component
    if not addon.Components or not addon.Components.UnifiedSpellsList then
        error("UnifiedSpellsList component not loaded. Make sure UI/Components/SpellsList.lua is loaded first.")
    end
    
    -- Helper function for common refresh operations
    local function refreshComponents(includeLayout)
        if refreshQueueDisplay then
            refreshQueueDisplay()
        end
        if includeLayout and scroll and scroll.DoLayout then
            scroll:DoLayout()
        end
    end
    
    -- Create component reference first (forward declaration pattern)
    local unifiedSpellsList
    
    unifiedSpellsList = addon.Components.UnifiedSpellsList:new(spellListGroup, {
        onSpellMoved = function(spellID, direction)
            unifiedSpellsList:refreshUI()
            refreshComponents(false)
        end,
        onSpellEdited = function(spellID, field, value)
            refreshComponents(false)
        end,
        onSpellIDChanged = function(oldSpellID, newSpellID, spellData)
            if dataProvider and dataProvider.changeSpellID then
                local success, errorMsg = dataProvider:changeSpellID(oldSpellID, newSpellID)
                if success then
                    container:ReleaseChildren()
                    SpellsTab.create(container)
                else
                    addon.Config:DebugPrint("Failed to change spell ID:", errorMsg)
                end
            else
                container:ReleaseChildren()
                SpellsTab.create(container)
            end
        end,
        onSpellDisabled = function(spellID)
            unifiedSpellsList:refreshUI()
            refreshComponents(true)
        end,
        onSpellEnabled = function(spellID)
            unifiedSpellsList:refreshUI()
            refreshComponents(true)
        end,
        onSpellDeleted = function(spellID)
            unifiedSpellsList:refreshUI()
        end
    }, dataProvider)
    
    -- Store component reference for cleanup
    container.spellsTabComponents.unifiedSpellsList = unifiedSpellsList
    
    -- Initialize the component
    unifiedSpellsList:buildUI()
    
    -- Add spell form section
    local addSpellGroup = addon.BaseComponent:createInlineGroup("Add Custom Spell", scroll)
    
    if not addon.Components or not addon.Components.AddSpellForm then
        error("AddSpellForm component not loaded. Make sure UI/Components/SpellsList.lua is loaded first.")
    end
    
    local addSpellForm = addon.Components.AddSpellForm:new(addSpellGroup, {
        onSpellAdded = function(spellID)
            if unifiedSpellsList then
                unifiedSpellsList:refreshUI()
            end
            refreshComponents(true)
        end
    }, dataProvider)
    
    container.spellsTabComponents.addSpellForm = addSpellForm
    addSpellForm:buildUI()
    
    -- Help text for spell management
    local manageHelpText = AceGUI:Create("Label")
    manageHelpText:SetText("Use Up/Down buttons to reorder spells by priority. Use Enable/Disable buttons to toggle spells in-place while keeping their priority position. Disabled spells appear grayed out with reduced opacity. Use Delete button to permanently remove custom spells.")
    manageHelpText:SetFullWidth(true)
    scroll:AddChild(manageHelpText)
end

-- Register SpellsTab module for ConfigFrame to load
addon.SpellsTabModule = SpellsTab

return SpellsTab