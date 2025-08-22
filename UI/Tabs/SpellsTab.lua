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

    -- Current tracked spells display using TrackedSpellsList component
    local spellListGroup = addon.BaseComponent:createInlineGroup("Currently Tracked Spells", scroll)
    
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
            -- This will be overridden after disabledSpellsList is created
            -- Placeholder callback for initial component creation
        end
    }, dataProvider)
    
    -- Store component reference for cleanup
    container.spellsTabComponents.trackedSpellsList = trackedSpellsList
    
    -- Initialize the component
    trackedSpellsList:buildUI()
    
    -- Add the management sections (add/inactive spells) and get disabledSpellsList reference
    local disabledSpellsList = SpellsTab.createManagementSections(scroll, container, trackedSpellsList, refreshQueueDisplay)
    
    -- Store additional components for cleanup
    if disabledSpellsList then
        container.spellsTabComponents.disabledSpellsList = disabledSpellsList
    end
    
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
    local addSpellGroup = addon.BaseComponent:createInlineGroup("Add Custom Spell", scroll)
    
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
    
    -- Store component reference for cleanup
    container.spellsTabComponents.addSpellForm = addSpellForm
    
    -- Initialize the component
    addSpellForm:buildUI()
    
    -- Disabled spells section using DisabledSpellsList component
    local inactiveSpellsGroup = addon.BaseComponent:createInlineGroup("Disabled Spells", scroll)
    
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