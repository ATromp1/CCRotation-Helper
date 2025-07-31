-- CC Rotation Helper Main Addon File
local addonName, addon = ...

-- Load Ace3 libraries
local AceAddon = LibStub("AceAddon-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

-- Create main addon frame
local CCRotationHelper = CreateFrame("Frame", "CCRotationHelperFrame")
CCRotationHelper:RegisterEvent("ADDON_LOADED")
CCRotationHelper:RegisterEvent("PLAYER_LOGIN")

-- Store addon reference
addon.frame = CCRotationHelper

-- Add Ace3 functionality to our addon object
AceEvent:Embed(addon)
AceComm:Embed(addon)

-- Addon loaded handler
function CCRotationHelper:OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then return end
    
    -- Initialize configuration
    addon.Config:Initialize()
    
    -- Initialize profile sync
    if addon.ProfileSync then
        addon.ProfileSync:Initialize()
    end
    
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
    elseif string.match(command, "^sync") then
        -- Profile sync commands
        local args = {string.match(command, "^sync%s+(.+)")}
        if #args == 0 then
            -- Sync current profile to party
            local success, msg = addon.Config:SyncProfileToParty()
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            local subcommand = args[1]
            if subcommand and string.match(subcommand, "^%w+$") then
                -- Sync specific profile to party
                local success, msg = addon.Config:SyncProfileToParty(subcommand)
                print("|cff00ff00CC Rotation Helper|r: " .. msg)
            end
        end
    elseif string.match(command, "^request") then
        -- Profile request commands: /ccr request PlayerName ProfileName
        local player, profileName = string.match(command, "^request%s+(%S+)%s+(.+)")
        if player and profileName then
            local success, msg = addon.Config:RequestProfileFromPlayer(player, profileName)
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cff00ff00CC Rotation Helper|r: Usage: /ccr request PlayerName ProfileName")
        end
    elseif command == "resetdb" then
        -- Manual database reset for corrupted profiles
        print("|cff00ff00CC Rotation Helper|r: Resetting database...")
        _G["CCRotationDB"] = nil
        addon.Config.database = nil
        addon.Config:Initialize()
        print("|cff00ff00CC Rotation Helper|r: Database reset complete. All settings will be restored to defaults.")
    elseif command == "debug" then
        -- Toggle debug mode
        local currentDebug = addon.Config:Get("debugMode")
        addon.Config:Set("debugMode", not currentDebug)
        local newState = addon.Config:Get("debugMode") and "enabled" or "disabled"
        print("|cff00ff00CC Rotation Helper|r: Debug mode " .. newState)
    elseif command == "party" then
        -- Debug party information
        print("|cff00ff00CC Rotation Helper|r: Party Debug Info:")
        print("  IsInGroup():", IsInGroup())
        print("  IsInRaid():", IsInRaid())
        print("  GetNumSubgroupMembers():", GetNumSubgroupMembers())
        print("  GetNumGroupMembers():", GetNumGroupMembers())
        
        if addon.ProfileSync then
            local members = addon.ProfileSync:GetPartyMembers()
            print("  Party members found:", #members)
            for i, name in ipairs(members) do
                print("    " .. i .. ": " .. name)
            end
        else
            print("  ProfileSync not available")
        end
    elseif command == "users" then
        -- Show addon users
        print("|cff00ff00CC Rotation Helper|r: Addon Users:")
        if addon.ProfileSync then
            local users = addon.ProfileSync:GetAddonUsers()
            if #users == 0 then
                addon.Config:DebugPrint("No addon users detected")
                addon.Config:DebugPrint("Use 'Scan for Addon Users' button in config or join/rejoin party")
            else
                for i, name in ipairs(users) do
                    print("  " .. i .. ": " .. name .. " ✓")
                end
            end
        else
            print("  ProfileSync not available")
        end
    else
        print("|cff00ff00CC Rotation Helper|r Commands:")
        print("  /ccr config - Open configuration")
        print("  /ccr toggle - Enable/disable addon")
        print("  /ccr reset - Reset position to default")
        print("  /ccr profile - Show current profile info")
        print("  /ccr sync [profilename] - Share profile with party")
        print("  /ccr request PlayerName ProfileName - Request profile from player")
        print("  /ccr debug - Toggle debug mode")
        print("  /ccr resetdb - Reset corrupted database (WARNING: loses all settings)")
    end
end

-- Export addon namespace for other files
_G[addonName] = addon
