-- SoundManager.lua - Handles audio notifications for the addon
-- Provides centralized sound management with proper throttling

local addonName, addon = ...

addon.SoundManager = {}
local SoundManager = addon.SoundManager

SoundManager.Substitutions = {
    ["spellName"] = function (cooldownData)
        local spell = addon.Config:GetSpellInfo(cooldownData.spellID)
        return spell.name or "Next"
    end,
}

function SoundManager:Initialize()
    -- Initialize throttling state
    self.lastNotificationTime = nil
    
    -- Register for turn notification events
    if addon.CCRotation then
        addon.CCRotation:RegisterEventListener("PLAYER_TURN_NEXT", function(cooldownData)
            self:PlayTurnNotification(cooldownData)
        end)
    end
end

-- Play turn notification sound using text-to-speech
function SoundManager:PlayTurnNotification(cooldownData)
    -- Throttle notifications to prevent spam (only once per 5 seconds)
    local now = GetTime()
    if self.lastNotificationTime and (now - self.lastNotificationTime) < 5 then
        return
    end
    self.lastNotificationTime = now
    
    -- Get the configurable notification settings
    local config = addon.Config
    local notificationText = self:GetNotificationText(cooldownData)
    local volume = config:Get("turnNotificationVolume") or 100
    
    -- Use WoW's text-to-speech API to announce it's the player's turn
    C_VoiceChat.SpeakText(1, notificationText, Enum.VoiceTtsDestination.QueuedLocalPlayback, 1, volume)
end

function SoundManager:GetNotificationText(cooldownData) 
    local notificationText = addon.Config:Get("turnNotificationText") or "Next"

    -- Pattern explanation:
    -- %% matches a literal % character
    -- ([%w_]+) captures one or more word characters (letters, digits, underscore) as the key
    return notificationText:gsub("%%([%w_]+)", function (key)
        if self.Substitutions[key] then
            return self.Substitutions[key](cooldownData)
        end

        return key
    end)
end
