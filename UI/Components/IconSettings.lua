-- IconSettings.lua - Component for basic icon configuration settings
-- Handles icon zoom, max icons, and individual icon size controls

local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

local BaseComponent = addon.BaseComponent
local IconSettings = {}
setmetatable(IconSettings, {__index = BaseComponent})

function IconSettings:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.Components.DataManager)
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
                if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
            end
        }
    )
    iconZoomSlider:buildUI()
    
    -- Max icons slider with special handling for dynamic controls
    local maxIconsSlider = AceGUI:Create("Slider")
    maxIconsSlider:SetLabel("Max Icons")
    maxIconsSlider:SetSliderValues(1, 3, 1)
    maxIconsSlider:SetValue(self.dataProvider.config:get("maxIcons") or 2)
    maxIconsSlider:SetFullWidth(true)
    self.container:AddChild(maxIconsSlider)
    
    -- Individual icon size controls (create AceGUI widgets directly for show/hide)
    for i = 1, 3 do
        local iconSlider = self.AceGUI:Create("Slider")
        iconSlider:SetLabel("Icon " .. i .. " Size")
        iconSlider:SetSliderValues(16, 128, 1)
        local iconSizeValue = self.dataProvider.config:get("iconSize" .. i) or 64
        iconSlider:SetValue(iconSizeValue)
        
        -- Fix closure issue - capture i in local scope
        local iconIndex = i
        iconSlider:SetCallback("OnValueChanged", function(widget, event, value)
            self.dataProvider.config:set("iconSize" .. iconIndex, value)
            if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
        end)
        
        iconSlider:SetFullWidth(true)
        
        -- Check if this control should be hidden before adding to container
        local maxIcons = self.dataProvider.config:get("maxIcons") or 2
        local shouldHide = i > maxIcons
        
        self.container:AddChild(iconSlider)
        self.iconSizeWidgets[i] = iconSlider
        
        -- Hide controls beyond maxIcons after UI renders
        if shouldHide then
            C_Timer.After(0.01, function()
                if iconSlider.frame then
                    iconSlider.frame:Hide()
                end
            end)
        end
    end
    
    -- Set max icons callback after creating individual controls
    maxIconsSlider:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider.config:set("maxIcons", value)
        
        -- Show/hide icon controls based on maxIcons
        for i = 1, 3 do
            if self.iconSizeWidgets[i] then
                if i <= value then
                    self.iconSizeWidgets[i].frame:Show()
                else
                    self.iconSizeWidgets[i].frame:Hide()
                end
            end
        end
        
        if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
end

-- Register component
if not addon.Components then
    addon.Components = {}
end
addon.Components.IconSettings = IconSettings

return IconSettings