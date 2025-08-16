-- DisplaySettings.lua - Display configuration component
-- Contains all display-related settings using reusable form controls

local addonName, addon = ...
local BaseComponent = addon.BaseComponent

-- DisplaySettings Component - handles all display configuration
local DisplaySettings = {}
setmetatable(DisplaySettings, {__index = BaseComponent})

function DisplaySettings:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.DataProviders.Config)
    setmetatable(instance, {__index = self})
    self:validateImplementation("DisplaySettings")
    return instance
end

function DisplaySettings:buildUI()
    -- Create internal container for this component's content
    local internalGroup = self.AceGUI:Create("SimpleGroup")
    internalGroup:SetFullWidth(true)
    internalGroup:SetLayout("Flow")
    self.container:AddChild(internalGroup)
    
    -- Load form control components
    if not addon.Components or not addon.Components.CheckboxControl then
        error("CheckboxControl component not loaded. Make sure UI/Components/FormControls.lua is loaded first.")
    end
    
    -- Enable CC Rotation Helper
    local enabledControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Enable CC Rotation Helper",
        "enabled",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:updateVisibility()
            end
        }
    )
    enabledControl:buildUI()
    
    -- Show when not in group
    local soloControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Show when not in group",
        "showInSolo",
        {
            onValueChanged = function(configKey, value)
                -- Rebuild queue first in case visibility affects queue logic
                self.dataProvider:rebuildQueue()
                -- Update visibility (this shows/hides the frame)
                self.dataProvider:updateVisibility()
                -- Force display refresh to show the rebuilt queue
                self.dataProvider:refreshDisplay()
            end
        }
    )
    soloControl:buildUI()
    
    -- Only enable in dungeons
    local dungeonsOnlyControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Only enable in dungeons",
        "onlyInDungeons",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:rebuildQueue()
                self.dataProvider:updateVisibility()
                self.dataProvider:refreshDisplay()
            end
        }
    )
    dungeonsOnlyControl:buildUI()
    
    -- Show spell names
    local spellNameControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Show spell names",
        "showSpellName",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
            end
        }
    )
    spellNameControl:buildUI()
    
    -- Show player names
    local playerNameControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Show player names",
        "showPlayerName",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
            end
        }
    )
    playerNameControl:buildUI()
    
    -- Show cooldown numbers
    local cooldownTextControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Show cooldown numbers",
        "showCooldownText",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
            end
        }
    )
    cooldownTextControl:buildUI()

    -- Desaturate icon if spell is on cooldown
    local desaturateIconControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Desaturate icons if spell is on cooldown",
        "desaturateOnCooldown",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
            end
        }
    )
    desaturateIconControl:buildUI()
    
    -- Desaturate icon when no tracked NPCs are in combat
    local desaturateNoNPCsControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Desaturate when no tracked NPCs are fighting us",
        "desaturateWhenNoTrackedNPCs",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
            end
        }
    )
    desaturateNoNPCsControl:buildUI()
    
    -- Show tooltips on hover
    local tooltipControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Show tooltips on hover",
        "showTooltips",
        {
            onValueChanged = function(configKey, value)
                -- Update mouse settings to enable/disable click-through
                self.dataProvider:updateMouseSettings()
            end
        }
    )
    tooltipControl:buildUI()
    
    -- Highlight next spell
    local highlightControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Highlight next spell",
        "highlightNext",
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
            end
        }
    )
    highlightControl:buildUI()
    
    -- Turn notification sound
    local turnNotificationControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Play sound when it's your turn",
        "enableTurnNotification",
        {
            onValueChanged = function(configKey, value)
                -- No refresh needed for sound settings
            end
        }
    )
    turnNotificationControl:buildUI()
    
    -- Turn notification text
    local turnNotificationTextEdit = self.AceGUI:Create("EditBox")
    turnNotificationTextEdit:SetLabel("Turn notification text")
    turnNotificationTextEdit:SetWidth(200)
    turnNotificationTextEdit:SetText(addon.Config:Get("turnNotificationText") or "Next")
    turnNotificationTextEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        addon.Config:Set("turnNotificationText", text)
    end)
    internalGroup:AddChild(turnNotificationTextEdit)
    
    -- Turn notification volume slider
    local turnNotificationVolumeControl = addon.Components.SliderControl:new(
        internalGroup,
        "Turn notification volume",
        "turnNotificationVolume",
        0, 100, 5,
        {
            onValueChanged = function(configKey, value)
                -- No refresh needed for sound settings
            end
        }
    )
    turnNotificationVolumeControl:buildUI()
    
    -- Cooldown decimal threshold slider
    local decimalThresholdControl = addon.Components.SliderControl:new(
        internalGroup,
        "Show decimals below (seconds)",
        "cooldownDecimalThreshold",
        0, 10, 1,
        {
            onValueChanged = function(configKey, value)
                self.dataProvider:refreshDisplay()
            end
        }
    )
    decimalThresholdControl:buildUI()
    
    -- Lock frame position
    local anchorLockControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Lock frame position (prevents Shift+drag movement)",
        "anchorLocked",
        {
            onValueChanged = function(configKey, value)
                -- Update mouse settings to enable/disable click-through
                self.dataProvider:updateMouseSettings()
            end
        }
    )
    anchorLockControl:buildUI()
    
    -- Debug mode
    local debugControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Debug mode (shows detailed debug messages)",
        "debugMode",
        {
            onValueChanged = function(configKey, value)
                local state = value and "enabled" or "disabled"
                print("|cff00ff00CC Rotation Helper|r: Debug mode " .. state)
            end
        }
    )
    debugControl:buildUI()
end

-- Register in addon namespace
if not addon.Components then
    addon.Components = {}
end
addon.Components.DisplaySettings = DisplaySettings

return DisplaySettings