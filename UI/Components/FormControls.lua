-- FormControls.lua - Reusable form control components
-- Provides CheckboxControl and SliderControl for configuration forms

local addonName, addon = ...
local BaseComponent = addon.BaseComponent

-- CheckboxControl Component - reusable checkbox with consistent pattern
local CheckboxControl = {}
setmetatable(CheckboxControl, {__index = BaseComponent})

function CheckboxControl:new(container, label, configKey, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.Components.DataManager)
    instance.label = label
    instance.configKey = configKey
    setmetatable(instance, {__index = self})
    self:validateImplementation("CheckboxControl")
    return instance
end

function CheckboxControl:buildUI()
    local checkbox = self.AceGUI:Create("CheckBox")
    checkbox:SetLabel(self.label)
    checkbox:SetValue(self.dataProvider.config:get(self.configKey))
    checkbox:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider.config:set(self.configKey, value)
        self:triggerCallback("onValueChanged", self.configKey, value)
    end)
    checkbox:SetFullWidth(true)
    self.container:AddChild(checkbox)
end

-- SliderControl Component - reusable slider with consistent pattern
local SliderControl = {}
setmetatable(SliderControl, {__index = BaseComponent})

function SliderControl:new(container, label, configKey, min, max, step, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.Components.DataManager)
    instance.label = label
    instance.configKey = configKey
    instance.min = min or 0
    instance.max = max or 100
    instance.step = step or 1
    setmetatable(instance, {__index = self})
    self:validateImplementation("SliderControl")
    return instance
end

function SliderControl:buildUI()
    local slider = self.AceGUI:Create("Slider")
    slider:SetLabel(self.label)
    slider:SetSliderValues(self.min, self.max, self.step)
    local currentValue = self.dataProvider.config:get(self.configKey)
    -- Ensure we always pass a valid number to SetValue
    if currentValue == nil then
        currentValue = self.min -- Use minimum value as fallback
    end
    slider:SetValue(currentValue)
    slider:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider.config:set(self.configKey, value)
        self:triggerCallback("onValueChanged", self.configKey, value)
    end)
    slider:SetFullWidth(true)
    self.container:AddChild(slider)
end

-- Export components
local FormControls = {
    CheckboxControl = CheckboxControl,
    SliderControl = SliderControl
}

-- Register in addon namespace
if not addon.Components then
    addon.Components = {}
end
addon.Components.CheckboxControl = CheckboxControl
addon.Components.SliderControl = SliderControl

return FormControls