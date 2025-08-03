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
    
    -- Create data provider for components
    local dataProvider = addon.DataProviders and addon.DataProviders.Config
    if not dataProvider then
        error("ConfigDataProvider not loaded. Make sure UI/Components/ConfigDataProvider.lua is loaded first.")
    end
    
    -- Load icon settings component
    if not addon.Components or not addon.Components.IconSettings then
        error("IconSettings component not loaded. Make sure UI/Components/IconSettings.lua is loaded first.")
    end
    
    -- Load glow settings component
    if not addon.Components or not addon.Components.GlowSettings then
        error("GlowSettings component not loaded. Make sure UI/Components/GlowSettings.lua is loaded first.")
    end
    
    -- Icon Settings Section
    local iconGroup = addon.BaseComponent:createInlineGroup("Icon Settings", scroll)
    local iconSettings = addon.Components.IconSettings:new(iconGroup, {})
    iconSettings:buildUI()
    
    -- Glow Settings Section (component creates its own header)
    local glowGroup = addon.BaseComponent:createInlineGroup("", scroll)
    local glowSettings = addon.Components.GlowSettings:new(glowGroup, {})
    glowSettings:buildUI()
end

-- Register the tab module
addon.IconsTabModule = IconsTab

return IconsTab