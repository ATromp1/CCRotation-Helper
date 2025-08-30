local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local IconsTab = {}

-- Create Icons tab content using component-based architecture
function IconsTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Validate DataManager is available
    if not addon.Components or not addon.Components.DataManager then
        error("DataManager not loaded. Make sure UI/Components/DataManager.lua is loaded first.")
    end
    
    -- Load icon settings component
    if not addon.Components or not addon.Components.IconSettings then
        error("IconSettings component not loaded. Make sure UI/Components/IconSettings.lua is loaded first.")
    end
    
    -- Icon Settings Section
    local iconGroup = addon.BaseComponent:createInlineGroup("Icon Settings", scroll)
    local iconSettings = addon.Components.IconSettings:new(iconGroup, {})
    iconSettings:buildUI()
end

-- Register the tab module
addon.IconsTabModule = IconsTab

return IconsTab