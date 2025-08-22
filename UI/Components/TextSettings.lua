-- TextSettings.lua - Text configuration component
-- Contains all text-related settings using reusable form controls

local addonName, addon = ...
local BaseComponent = addon.BaseComponent

-- TextSettings Component - handles all text configuration
local TextSettings = {}
setmetatable(TextSettings, {__index = BaseComponent})

function TextSettings:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.DataProviders.Config)
    setmetatable(instance, {__index = self})
    self:validateImplementation("TextSettings")
    return instance
end

function TextSettings:buildUI()
    -- Create internal container for this component's content
    local internalGroup = self.AceGUI:Create("SimpleGroup")
    internalGroup:SetFullWidth(true)
    internalGroup:SetLayout("Flow")
    self.container:AddChild(internalGroup)
    
    -- Load form control components
    if not addon.Components or not addon.Components.SliderControl then
        error("SliderControl component not loaded. Make sure UI/Components/FormControls.lua is loaded first.")
    end
    
    -- Spell name font size slider
    local spellNameFontControl = addon.Components.SliderControl:new(
        internalGroup,
        "Spell Name Font Size",
        "spellNameFontSize",
        8, 24, 1,
        {
            onValueChanged = function(configKey, value)
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    spellNameFontControl:buildUI()
    
    -- Spell name max length slider
    local spellNameLengthControl = addon.Components.SliderControl:new(
        internalGroup,
        "Spell Name Max Length",
        "spellNameMaxLength",
        5, 50, 1,
        {
            onValueChanged = function(configKey, value)
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    spellNameLengthControl:buildUI()
    
    -- Player name font size slider
    local playerNameFontControl = addon.Components.SliderControl:new(
        internalGroup,
        "Player Name Font Size",
        "playerNameFontSize",
        8, 24, 1,
        {
            onValueChanged = function(configKey, value)
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    playerNameFontControl:buildUI()
    
    -- Player name max length slider
    local playerNameLengthControl = addon.Components.SliderControl:new(
        internalGroup,
        "Player Name Max Length",
        "playerNameMaxLength",
        3, 30, 1,
        {
            onValueChanged = function(configKey, value)
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    playerNameLengthControl:buildUI()
    
    -- Cooldown font size percentage slider
    local cooldownFontControl = addon.Components.SliderControl:new(
        internalGroup,
        "Cooldown Font Size (% of icon)",
        "cooldownFontSizePercent",
        10, 50, 1,
        {
            onValueChanged = function(configKey, value)
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    cooldownFontControl:buildUI()
end

-- Register in addon namespace
if not addon.Components then
    addon.Components = {}
end
addon.Components.TextSettings = TextSettings

return TextSettings