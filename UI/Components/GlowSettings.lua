-- GlowSettings.lua - Component for dynamic glow configuration settings
-- Handles glow type selection and type-specific controls that change dynamically

local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

local BaseComponent = addon.BaseComponent
local GlowSettings = {}
setmetatable(GlowSettings, {__index = BaseComponent})

function GlowSettings:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.Components.DataManager)
    setmetatable(instance, {__index = self})
    
    -- Container for dynamic controls
    instance.dynamicContainer = nil
    
    return instance
end

function GlowSettings:buildUI()
    -- Glow Settings Header
    local glowHeader = AceGUI:Create("Heading")
    glowHeader:SetText("Glow Settings")
    glowHeader:SetFullWidth(true)
    self.container:AddChild(glowHeader)
    
    -- Highlight Next checkbox
    local highlightNextCheck = addon.Components.CheckboxControl:new(
        self.container,
        "Highlight Player's First Spell",
        "highlightNext",
        {
            onValueChanged = function()
                if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
            end
        }
    )
    highlightNextCheck:buildUI()
    
    -- Glow Only In Combat checkbox
    local glowOnlyInCombatCheck = addon.Components.CheckboxControl:new(
        self.container,
        "Only Show Glow In Combat",
        "glowOnlyInCombat",
        {
            onValueChanged = function()
                if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
            end
        }
    )
    glowOnlyInCombatCheck:buildUI()
    
    -- Glow Type dropdown
    local glowTypeDropdown = AceGUI:Create("Dropdown")
    glowTypeDropdown:SetLabel("Glow Type")
    glowTypeDropdown:SetList({
        Pixel = "Pixel Glow",
        ACShine = "Autocast Shine",
        Proc = "Proc Glow"
    })
    glowTypeDropdown:SetValue(self.dataProvider.config:get("glowType"))
    self.container:AddChild(glowTypeDropdown)
    
    -- Container for dynamic controls
    self.dynamicContainer = AceGUI:Create("SimpleGroup")
    self.dynamicContainer:SetFullWidth(true)
    self.dynamicContainer:SetLayout("Flow")
    self.container:AddChild(self.dynamicContainer)
    
    -- Build initial dynamic controls
    self:rebuildGlowControls(self.dataProvider.config:get("glowType"))
    
    -- Update dropdown callback to rebuild controls
    glowTypeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider.config:set("glowType", value)
        self:rebuildGlowControls(value)
        if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
end

-- Function to rebuild controls for selected glow type
function GlowSettings:rebuildGlowControls(glowType)
    -- Clear existing controls
    self.dynamicContainer:ReleaseChildren()
    
    -- Color picker (all types except Proc)
    if glowType ~= "Proc" then
        local glowColorPicker = AceGUI:Create("ColorPicker")
        glowColorPicker:SetLabel("Glow Color")
        local currentColor = self.dataProvider.config:get("glowColor")
        glowColorPicker:SetColor(currentColor[1], currentColor[2], currentColor[3], currentColor[4])
        glowColorPicker:SetCallback("OnValueChanged", function(widget, event, r, g, b, a)
            self.dataProvider.config:set("glowColor", {r, g, b, a})
            if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
        end)
        glowColorPicker:SetFullWidth(true)
        self.dynamicContainer:AddChild(glowColorPicker)
    end
    
    -- Type-specific controls
    if glowType == "Pixel" then
        self:createPixelGlowControls()
    elseif glowType == "ACShine" then
        self:createACShineControls()
    end
    -- Proc glow has no additional settings
end

function GlowSettings:createPixelGlowControls()
    -- Frequency for Pixel glow
    local glowFrequencySlider = AceGUI:Create("Slider")
    glowFrequencySlider:SetLabel("Frequency/Speed")
    glowFrequencySlider:SetSliderValues(-2, 2, 0.05)
    glowFrequencySlider:SetValue(self.dataProvider.config:get("glowFrequency"))
    glowFrequencySlider:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider.config:set("glowFrequency", value)
        if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    glowFrequencySlider:SetFullWidth(true)
    self.dynamicContainer:AddChild(glowFrequencySlider)
    
    -- Pixel-specific sliders
    local pixelControls = {
        {key = "glowLines", label = "Number of Lines", min = 1, max = 30, step = 1},
        {key = "glowLength", label = "Line Length", min = 1, max = 20, step = 1},
        {key = "glowThickness", label = "Line Thickness", min = 1, max = 20, step = 1},
        {key = "glowXOffset", label = "X Offset", min = -20, max = 20, step = 1},
        {key = "glowYOffset", label = "Y Offset", min = -20, max = 20, step = 1}
    }
    
    for _, controlData in ipairs(pixelControls) do
        local slider = AceGUI:Create("Slider")
        slider:SetLabel(controlData.label)
        slider:SetSliderValues(controlData.min, controlData.max, controlData.step)
        slider:SetValue(self.dataProvider.config:get(controlData.key))
        slider:SetCallback("OnValueChanged", function(widget, event, value)
            self.dataProvider.config:set(controlData.key, value)
            if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
        end)
        slider:SetFullWidth(true)
        self.dynamicContainer:AddChild(slider)
    end
    
    -- Border checkbox
    local glowBorderCheck = AceGUI:Create("CheckBox")
    glowBorderCheck:SetLabel("Add Border")
    glowBorderCheck:SetValue(self.dataProvider.config:get("glowBorder"))
    glowBorderCheck:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider.config:set("glowBorder", value)
        if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    glowBorderCheck:SetFullWidth(true)
    self.dynamicContainer:AddChild(glowBorderCheck)
end

function GlowSettings:createACShineControls()
    local acControls = {
        {key = "glowParticleGroups", label = "Particle Groups (N)", min = 1, max = 10, step = 1},
        {key = "glowACFrequency", label = "Frequency (negative = reverse)", min = -2, max = 2, step = 0.025},
        {key = "glowScale", label = "Scale", min = 0.1, max = 3.0, step = 0.1},
        {key = "glowACXOffset", label = "X Offset", min = -20, max = 20, step = 1},
        {key = "glowACYOffset", label = "Y Offset", min = -20, max = 20, step = 1}
    }
    
    for _, controlData in ipairs(acControls) do
        local slider = AceGUI:Create("Slider")
        slider:SetLabel(controlData.label)
        slider:SetSliderValues(controlData.min, controlData.max, controlData.step)
        slider:SetValue(self.dataProvider.config:get(controlData.key))
        slider:SetCallback("OnValueChanged", function(widget, event, value)
            self.dataProvider.config:set(controlData.key, value)
            if addon.UI and addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
        end)
        slider:SetFullWidth(true)
        self.dynamicContainer:AddChild(slider)
    end
end

-- Register component
if not addon.Components then
    addon.Components = {}
end
addon.Components.GlowSettings = GlowSettings

return GlowSettings