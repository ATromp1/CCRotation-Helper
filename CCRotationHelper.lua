-- CC Rotation Helper Main Addon File
local addonName, addon = ...

-- Load Ace3 libraries
local AceAddon = LibStub("AceAddon-3.0")
local AceEvent = LibStub("AceEvent-3.0")

-- Create main addon frame
local CCRotationHelper = CreateFrame("Frame", "CCRotationHelperFrame")
CCRotationHelper:RegisterEvent("ADDON_LOADED")
CCRotationHelper:RegisterEvent("PLAYER_LOGIN")

-- Store addon reference
addon.frame = CCRotationHelper

-- Add AceEvent functionality to our addon object
AceEvent:Embed(addon)

-- Addon loaded handler
function CCRotationHelper:OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then return end
    
    -- Initialize configuration
    addon.Config:Initialize()
    
    print("|cff00ff00CC Rotation Helper|r: Addon loaded successfully!")
end

-- Player login handler  
function CCRotationHelper:OnPlayerLogin()
    -- Initialize core rotation system
    addon.CCRotation:Initialize()
    
    -- Initialize UI
    if addon.UI then
        addon.UI:Initialize()
    end
    
    -- Initialize minimap icon
    if addon.MinimapIcon then
        addon.MinimapIcon:Initialize()
    end
    
    print("|cff00ff00CC Rotation Helper|r: Ready for M+ dungeons!")
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
    
    if command == "config" or command == "options" then
        if addon.UI and addon.UI.ShowConfigFrame then
            addon.UI:ShowConfigFrame()
        else
            print("|cff00ff00CC Rotation Helper|r: Configuration UI not available")
        end
    elseif command == "toggle" then
        local enabled = addon.Config:Get("enabled")
        addon.Config:Set("enabled", not enabled)
        print("|cff00ff00CC Rotation Helper|r: " .. (enabled and "Disabled" or "Enabled"))
        
        if addon.UI then
            if enabled then
                addon.UI:Hide()
            else
                addon.UI:Show()
            end
        end
    elseif command == "reset" then
        -- Reset position to default
        addon.Config:Set("xOffset", 354)
        addon.Config:Set("yOffset", 134)
        if addon.UI then
            addon.UI:UpdatePosition()
        end
        print("|cff00ff00CC Rotation Helper|r: Position reset to default")
    elseif command == "profile" or command == "profiles" then
        -- Show current profile and available profiles
        local current = addon.Config:GetCurrentProfileName()
        local profiles = addon.Config:GetProfileNames()
        print("|cff00ff00CC Rotation Helper|r: Current profile: " .. current)
        print("Available profiles: " .. table.concat(profiles, ", "))
    else
        print("|cff00ff00CC Rotation Helper|r Commands:")
        print("  /ccr config - Open configuration")
        print("  /ccr toggle - Enable/disable addon")
        print("  /ccr reset - Reset position to default")
        print("  /ccr profile - Show current profile info")
    end
end

-- Export addon namespace for other files
_G[addonName] = addon
