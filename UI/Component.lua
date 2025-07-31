local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

addon.UI.Component = {}

--- Create a horizontal spacer
--- @param width number
function addon.UI.Component:HorizontalSpacer(width)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(width)

    return spacer
end
