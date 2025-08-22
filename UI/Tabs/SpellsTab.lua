local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local SpellsTab = {}

-- Create Spells tab content using component-based architecture
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
    
    -- Create data provider for components
    local dataProvider = addon.DataProviders and addon.DataProviders.Spells
    
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
    
    -- Create component reference first (forward declaration pattern)
    local unifiedSpellsList
    
    unifiedSpellsList = addon.Components.UnifiedSpellsList:new(spellListGroup, {
        onSpellMoved = function(spellID, direction)
            -- Targeted refresh: refresh the unified spells component and queue display
            unifiedSpellsList:refreshUI()
            if refreshQueueDisplay then
                refreshQueueDisplay()
            end
        end,
        onSpellEdited = function(spellID, field, value)
            -- Simple edits don't need full refresh, but queue display might need update
            if refreshQueueDisplay then
                refreshQueueDisplay()
            end
        end,
        onSpellIDChanged = function(oldSpellID, newSpellID, spellData)
            -- Use data provider to handle spell ID change
            if dataProvider and dataProvider.changeSpellID then
                local success, errorMsg = dataProvider:changeSpellID(oldSpellID, newSpellID)
                if success then
                    -- Spell ID changes are complex, require full tab refresh
                    container:ReleaseChildren()
                    SpellsTab.create(container)
                else
                    -- Show error message if the change failed
                    addon.Config:DebugPrint("Failed to change spell ID:", errorMsg)
                end
            else
                -- Fallback to old behavior if data provider doesn't support it
                container:ReleaseChildren()
                SpellsTab.create(container)
            end
        end,
        onSpellDisabled = function(spellID)
            -- Targeted refresh: refresh unified spells component and queue display
            unifiedSpellsList:refreshUI()
            if refreshQueueDisplay then
                refreshQueueDisplay()
            end
            
            -- Force layout refresh on the main scroll container to handle size changes
            if scroll and scroll.DoLayout then
                scroll:DoLayout()
            end
        end,
        onSpellEnabled = function(spellID)
            -- Targeted refresh: refresh unified spells component and queue display
            unifiedSpellsList:refreshUI()
            if refreshQueueDisplay then
                refreshQueueDisplay()
            end
            
            -- Force layout refresh on the main scroll container to handle size changes
            if scroll and scroll.DoLayout then
                scroll:DoLayout()
            end
        end,
        onSpellDeleted = function(spellID)
            -- Targeted refresh: refresh unified spells component
            unifiedSpellsList:refreshUI()
        end
    }, dataProvider)
    
    -- Store component reference for cleanup
    container.spellsTabComponents.unifiedSpellsList = unifiedSpellsList
    
    -- Initialize the component
    unifiedSpellsList:buildUI()
    
    -- Add the management sections (add spell form)
    SpellsTab.createManagementSections(scroll, container, unifiedSpellsList, refreshQueueDisplay)
end

-- Create spell management sections (add spell form only - disabled spells are now integrated)
function SpellsTab.createManagementSections(scroll, container, unifiedSpellsList, refreshQueueDisplay)
    -- Get data provider for components
    local dataProvider = addon.DataProviders and addon.DataProviders.Spells
    -- COMPONENT-BASED: Add new spell section using AddSpellForm component
    local addSpellGroup = addon.BaseComponent:createInlineGroup("Add Custom Spell", scroll)
    
    -- Load and create AddSpellForm component  
    if not addon.Components or not addon.Components.AddSpellForm then
        error("AddSpellForm component not loaded. Make sure UI/Components/SpellsList.lua is loaded first.")
    end
    
    local addSpellForm = addon.Components.AddSpellForm:new(addSpellGroup, {
        onSpellAdded = function(spellID)
            -- Targeted refresh: refresh the unified spells list to show new spell
            if unifiedSpellsList then
                unifiedSpellsList:refreshUI()
            end
            -- Also update queue display since active spells changed
            if refreshQueueDisplay then
                refreshQueueDisplay()
            end
            
            -- Force layout refresh on scroll container to handle size changes
            if scroll and scroll.DoLayout then
                scroll:DoLayout()
            end
        end
    }, dataProvider)
    
    -- Store component reference for cleanup
    container.spellsTabComponents.addSpellForm = addSpellForm
    
    -- Initialize the component
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