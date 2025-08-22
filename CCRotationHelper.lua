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
            addon.DebugFrame:ShowFrame("PartySync", "Party Sync Debug")
            -- Test the debug system
            addon.DebugFrame:Print("PartySync", "DEBUG", "=== DEBUG FRAME TEST ===")
            addon.DebugFrame:Print("PartySync", "DEBUG", "If you see this, the debug system is working")
            addon.DebugFrame:Print("PartySync", "INIT", "Test INIT category")
            addon.DebugFrame:Print("PartySync", "GROUP", "Test GROUP category")
            addon.DebugFrame:Print("PartySync", "COMM", "Test COMM category")
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
                addon.DebugFrame:Print("PartySync", "DEBUG", ...)
            else
                print(...)
            end
        end
        
        DebugPrint("=== Simple Party Sync Debug Info ===")
        DebugPrint("IsInGroup():", IsInGroup())
        DebugPrint("IsInRaid():", IsInRaid())
        DebugPrint("GetNumSubgroupMembers():", GetNumSubgroupMembers())
        DebugPrint("GetNumGroupMembers():", GetNumGroupMembers())
        
        -- Party Sync info
        if addon.PartySync then
            DebugPrint("Party Sync Status:", addon.PartySync:GetStatus())
            DebugPrint("Is Group Leader:", UnitIsGroupLeader("player"))
            DebugPrint("Is Active:", addon.PartySync:IsInGroup())
        else
            DebugPrint("PartySync not available!")
        end
        
    elseif command == "status" then
        -- Show simple party sync system status
        print("|cff00ff00CC Rotation Helper|r: === Party Sync Status ===")
        
        -- Party Sync status
        if addon.PartySync then
            print("Status: " .. addon.PartySync:GetStatus())
            print("In Group: " .. (addon.PartySync:IsInGroup() and "Yes" or "No"))
            print("Is Leader: " .. (UnitIsGroupLeader("player") and "Yes" or "No"))
            print("Active: " .. (addon.PartySync:IsInGroup() and "Yes" or "No"))
        else
            print("PartySync: Not initialized")
        end
    elseif command == "pugtest" then
        -- Test pug announcer functionality
        print("|cff00ff00CC Rotation Helper|r: === Pug Announcer Test ===")
        
        if not addon.PartySync:IsInGroup() then
            print("Not in group - pug announcer requires being in a group")
            return
        end
        
        if not addon.PartySync:IsGroupLeader() then
            print("Not group leader - only leaders can make announcements")
            return
        end
        
        local enabled = addon.Config:Get("pugAnnouncerEnabled")
        local channel = addon.Config:Get("pugAnnouncerChannel")
        print("Announcer enabled: " .. (enabled and "Yes" or "No"))
        print("Announcer channel: " .. (channel or "SAY"))
        
        -- Check for pugs in group
        local pugCount = 0
        if IsInGroup() then
            local numGroupMembers = GetNumGroupMembers()
            local prefix = IsInRaid() and "raid" or "party"
            
            for i = 1, numGroupMembers do
                local unit = prefix .. i
                if UnitExists(unit) then
                    local playerName = UnitName(unit)
                    if addon.PartySync:IsPlayerPug(playerName) then
                        pugCount = pugCount + 1
                        print("Pug detected: " .. playerName)
                    else
                        print("Has addon: " .. playerName)
                    end
                end
            end
        end
        
        if pugCount == 0 then
            print("No pugs detected in current group")
        else
            print("Total pugs: " .. pugCount)
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
        
    elseif command == "syncdata" then
        -- Show what's being broadcast or received
        if not addon.PartySync then
            print("|cffff0000Error:|r PartySync not available")
            return
        end
        
        if addon.PartySync:IsGroupLeader() then
            print("|cff00ff00CC Rotation Helper|r: === BROADCASTING DATA ===")
            if addon.Config and addon.Config.database then
                local data = addon.Config.database.profile.spells or {}
                
                -- Collect active spells and sort by priority
                local activeSpells = {}
                for id, spell in pairs(data) do
                    if spell.active then
                        table.insert(activeSpells, {
                            id = id,
                            name = spell.name or "Unknown",
                            priority = spell.priority or 999,
                            ccType = spell.ccType or "unknown"
                        })
                    end
                end
                
                -- Sort by priority (lower number = higher priority)
                table.sort(activeSpells, function(a, b)
                    return a.priority < b.priority
                end)
                
                -- Display sorted spells
                for i, spell in ipairs(activeSpells) do
                    print(string.format("  %d. Spell %s: %s (Priority: %d, Type: %s)", 
                        i, spell.id, spell.name, spell.priority, spell.ccType))
                end
                print(string.format("Total broadcasting: %d active spells", #activeSpells))
                
                -- Show priority players (sorted alphabetically)
                local priorityPlayers = addon.Config.database.profile.priorityPlayers or {}
                local priorityNames = {}
                for name in pairs(priorityPlayers) do
                    table.insert(priorityNames, name)
                end
                table.sort(priorityNames)
                
                for i, name in ipairs(priorityNames) do
                    print(string.format("  Priority Player %d: %s", i, name))
                end
                print(string.format("Total priority players: %d", #priorityNames))
            end
        elseif addon.PartySync:IsInPartySync() then
            print("|cff00ff00CC Rotation Helper|r: === RECEIVING DATA ===")
            local syncedSpells = addon.PartySync:GetDisplaySpells()
            
            -- Collect synced spells and sort by priority
            local activeSyncedSpells = {}
            if syncedSpells then
                for id, spell in pairs(syncedSpells) do
                    if spell.active then
                        table.insert(activeSyncedSpells, {
                            id = id,
                            name = spell.name or "Unknown",
                            priority = spell.priority or 999,
                            ccType = spell.ccType or "unknown"
                        })
                    end
                end
            end
            
            -- Sort by priority (lower number = higher priority)
            table.sort(activeSyncedSpells, function(a, b)
                return a.priority < b.priority
            end)
            
            -- Display sorted synced spells
            for i, spell in ipairs(activeSyncedSpells) do
                print(string.format("  %d. Synced Spell %s: %s (Priority: %d, Type: %s)", 
                    i, spell.id, spell.name, spell.priority, spell.ccType))
            end
            print(string.format("Total receiving: %d synced spells", #activeSyncedSpells))
            
            -- Show synced priority players (sorted alphabetically)
            local syncedPriority = addon.PartySync:GetDisplayPriorityPlayers()
            local syncedPriorityNames = {}
            if syncedPriority then
                for name in pairs(syncedPriority) do
                    table.insert(syncedPriorityNames, name)
                end
            end
            table.sort(syncedPriorityNames)
            
            for i, name in ipairs(syncedPriorityNames) do
                print(string.format("  Priority Player %d: %s", i, name))
            end
            print(string.format("Total synced priority players: %d", #syncedPriorityNames))
        else
            print("|cff00ff00CC Rotation Helper|r: Not in party sync mode")
        end

    elseif command == "hash" then
        -- Show current data hash
        if addon.PartySync then
            print("|cff00ff00CC Rotation Helper|r: === DATA HASH DEBUG ===")
            local hash = addon.PartySync:GetCurrentDataHash()
            if hash then
                print("Current data hash:", hash)
                
                if addon.Config and addon.Config.db then
                    local profileData = {
                        spells = addon.Config.db.spells or {},
                        customNPCs = addon.Config.db.customNPCs or {},
                        priorityPlayers = addon.Config.db.priorityPlayers or {}
                    }
                    
                    local activeSpells = 0
                    for spellID, spell in pairs(profileData.spells) do
                        if spell.active then
                            activeSpells = activeSpells + 1
                        end
                    end
                    
                    local priorityPlayers = 0
                    for _ in pairs(profileData.priorityPlayers) do
                        priorityPlayers = priorityPlayers + 1
                    end
                    
                    local customNPCs = 0
                    for _ in pairs(profileData.customNPCs) do
                        customNPCs = customNPCs + 1
                    end
                    
                    print("Data being hashed:")
                    print("  Active spells:", activeSpells)
                    print("  Priority players:", priorityPlayers)
                    print("  Custom NPCs:", customNPCs)
                    
                    local spellCount = 0
                    for spellID, spell in pairs(profileData.spells) do
                        if spell.active and spellCount < 3 then
                            print(string.format("  Spell %s: %s (Priority: %s, Type: %s)", 
                                spellID, spell.name or "Unknown", spell.priority or 0, spell.ccType or "unknown"))
                            spellCount = spellCount + 1
                        end
                    end
                    
                    if activeSpells > 3 then
                        print("  ... and", activeSpells - 3, "more spells")
                    end
                end
            else
                print("No hash available")
            end
        else
            print("|cffff0000Error:|r PartySync not available")
        end
    elseif command == "hashraw" then
        if addon.PartySync then
            print("|cff00ff00CC Rotation Helper|r: === RAW HASH STRING ===")
            if addon.Config and addon.Config.db then
                local profileData = {
                    spells = addon.Config.db.spells or {},
                    customNPCs = addon.Config.db.customNPCs or {},
                    priorityPlayers = addon.Config.db.priorityPlayers or {}
                }
                
                local str = ""
                
                if profileData.spells then
                    local spellIDs = {}
                    for spellID, spell in pairs(profileData.spells) do
                        if spell.active then
                            table.insert(spellIDs, tonumber(spellID) or 0)
                        end
                    end
                    table.sort(spellIDs)
                    
                    local spellList = {}
                    for _, spellID in ipairs(spellIDs) do
                        local spell = profileData.spells[tostring(spellID)]
                        if spell and spell.active then
                            local spellStr = string.format("%s:%s:%s:%s:%s", 
                                spellID, 
                                spell.priority or 0,
                                spell.name or "",
                                spell.ccType or "",
                                spell.active and "1" or "0"
                            )
                            table.insert(spellList, spellStr)
                        end
                    end
                    str = str .. table.concat(spellList, ",")
                end
                
                if profileData.priorityPlayers then
                    local playerList = {}
                    for player in pairs(profileData.priorityPlayers) do
                        table.insert(playerList, player)
                    end
                    table.sort(playerList)
                    str = str .. "|" .. table.concat(playerList, ",")
                end
                
                if profileData.customNPCs then
                    local npcIDs = {}
                    for npcID in pairs(profileData.customNPCs) do
                        table.insert(npcIDs, tonumber(npcID) or 0)
                    end
                    table.sort(npcIDs)
                    
                    local npcList = {}
                    for _, npcID in ipairs(npcIDs) do
                        local npc = profileData.customNPCs[tostring(npcID)]
                        if npc then
                            local npcStr = string.format("%s:%s", npcID, npc.name or "")
                            if npc.cc then
                                for i = 1, 5 do
                                    local ccValue = npc.cc[i]
                                    if type(ccValue) == "boolean" then
                                        ccValue = ccValue and 1 or 0
                                    elseif type(ccValue) == "number" then
                                        ccValue = ccValue
                                    else
                                        ccValue = 0
                                    end
                                    npcStr = npcStr .. ":" .. ccValue
                                end
                            end
                            table.insert(npcList, npcStr)
                        end
                    end
                    str = str .. "|" .. table.concat(npcList, ",")
                end
                
                print("Raw hash string (first 500 chars):")
                print(string.sub(str, 1, 500))
                if #str > 500 then
                    print("... (truncated, total length: " .. #str .. ")")
                end
                print("Full string length:", #str)
            else
                print("No config data available")
            end
        else
            print("|cffff0000Error:|r PartySync not available")
        end
    else
        print("|cff00ff00CC Rotation Helper|r Commands:")
        print("  /ccr config - Open configuration")
        print("  /ccr toggle - Enable/disable addon")
        print("  /ccr reset - Reset position to default")
        print("  /ccr status - Show party sync status")
        print("  /ccr debug - Toggle debug mode")
        print("  /ccr preview - Toggle config positioning preview")
        print("  /ccr pugtest - Test pug announcer functionality")
        print("|cffFFFF00Party Sync Commands:|r")
        print("  /ccr syncdata - Show what you're broadcasting/receiving")
        print("  /ccr hash - Show current data hash")
        print("  /ccr hashraw - Show raw hash string for comparison")
        print("  /ccr debugnpc - Toggle NPC debug frame")
        print("  /ccr resetdb - Reset database (WARNING: loses all settings)")
    end
end

-- Export addon namespace for other files
_G[addonName] = addon
