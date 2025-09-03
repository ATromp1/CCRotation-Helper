-- DisplaySettings.lua - Display configuration component
-- Contains all display-related settings using reusable form controls

local addonName, addon = ...
local BaseComponent = addon.BaseComponent

-- DisplaySettings Component - handles all display configuration
local DisplaySettings = {}
setmetatable(DisplaySettings, {__index = BaseComponent})

function DisplaySettings:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.Components.DataManager)
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
                if addon.UI and addon.UI.UpdateVisibility then
                    addon.UI:UpdateVisibility()
                end
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
                self.dataProvider.config:rebuildQueue()
                -- Update visibility (this shows/hides the frame)
                if addon.UI and addon.UI.UpdateVisibility then
                    addon.UI:UpdateVisibility()
                end
                -- Force display refresh to show the rebuilt queue
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
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
                self.dataProvider.config:rebuildQueue()
                if addon.UI and addon.UI.UpdateVisibility then
                    addon.UI:UpdateVisibility()
                end
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
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
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
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
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
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
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    cooldownTextControl:buildUI()

    -- Dangerous Cast Settings Section
    local dangerousCastsGroup = addon.BaseComponent:createInlineGroup("Dangerous Cast Settings", self.container)
    
    -- Show dangerous cast alerts
    local dangerousCastsControl = addon.Components.CheckboxControl:new(
        dangerousCastsGroup,
        "Show dangerous cast alerts",
        "showDangerousCasts",
        {
            onValueChanged = function(configKey, value)
                -- Rebuild queue to refresh dangerous cast data
                self.dataProvider.config:rebuildQueue()
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    dangerousCastsControl:buildUI()

    -- Dangerous casts player only option (sub-option of show dangerous casts)
    local dangerousCastsPlayerOnlyControl = addon.Components.CheckboxControl:new(
        dangerousCastsGroup,
        "Only show alerts for your own abilities",
        "dangerousCastsPlayerOnly",
        {
            onValueChanged = function(configKey, value)
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    dangerousCastsPlayerOnlyControl:buildUI()

    -- Dangerous cast trigger count slider
    local dangerousCastTriggerCountControl = addon.Components.SliderControl:new(
        dangerousCastsGroup,
        "Minimum simultaneous casts to trigger",
        "dangerousCastTriggerCount",
        1, 10, 1,
        {
            onValueChanged = function(configKey, value)
                -- Rebuild queue to refresh dangerous cast data
                self.dataProvider.config:rebuildQueue()
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    dangerousCastTriggerCountControl:buildUI()

    -- Desaturate icon if spell is on cooldown
    local desaturateIconControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Desaturate icons if spell is on cooldown",
        "desaturateOnCooldown",
        {
            onValueChanged = function(configKey, value)
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end
        }
    )
    desaturateIconControl:buildUI()
    
    
    -- Show tooltips on hover
    local tooltipControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Show tooltips on hover",
        "showTooltips",
        {
            onValueChanged = function(configKey, value)
                -- Update mouse settings to enable/disable click-through
                if addon.UI and addon.UI.UpdateMouseSettings then
                    addon.UI:UpdateMouseSettings()
                end
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
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
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
    
    -- Pug announcer
    local pugAnnouncerControl = addon.Components.CheckboxControl:new(
        internalGroup,
        "Announce abilities for players without addon",
        "pugAnnouncerEnabled",
        {
            onValueChanged = function(configKey, value)
                -- No refresh needed for announcer settings
            end
        }
    )
    pugAnnouncerControl:buildUI()
    
    -- Pug announcer channel dropdown
    local pugChannelDropdown = self.AceGUI:Create("Dropdown")
    pugChannelDropdown:SetLabel("Announcer channel")
    pugChannelDropdown:SetWidth(150)
    pugChannelDropdown:SetList({
        ["SAY"] = "Say",
        ["PARTY"] = "Party",
        ["YELL"] = "Yell"
    })
    pugChannelDropdown:SetValue(self.dataProvider.config:get("pugAnnouncerChannel", "SAY"))
    pugChannelDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        self.dataProvider.config:set("pugAnnouncerChannel", value)
    end)
    internalGroup:AddChild(pugChannelDropdown)
    
    -- Turn notification text
    local turnNotificationTextEdit = self.AceGUI:Create("EditBox")
    turnNotificationTextEdit:SetLabel("Turn notification text")
    turnNotificationTextEdit:SetWidth(200)
    turnNotificationTextEdit:SetText(self.dataProvider.config:get("turnNotificationText", "Next"))
    turnNotificationTextEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        self.dataProvider.config:set("turnNotificationText", text)
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
                if addon.UI and addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
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
                if addon.UI and addon.UI.UpdateMouseSettings then
                    addon.UI:UpdateMouseSettings()
                end
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