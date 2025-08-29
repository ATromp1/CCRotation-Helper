local addonName, addon = ...

-- PartySync-related commands: partysync, party, status, pugtest, syncdata, hash, hashraw
addon.PartySyncCommands = {}

local function DebugPrint(...)
    if addon.DebugFrame then
        addon.DebugFrame:Print("PartySync", "DEBUG", ...)
    end
end

function addon.PartySyncCommands:partysync()
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
end

function addon.PartySyncCommands:party()
    -- Debug party information in party sync frame
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
end

function addon.PartySyncCommands:status()
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
end

function addon.PartySyncCommands:pugtest()
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
end

