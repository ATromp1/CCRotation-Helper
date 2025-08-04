local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local AboutTab = {}

-- Create About tab content
function AboutTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- About Section
    local aboutGroup = AceGUI:Create("InlineGroup")
    aboutGroup:SetTitle("About CC Rotation Helper")
    aboutGroup:SetFullWidth(true)
    aboutGroup:SetLayout("Flow")
    scroll:AddChild(aboutGroup)
    
    -- Version Info
    local version = "Unknown"
    if GetAddOnMetadata then
        version = GetAddOnMetadata(addonName, "Version") or "Unknown"
    elseif C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
    end
    local versionLabel = AceGUI:Create("Label")
    versionLabel:SetText("|cff00ff00Version:|r " .. version)
    versionLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    versionLabel:SetFullWidth(true)
    aboutGroup:AddChild(versionLabel)
    
    -- Spacer
    local spacer1 = AceGUI:Create("Label")
    spacer1:SetText(" ")
    spacer1:SetFullWidth(true)
    aboutGroup:AddChild(spacer1)
    
    -- Creator Info
    local creatorLabel = AceGUI:Create("Label")
    creatorLabel:SetText("|cff00ff00Created by:|r Furo")
    creatorLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    creatorLabel:SetFullWidth(true)
    aboutGroup:AddChild(creatorLabel)
    
    -- Spacer
    local spacer2 = AceGUI:Create("Label")
    spacer2:SetText(" ")
    spacer2:SetFullWidth(true)
    aboutGroup:AddChild(spacer2)
    
    -- Major Contributors
    local contributorsLabel = AceGUI:Create("Label")
    contributorsLabel:SetText("|cff00ff00Major Contributors:|r Malpam")
    contributorsLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    contributorsLabel:SetFullWidth(true)
    aboutGroup:AddChild(contributorsLabel)
    
    -- Spacer
    local spacer3 = AceGUI:Create("Label")
    spacer3:SetText(" ")
    spacer3:SetFullWidth(true)
    aboutGroup:AddChild(spacer3)
    
    -- Contact Info
    local contactLabel = AceGUI:Create("Label")
    contactLabel:SetText("|cff00ff00Contact:|r For bugs or questions, reach out on Discord: |cff00ccffrealfuro|r")
    contactLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    contactLabel:SetFullWidth(true)
    aboutGroup:AddChild(contactLabel)
    
    -- Spacer
    local spacer4 = AceGUI:Create("Label")
    spacer4:SetText(" ")
    spacer4:SetFullWidth(true)
    aboutGroup:AddChild(spacer4)
    
    -- Credits Section
    local creditsGroup = AceGUI:Create("InlineGroup")
    creditsGroup:SetTitle("Credits & Libraries")
    creditsGroup:SetFullWidth(true)
    creditsGroup:SetLayout("Flow")
    scroll:AddChild(creditsGroup)
    
    local creditsText = AceGUI:Create("Label")
    creditsText:SetText("|cff00ff00Libraries Used:|r\n• Ace3 Framework (AceAddon, AceConfig, AceDB, AceGUI)\n• LibOpenRaid (cooldown tracking)\n• LibDBIcon (minimap integration)\n• LibCustomGlow (visual effects)\n• LibSharedMedia (fonts and media)")
    creditsText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    creditsText:SetFullWidth(true)
    creditsGroup:AddChild(creditsText)
end

-- Register the tab module
addon.AboutTabModule = AboutTab

return AboutTab