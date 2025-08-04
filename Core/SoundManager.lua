-- SoundManager.lua - Handles audio notifications for the addon
-- Provides centralized sound management with proper throttling

local addonName, addon = ...

addon.SoundManager = {}
local SoundManager = addon.SoundManager

function SoundManager:Initialize()
    -- Initialize throttling state
    self.lastNotificationTime = nil
    
    -- Register for turn notification events
    if addon.CCRotation then
        addon.CCRotation:RegisterEventListener("PLAYER_TURN_NEXT", function(cooldownData)
            self:PlayTurnNotification()
        end)
    end
end

-- Play turn notification sound using text-to-speech
function SoundManager:PlayTurnNotification()
    -- Throttle notifications to prevent spam (only once per 5 seconds)
    local now = GetTime()
    if self.lastNotificationTime and (now - self.lastNotificationTime) < 5 then
        return
    end
    self.lastNotificationTime = now
    
    -- Get the configurable notification settings
    local config = addon.Config
    local notificationText = config:Get("turnNotificationText") or "Next"
    local volume = config:Get("turnNotificationVolume") or 100
    
    -- Use WoW's text-to-speech API to announce it's the player's turn
    C_VoiceChat.SpeakText(1, notificationText, Enum.VoiceTtsDestination.QueuedLocalPlayback, 1, volume)
end