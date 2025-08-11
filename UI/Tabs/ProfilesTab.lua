local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local ProfilesTab = {}

-- Create Profiles tab content using component-based architecture
function ProfilesTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Create data provider for components
    local dataProvider = addon.DataProviders and addon.DataProviders.Profiles
    if not dataProvider then
        error("ProfilesDataProvider not loaded. Make sure UI/Components/ProfilesDataProvider.lua is loaded first.")
    end
    
    -- Load profile components
    if not addon.Components or not addon.Components.ProfileManagement then
        error("Profile components not loaded. Make sure UI/Components/ProfilesList.lua is loaded first.")
    end
    
    -- Profile Management Section
    local profileGroup = addon.BaseComponent:createInlineGroup("Profile Management", scroll)
    local profileManagement = addon.Components.ProfileManagement:new(profileGroup, {})
    profileManagement:buildUI()
end

-- Register the tab module
addon.ProfilesTabModule = ProfilesTab

return ProfilesTab