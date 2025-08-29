-- CC Rotation Helper Main Addon File
local addonName, addon = ...

-- Load Ace3 libraries
local AceComm = LibStub("AceComm-3.0")

-- Create main addon frame
local CCRotationHelper = CreateFrame("Frame", "CCRotationHelperFrame")
CCRotationHelper:RegisterEvent("ADDON_LOADED")
CCRotationHelper:RegisterEvent("PLAYER_LOGIN")

-- Store addon reference
addon.frame = CCRotationHelper

-- Add Ace3 functionality to our addon object
AceComm:Embed(addon)

-- Addon loaded handler
function CCRotationHelper:OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then return end
    
    -- Initialize configuration
    addon.Config:Initialize()
    
    -- Initialize party sync system
    if addon.PartySync then
        addon.PartySync:Initialize()
        -- Register config listener now that Config is initialized
        addon.PartySync:RegisterConfigListener()
    end
end

-- Player login handler  
function CCRotationHelper:OnPlayerLogin()
    -- Initialize core rotation system
    addon.CCRotation:Initialize()
    
    -- Initialize sound manager (after CCRotation is ready)
    if addon.SoundManager then
        addon.SoundManager:Initialize()
    end
    
    -- Initialize UI
    if addon.UI then
        addon.UI:Initialize()
    end
    
    -- Initialize minimap icon
    if addon.MinimapIcon then
        addon.MinimapIcon:Initialize()
    end
    
end

-- Main event handler
CCRotationHelper:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        self:OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        self:OnPlayerLogin()
    end
end)

-- Slash command registration
SLASH_CCROTATION1 = "/ccr"
SLASH_CCROTATION2 = "/ccrotation"

SlashCmdList["CCROTATION"] = function(msg)
    local command = string.lower(msg or "")
    
    -- Core commands
    if command == "config" or command == "options" then
        addon.CoreCommands:config()
    elseif command == "toggle" then
        addon.CoreCommands:toggle()
    elseif command == "reset" then
        addon.CoreCommands:reset()
    
    -- Debug commands
    elseif command == "debug" then
        addon.DebugCommands:debug()
    elseif command == "debugnpc" or command == "npcdebug" then
        addon.DebugCommands:debugnpc()
    elseif command == "resetdebug" then
        addon.DebugCommands:resetdebug()
    elseif command == "icons" or command == "icon" then
        addon.DebugCommands:icons()
    elseif command == "preview" then
        addon.DebugCommands:preview()
    elseif command == "debugframe" then
        addon.DebugCommands:debugframe()
    
    -- Profile commands
    elseif command == "profile" or command == "profiles" then
        addon.ProfileCommands:profile()
    elseif command == "resetdb" then
        addon.ProfileCommands:resetdb()
    
    -- Party sync commands
    elseif command == "partysync" then
        addon.PartySyncCommands:partysync()
    elseif command == "party" then
        addon.PartySyncCommands:party()
    elseif command == "status" then
        addon.PartySyncCommands:status()
    elseif command == "pugtest" then
        addon.PartySyncCommands:pugtest()
    
    -- Help/default
    else
        print("|cff00ff00CC Rotation Helper|r Commands:")
        print("  /ccr config - Open configuration")
        print("  /ccr toggle - Enable/disable addon")
        print("  /ccr reset - Reset position to default")
        print("  /ccr status - Show party sync status")
        print("  /ccr debug - Toggle debug mode")
        print("  /ccr preview - Toggle config positioning preview")
        print("  /ccr pugtest - Test pug announcer functionality")
        print("  /ccr debugnpc - Toggle NPC debug frame")
        print("  /ccr debugframe - Show tabbed debug frame")
        print("  /ccr resetdb - Reset database (WARNING: loses all settings)")
    end
end

-- Export addon namespace for other files
_G[addonName] = addon
