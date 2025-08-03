-- IconSettings.lua - Component for basic icon configuration settings
-- Handles icon zoom, max icons, and individual icon size controls

local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

local IconSettings = {}
setmetatable(IconSettings, {__index = addon.BaseComponent})

function IconSettings:new(container, callbacks)
    local instance = addon.BaseComponent:new(container, callbacks, addon.DataProviders.Config)
    setmetatable(instance, {__index = self})
    
    -- Store references to AceGUI widgets for show/hide logic
    instance.iconSizeWidgets = {}
    
    return instance
end

function IconSettings:buildUI()
    -- Icon zoom slider
    local iconZoomSlider = addon.Components.SliderControl:new(
        self.container,
        "Icon Zoom (Texture scale within frame)",
        "iconZoom",
        0.3, 3.0, 0.1,
        {
            onValueChanged = function()
                self.dataProvider:refreshDisplay()
            end
        }
    )
    iconZoomSlider:buildUI()
    
    -- Max icons slider with special handling for dynamic controls
    local maxIconsSlider = AceGUI:Create("Slider")
    maxIconsSlider:SetLabel("Max Icons")
    maxIconsSlider:SetSliderValues(1, 5, 1)
    maxIconsSlider:SetValue(self.dataProvider:get("maxIcons"))
    maxIconsSlider:SetFullWidth(true)
    self.container:AddChild(maxIconsSlider)
    
    -- Individual icon size controls (create AceGUI widgets directly for show/hide)
    for i = 1, 5 do
        local iconSlider = self.AceGUI:Create("Slider")
        iconSlider:SetLabel("Icon " .. i .. " Size")
        iconSlider:SetSliderValues(16, 128, 1)
        iconSlider:SetValue(self.dataProvider:get("iconSize" .. i))
        iconSlider:SetCallback("OnValueChanged", function(widget, event, value)
            self.dataProvider:set("iconSize" .. i, value)
            self.dataProvider:refreshDisplay()
        end)
        iconSlider:SetFullWidth(true)
        self.container:AddChild(iconSlider)
        self.iconSizeWidgets[i] = iconSlider
        
        -- Initially hide controls beyond maxIcons
        if i > self.dataProvider:get("maxIcons") then
            iconSlider.frame:Hide()
        end
    end
    
    -- Set max icons callback after creating individual controls
    maxIconsSlider:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider:set("maxIcons", value)
        
        -- Show/hide icon controls based on maxIcons
        for i = 1, 5 do
            if self.iconSizeWidgets[i] then
                if i <= value then
                    self.iconSizeWidgets[i].frame:Show()
                else
                    self.iconSizeWidgets[i].frame:Hide()
                end
            end
        end
        
        self.dataProvider:refreshDisplay()
    end)
end

-- Register component
if not addon.Components then
    addon.Components = {}
end
addon.Components.IconSettings = IconSettings

return IconSettings