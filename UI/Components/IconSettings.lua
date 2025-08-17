-- IconSettings.lua - Component for basic icon configuration settings
-- Handles icon zoom, max icons, and individual icon size controls

local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

local BaseComponent = addon.BaseComponent
local IconSettings = {}
setmetatable(IconSettings, {__index = BaseComponent})

function IconSettings:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.DataProviders.Config)
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
    maxIconsSlider:SetValue(self.dataProvider:get("maxIcons") or 2)
    maxIconsSlider:SetFullWidth(true)
    self.container:AddChild(maxIconsSlider)
    
    -- Individual icon size controls (create AceGUI widgets directly for show/hide)
    for i = 1, 5 do
        local iconSlider = self.AceGUI:Create("Slider")
        iconSlider:SetLabel("Icon " .. i .. " Size")
        iconSlider:SetSliderValues(16, 128, 1)
        local iconSizeValue = self.dataProvider:get("iconSize" .. i) or 64
        iconSlider:SetValue(iconSizeValue)
        
        -- Fix closure issue - capture i in local scope
        local iconIndex = i
        iconSlider:SetCallback("OnValueChanged", function(widget, event, value)
            self.dataProvider:set("iconSize" .. iconIndex, value)
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
    
    -- Unavailable Queue Settings Header
    local unavailableHeader = self.AceGUI:Create("Heading")
    unavailableHeader:SetText("Unavailable Queue Settings")
    unavailableHeader:SetFullWidth(true)
    self.container:AddChild(unavailableHeader)
    
    -- Show unavailable queue
    local showUnavailableControl = addon.Components.CheckboxControl:new(
        self.container,
        "Show unavailable queue (dead/out of range players)",
        "showUnavailableQueue",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
                -- Update config preview if active
                if addon.UI and addon.UI.showConfigPreview then
                    addon.UI:showConfigPreview()
                end
            end
        }
    )
    showUnavailableControl:buildUI()
    
    -- Unavailable queue positioning mode
    local positioningModeDropdown = self.AceGUI:Create("Dropdown")
    positioningModeDropdown:SetLabel("Positioning Mode")
    positioningModeDropdown:SetWidth(200)
    positioningModeDropdown:SetList({
        ["relative"] = "Relative to main queue",
        ["independent"] = "Independent positioning"
    })
    positioningModeDropdown:SetValue(self.dataProvider:get("unavailableQueuePositioning"))
    positioningModeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider:set("unavailableQueuePositioning", value)
        self.dataProvider:refreshDisplay()
        -- Update config preview if active
        if addon.UI and addon.UI.showConfigPreview then
            addon.UI:showConfigPreview()
        end
    end)
    self.container:AddChild(positioningModeDropdown)
    
    -- Unavailable queue X offset
    local unavailableXControl = addon.Components.SliderControl:new(
        self.container,
        "Horizontal offset",
        "unavailableQueueX",
        -500, 500, 1,
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
                -- Update config preview if active
                if addon.UI and addon.UI.showConfigPreview then
                    addon.UI:showConfigPreview()
                end
            end
        }
    )
    unavailableXControl:buildUI()
    
    -- Unavailable queue Y offset
    local unavailableYControl = addon.Components.SliderControl:new(
        self.container,
        "Vertical offset",
        "unavailableQueueY",
        -500, 500, 1,
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
                -- Update config preview if active
                if addon.UI and addon.UI.showConfigPreview then
                    addon.UI:showConfigPreview()
                end
            end
        }
    )
    unavailableYControl:buildUI()
    
    -- Reset unavailable queue position button
    local resetUnavailableBtn = self.AceGUI:Create("Button")
    resetUnavailableBtn:SetText("Reset Position")
    resetUnavailableBtn:SetWidth(150)
    resetUnavailableBtn:SetCallback("OnClick", function()
        self.dataProvider:set("unavailableQueueX", 0)
        self.dataProvider:set("unavailableQueueY", -30)
        self.dataProvider:set("unavailableQueueAnchorPoint", "TOP")
        self.dataProvider:set("unavailableQueueRelativePoint", "BOTTOM")
        self.dataProvider:refreshDisplay()
        -- Update config preview if active
        if addon.UI and addon.UI.showConfigPreview then
            addon.UI:showConfigPreview()
        end
        print("|cff00ff00CC Rotation Helper|r: Unavailable queue position reset")
    end)
    self.container:AddChild(resetUnavailableBtn)
end

-- Register component
if not addon.Components then
    addon.Components = {}
end
addon.Components.IconSettings = IconSettings

return IconSettings