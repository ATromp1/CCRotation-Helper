local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local DisplayTab = {}

-- Create Display tab content using component-based architecture
function DisplayTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Validate DataManager is available
    if not addon.Components or not addon.Components.DataManager then
        error("DataManager not loaded. Make sure UI/Components/DataManager.lua is loaded first.")
    end
    
    -- Load display settings component
    if not addon.Components or not addon.Components.DisplaySettings then
        error("DisplaySettings component not loaded. Make sure UI/Components/DisplaySettings.lua is loaded first.")
    end
    
    -- Display Settings Section
    local displayGroup = addon.BaseComponent:createInlineGroup("Display Settings", scroll)
    local displaySettings = addon.Components.DisplaySettings:new(displayGroup, {})
    displaySettings:buildUI()
end

-- Register the tab module
addon.DisplayTabModule = DisplayTab

return DisplayTab