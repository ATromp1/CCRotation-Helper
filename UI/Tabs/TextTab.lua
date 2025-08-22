local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local TextTab = {}

-- Create Text tab content using component-based architecture
function TextTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Validate DataManager is available
    if not addon.Components or not addon.Components.DataManager then
        error("DataManager not loaded. Make sure UI/Components/DataManager.lua is loaded first.")
    end
    
    -- Load text settings component
    if not addon.Components or not addon.Components.TextSettings then
        error("TextSettings component not loaded. Make sure UI/Components/TextSettings.lua is loaded first.")
    end
    
    -- Text Settings Section
    local textGroup = addon.BaseComponent:createInlineGroup("Text Settings", scroll)
    local textSettings = addon.Components.TextSettings:new(textGroup, {})
    textSettings:buildUI()
end

-- Register the tab module
addon.TextTabModule = TextTab

return TextTab