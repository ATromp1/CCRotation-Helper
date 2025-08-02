local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local SpellsTab = {}

-- Create Spells tab content using component-based architecture
function SpellsTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
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
    
    -- Initialize the component
    queueDisplayComponent:buildUI()
    
    -- Store reference for other components to trigger queue refresh
    local refreshQueueDisplay = function()
        if queueDisplayComponent and queueDisplayComponent.refreshQueueDisplay then
            queueDisplayComponent:refreshQueueDisplay()
        end
    end

    -- Current tracked spells display using TrackedSpellsList component
    local spellListGroup = AceGUI:Create("InlineGroup")
    spellListGroup:SetTitle("Currently Tracked Spells")
    spellListGroup:SetFullWidth(true)
    spellListGroup:SetLayout("Flow")
    scroll:AddChild(spellListGroup)
    
    -- Load and create TrackedSpellsList component
    if not addon.Components or not addon.Components.TrackedSpellsList then
        error("TrackedSpellsList component not loaded. Make sure UI/Components/SpellsList.lua is loaded first.")
    end
    
    -- Create component reference first (forward declaration pattern)
    local trackedSpellsList
    
    trackedSpellsList = addon.Components.TrackedSpellsList:new(spellListGroup, {
        onSpellMoved = function(spellID, direction)
            -- Targeted refresh: refresh the tracked spells component and queue display
            trackedSpellsList:refresh()
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
            -- Spell ID changes are complex, require full tab refresh
            container:ReleaseChildren()
            SpellsTab.create(container)
        end,
        onSpellDisabled = function(spellID)
            -- This will be overridden after disabledSpellsList is created
            -- Placeholder callback for initial component creation
        end
    }, dataProvider)
    
    -- Initialize the component
    trackedSpellsList:buildUI()
    
    -- Add the management sections (add/inactive spells) and get disabledSpellsList reference
    local disabledSpellsList = SpellsTab.createManagementSections(scroll, container, trackedSpellsList, refreshQueueDisplay)
    
    -- Now update the TrackedSpellsList callback to also refresh DisabledSpellsList
    -- Note: We need to update the callback after both components are created
    local originalCallbacks = trackedSpellsList.callbacks
    trackedSpellsList.callbacks.onSpellDisabled = function(spellID)
        -- Targeted refresh: refresh both tracked spells component and disabled spells list
        trackedSpellsList:refresh()
        if disabledSpellsList then
            disabledSpellsList:refresh()
        end
        if refreshQueueDisplay then
            refreshQueueDisplay()
        end
        
        -- Force layout refresh on the main scroll container to handle size changes
        if scroll and scroll.DoLayout then
            scroll:DoLayout()
        end
    end
end

-- Create spell management sections (add/disabled spells)
function SpellsTab.createManagementSections(scroll, container, trackedSpellsList, refreshQueueDisplay)
    -- Get data provider for components
    local dataProvider = addon.DataProviders and addon.DataProviders.Spells
    -- COMPONENT-BASED: Add new spell section using AddSpellForm component
    local addSpellGroup = AceGUI:Create("InlineGroup")
    addSpellGroup:SetTitle("Add Custom Spell")
    addSpellGroup:SetFullWidth(true)
    addSpellGroup:SetLayout("Flow")
    scroll:AddChild(addSpellGroup)
    
    -- Load and create AddSpellForm component  
    if not addon.Components or not addon.Components.AddSpellForm then
        error("AddSpellForm component not loaded. Make sure UI/Components/SpellsList.lua is loaded first.")
    end
    
    local addSpellForm = addon.Components.AddSpellForm:new(addSpellGroup, {
        onSpellAdded = function(spellID)
            -- Targeted refresh: refresh the tracked spells list to show new spell
            if trackedSpellsList then
                trackedSpellsList:refresh()
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
    
    -- Initialize the component
    addSpellForm:buildUI()
    
    -- Disabled spells section using DisabledSpellsList component
    local inactiveSpellsGroup = AceGUI:Create("InlineGroup")
    inactiveSpellsGroup:SetTitle("Disabled Spells")
    inactiveSpellsGroup:SetFullWidth(true)
    inactiveSpellsGroup:SetLayout("Flow")
    scroll:AddChild(inactiveSpellsGroup)
    
    -- Load and create DisabledSpellsList component
    if not addon.Components or not addon.Components.DisabledSpellsList then
        error("DisabledSpellsList component not loaded. Make sure UI/Components/SpellsList.lua is loaded first.")
    end
    
    -- Create component reference first
    local disabledSpellsList
    
    disabledSpellsList = addon.Components.DisabledSpellsList:new(inactiveSpellsGroup, {
        onSpellEnabled = function(spellID)
            -- Targeted refresh: refresh both disabled spells and tracked spells
            disabledSpellsList:refresh()
            if trackedSpellsList then
                trackedSpellsList:refresh()
            end
            -- Also update queue display since active spells changed
            if refreshQueueDisplay then
                refreshQueueDisplay()
            end
            
            -- Force layout refresh on scroll container to handle size changes
            if scroll and scroll.DoLayout then
                scroll:DoLayout()
            end
        end,
        onSpellDeleted = function(spellID)
            -- Targeted refresh: only refresh the disabled spells component
            disabledSpellsList:refresh()
        end
    }, dataProvider)
    
    -- Initialize the component
    disabledSpellsList:buildUI()
    
    -- Help text for spell management
    local manageHelpText = AceGUI:Create("Label")
    manageHelpText:SetText("Use Up/Down buttons to reorder spells. Use Disable button to temporarily remove spells from rotation. Use Enable button to restore disabled spells.")
    manageHelpText:SetFullWidth(true)
    scroll:AddChild(manageHelpText)
    
    -- Return the disabledSpellsList reference for cross-component communication
    return disabledSpellsList
end

-- Register SpellsTab module for ConfigFrame to load
addon.SpellsTabModule = SpellsTab

return SpellsTab