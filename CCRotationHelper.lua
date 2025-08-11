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
    
    -- Initialize simple party sync system
    if addon.SimplePartySync then
        addon.SimplePartySync:Initialize()
    end
    
    -- Initialize legacy profile sync (will be refactored)
    if addon.ProfileSync then
        addon.ProfileSync:Initialize()
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
        -- Reset position to default and clear WoW's saved position
        if addon.UI and addon.UI.mainFrame then
            addon.UI.mainFrame:ClearAllPoints()
            addon.UI.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 354, 134)
            -- Clear WoW's saved position so it uses our default
            addon.UI.mainFrame:SetUserPlaced(false)
            print("|cff00ff00CC Rotation Helper|r: Position reset to default")
        else
            print("|cff00ff00CC Rotation Helper|r: Cannot reset position - UI not initialized")
        end
    elseif command == "icons" or command == "icon" then
        -- Show icon debug info and attempt recovery
        if addon.UI then
            addon.UI:ShowIconDebug()
        else
            print("|cff00ff00CC Rotation Helper|r: UI not initialized")
        end
    elseif command == "debugnpc" or command == "npcdebug" then
        -- Toggle NPC debug frame
        if addon.UI then
            addon.UI:ToggleNPCDebug()
        else
            print("|cff00ff00CC Rotation Helper|r: UI not initialized")
        end
    elseif command == "partysync" then
        -- Toggle party sync debug frame
        if addon.DebugFrame then
            addon.DebugFrame:ShowFrame("ProfileSync", "Party Sync Debug")
            -- Test the debug system
            addon.DebugFrame:Print("ProfileSync", "DEBUG", "=== DEBUG FRAME TEST ===")
            addon.DebugFrame:Print("ProfileSync", "DEBUG", "If you see this, the debug system is working")
            addon.DebugFrame:Print("ProfileSync", "INIT", "Test INIT category")
            addon.DebugFrame:Print("ProfileSync", "GROUP", "Test GROUP category")
            addon.DebugFrame:Print("ProfileSync", "COMM", "Test COMM category")
        else
            print("|cff00ff00CC Rotation Helper|r: DebugFrame not initialized")
        end
    elseif command == "resetdebug" then
        -- Reset NPC debug frame position  
        if addon.UI then
            addon.UI:ResetNPCDebugPosition()
        else
            print("|cff00ff00CC Rotation Helper|r: UI not initialized")
        end
    elseif command == "profile" or command == "profiles" then
        -- Show current profile and available profiles
        local current = addon.Config:GetCurrentProfileName()
        local profiles = addon.Config:GetProfileNames()
        print("|cff00ff00CC Rotation Helper|r: Current profile: " .. current)
        print("Available profiles: " .. table.concat(profiles, ", "))
    elseif command == "resetdb" then
        -- Manual database reset for corrupted profiles
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
        -- Debug party information in party sync frame
        local function DebugPrint(...)
            if addon.DebugFrame and addon.DebugFrame.Print then
                addon.DebugFrame:Print("ProfileSync", "DEBUG", ...)
            else
                print(...)
            end
        end
        
        DebugPrint("=== Simple Party Sync Debug Info ===")
        DebugPrint("IsInGroup():", IsInGroup())
        DebugPrint("IsInRaid():", IsInRaid())
        DebugPrint("GetNumSubgroupMembers():", GetNumSubgroupMembers())
        DebugPrint("GetNumGroupMembers():", GetNumGroupMembers())
        
        -- Simple Party Sync info
        if addon.SimplePartySync then
            DebugPrint("Simple Party Sync Status:", addon.SimplePartySync:GetStatus())
            DebugPrint("Is Group Leader:", addon.SimplePartySync:IsGroupLeader())
            DebugPrint("Is Active:", addon.SimplePartySync:IsActive())
        else
            DebugPrint("SimplePartySync not available!")
        end
        
    elseif command == "status" then
        -- Show simple party sync system status
        print("|cff00ff00CC Rotation Helper|r: === Simple Party Sync Status ===")
        
        -- Simple Party Sync status
        if addon.SimplePartySync then
            print("Status: " .. addon.SimplePartySync:GetStatus())
            print("In Group: " .. (addon.SimplePartySync:IsInGroup() and "Yes" or "No"))
            print("Is Leader: " .. (addon.SimplePartySync:IsGroupLeader() and "Yes" or "No"))
            print("Active: " .. (addon.SimplePartySync:IsActive() and "Yes" or "No"))
        else
            print("SimplePartySync: Not initialized")
        end
    elseif command == "preview" then
        -- Toggle config preview manually
        if addon.UI then
            if addon.UI.mainFrame and addon.UI.mainFrame.mainPreview and addon.UI.mainFrame.mainPreview:IsShown() then
                addon.UI:hideConfigPreview()
                print("|cff00ff00CC Rotation Helper|r: Config preview hidden")
            else
                addon.UI:showConfigPreview()
                print("|cff00ff00CC Rotation Helper|r: Config preview shown")
            end
        else
            print("|cff00ff00CC Rotation Helper|r: UI not initialized")
        end
    else
        print("|cff00ff00CC Rotation Helper|r Commands:")
        print("  /ccr config - Open configuration")
        print("  /ccr toggle - Enable/disable addon")
        print("  /ccr reset - Reset position to default")
        print("  /ccr position - Show position debug info and toggle anchor")
        print("  /ccr icons - Show icon debug info and attempt recovery")
        print("  /ccr debugnpc - Toggle NPC debug frame")
        print("  /ccr resetdebug - Reset NPC debug frame position")
        print("  /ccr profile - Show current profile info")
        print("  /ccr sync [profilename] - Share profile with party")
        print("  /ccr request PlayerName ProfileName - Request profile from player")
        print("  /ccr debug - Toggle debug mode")
        print("  /ccr preview - Toggle config positioning preview")
        print("  /ccr resetdb - Reset corrupted database (WARNING: loses all settings)")
    end
end

-- Export addon namespace for other files
_G[addonName] = addon
