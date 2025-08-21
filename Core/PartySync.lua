local addonName, addon = ...

-- PartySync - Simplified and robust party synchronization
addon.PartySync = {}

local AceSerializer = LibStub("AceSerializer-3.0")
local AceComm = LibStub("AceComm-3.0")

-- Configuration
local SYNC_PREFIX = "CCRH_SYNC"
local REQUEST_PREFIX = "CCRH_REQ"
local BROADCAST_INTERVAL = 5 -- seconds

-- State tracking
local broadcastTimer = nil
local syncedData = {
    spells = nil,
    priorityPlayers = nil,
    customNPCs = nil
}
local originalData = {
    spells = nil
}
local lastDataHash = nil -- Track last sent/received data hash

-- User profile choice tracking for legacy compatibility
local userProfileTracking = {
    lastUserChosenProfile = nil
}

-- Debug logging
local function DebugPrint(category, ...)
    if addon.DebugFrame and addon.DebugFrame.Print then
        addon.DebugFrame:Print("PartySync", category, ...)
    end
end

-- Simple hash function for data comparison
local function CalculateDataHash(data)
    local str = ""
    
    -- Hash active spells with all relevant properties
    if data.spells then
        local spellIDs = {}
        for spellID, spell in pairs(data.spells) do
            if spell.active then
                table.insert(spellIDs, tonumber(spellID) or 0)
            end
        end
        table.sort(spellIDs)
        
        local spellList = {}
        for _, spellID in ipairs(spellIDs) do
            local spell = data.spells[tostring(spellID)]
            if spell and spell.active then
                -- Include all properties that affect functionality
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
    
    -- Hash priority players
    if data.priorityPlayers then
        local playerList = {}
        for player in pairs(data.priorityPlayers) do
            table.insert(playerList, player)
        end
        table.sort(playerList)
        str = str .. "|" .. table.concat(playerList, ",")
    end
    
    -- Hash custom NPCs
    if data.customNPCs then
        local npcIDs = {}
        for npcID in pairs(data.customNPCs) do
            table.insert(npcIDs, tonumber(npcID) or 0)
        end
        table.sort(npcIDs)
        
        local npcList = {}
        for _, npcID in ipairs(npcIDs) do
            local npc = data.customNPCs[tostring(npcID)]
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
    
    -- Simple string hash (djb2 algorithm)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    
    return hash
end

-- Initialize the party sync system
function addon.PartySync:Initialize()
    DebugPrint("init", "Initializing PartySync system")
    
    -- Embed AceComm into PartySync
    AceComm:Embed(addon.PartySync)
    
    -- Register AceComm for communication
    addon.PartySync:RegisterComm(SYNC_PREFIX, "OnCommReceived")
    addon.PartySync:RegisterComm(REQUEST_PREFIX, "OnRequestReceived")

    -- Create a frame to handle group events using WoW's native event system
    if not addon.PartySync.eventFrame then
        addon.PartySync.eventFrame = CreateFrame("Frame", "CCRPartySyncEventFrame")
        
        -- Register for group events only (AceComm handles communication)
        addon.PartySync.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        addon.PartySync.eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
        
        -- Set up event handler
        addon.PartySync.eventFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "GROUP_ROSTER_UPDATE" then
                addon.PartySync:GROUP_ROSTER_UPDATE()
            elseif event == "PARTY_LEADER_CHANGED" then
                addon.PartySync:PARTY_LEADER_CHANGED()
            end
        end)
        
        DebugPrint("init", "Created event frame and registered group events")
    end
    
    -- Listen for config changes to trigger immediate broadcast
    if addon.Config then
        DebugPrint("init", "Config found, registering PROFILE_DATA_CHANGED listener")
        addon.Config:RegisterEventListener("PROFILE_DATA_CHANGED", function(dataType, value)
            -- If we're the leader and actively syncing, broadcast immediately
            if addon.PartySync:IsGroupLeader() and addon.PartySync:IsInGroup() then
                DebugPrint("COMM", "Config changed, broadcasting immediately")
                addon.PartySync:BroadcastProfile()
            end
        end)
        self.configListenerRegistered = true
    else
        DebugPrint("init", "Config not found during PartySync initialization - will register later")
    end
    
    -- Initialize user profile tracking from saved variables
    if addon.Config and addon.Config.global and addon.Config.global.lastUserChosenProfile then
        userProfileTracking.lastUserChosenProfile = addon.Config.global.lastUserChosenProfile
    end
    
    -- Start sync if we're already in a group (delay to ensure group status is ready)
    C_Timer.After(1, function()
        self:UpdateGroupStatus()
    end)
    
end

-- Register config event listener (call this after Config is initialized)
function addon.PartySync:RegisterConfigListener()
    if addon.Config and not self.configListenerRegistered then
        DebugPrint("init", "Registering PROFILE_DATA_CHANGED listener (delayed)")
        addon.Config:RegisterEventListener("PROFILE_DATA_CHANGED", function(dataType, value)
            -- If we're the leader and actively syncing, broadcast immediately
            if addon.PartySync:IsGroupLeader() and addon.PartySync:IsInGroup() then
                DebugPrint("COMM", "Config changed, broadcasting immediately")
                addon.PartySync:BroadcastProfile()
            end
        end)
        self.configListenerRegistered = true
    end
end

-- Group status management
function addon.PartySync:UpdateGroupStatus()
    if self:IsInGroup() and self:IsGroupLeader() then
        self:StartBroadcasting()
    elseif self:IsInGroup() and not self:IsGroupLeader() then
        self:RequestSync()
    else
        self:StopBroadcasting()
    end
end

function addon.PartySync:IsInGroup()
    -- In delves, IsInGroup() returns true but you're only grouped with NPCs
    -- Check if we have actual player group members
    if IsInRaid() then
        return true -- Raids are always player groups
    end
    
    if IsInGroup() then
        -- Check if we have any real players in the group besides ourselves
        local numGroupMembers = GetNumSubgroupMembers() -- This counts party members excluding yourself
        if numGroupMembers > 0 then
            -- Verify at least one group member is a real player
            for i = 1, numGroupMembers do
                local unit = "party" .. i
                if UnitIsPlayer(unit) then
                    return true -- Found at least one real player
                end
            end
        end
    end
    
    return false -- Solo or only grouped with NPCs
end

function addon.PartySync:IsGroupLeader()
    return UnitIsGroupLeader("player")
end

-- Broadcasting (leader only)
function addon.PartySync:StartBroadcasting()
    if broadcastTimer then
        broadcastTimer:Cancel()
    end
    
    DebugPrint("broadcast", "Starting to broadcast as group leader")
    
    -- Immediate broadcast
    self:BroadcastProfile()
    
    -- Then broadcast every 5 seconds
    broadcastTimer = C_Timer.NewTicker(BROADCAST_INTERVAL, function()
        if addon.PartySync:IsInGroup() and addon.PartySync:IsGroupLeader() then
            addon.PartySync:BroadcastProfile()
        else
            addon.PartySync:StopBroadcasting()
        end
    end)
end

function addon.PartySync:StopBroadcasting()
    if broadcastTimer then
        broadcastTimer:Cancel()
        broadcastTimer = nil
        DebugPrint("broadcast", "Stopped broadcasting")
    end
    
    -- Restore original settings when leaving group or losing leadership
    self:RestoreOriginalSettings()
end

function addon.PartySync:BroadcastProfile()
    if not addon.Config or not addon.Config.db then
        return
    end
    
    local profileData = {
        spells = addon.Config.db.spells or {},
        customNPCs = addon.Config.db.customNPCs or {},
        priorityPlayers = addon.Config.db.priorityPlayers or {}
    }
    
    local currentHash = CalculateDataHash(profileData)
    
    if currentHash == lastDataHash then
        DebugPrint("COMM", "Data unchanged, skipping broadcast (hash:", currentHash, ")")
        return
    end
    
    DebugPrint("COMM", "Data changed, broadcasting (old hash:", lastDataHash, "new hash:", currentHash, ")")
    lastDataHash = currentHash
    
    profileData.transmissionHash = currentHash
    local serialized = AceSerializer:Serialize(profileData)
    if serialized then
        -- Use AceComm to send the message
        local success = pcall(function()
            addon.PartySync:SendCommMessage(SYNC_PREFIX, serialized, "PARTY")
        end)
        
        if not success then
            DebugPrint("COMM", "Failed to send sync message")
        end
    end
end

-- Request sync from leader
function addon.PartySync:RequestSync()
    if not self:IsInGroup() or self:IsGroupLeader() then
        return
    end
    
    if syncedData.spells then
        return
    end
    
    DebugPrint("COMM", "Requesting sync from leader")
    local success = pcall(function()
        addon.PartySync:SendCommMessage(REQUEST_PREFIX, "REQUEST", "PARTY")
    end)
    
    if not success then
        DebugPrint("COMM", "Failed to send sync request")
    end
end

function addon.PartySync:OnRequestReceived(prefix, message, distribution, sender)
    if prefix ~= REQUEST_PREFIX then
        return
    end
    
    if sender == UnitName("player") then
        return
    end
    
    if not self:IsGroupLeader() then
        return
    end
    
    DebugPrint("COMM", "Received sync request from:", sender)
    
    -- Force immediate broadcast regardless of hash
    self:ForceBroadcast()
end

-- Force broadcast (ignoring hash check)
function addon.PartySync:ForceBroadcast()
    if not addon.Config or not addon.Config.db then
        return
    end
    
    local profileData = {
        spells = addon.Config.db.spells or {},
        customNPCs = addon.Config.db.customNPCs or {},
        priorityPlayers = addon.Config.db.priorityPlayers or {}
    }
    
    local currentHash = CalculateDataHash(profileData)
    profileData.transmissionHash = currentHash
    
    DebugPrint("COMM", "Force broadcasting (hash:", currentHash, ")")
    
    local serialized = AceSerializer:Serialize(profileData)
    if serialized then
        local success = pcall(function()
            addon.PartySync:SendCommMessage(SYNC_PREFIX, serialized, "PARTY")
        end)
        
        if not success then
            DebugPrint("COMM", "Failed to send forced sync message")
        end
    end
end

-- Handle AceComm messages
function addon.PartySync:OnCommReceived(prefix, message, distribution, sender)
    -- Only handle our prefix
    if prefix ~= SYNC_PREFIX then
        return
    end
    
    -- Ignore our own messages
    if sender == UnitName("player") then
        return
    end
    
    -- Only accept from group leader
    if not UnitIsGroupLeader(sender) then
        DebugPrint("COMM", "Ignoring sync from non-leader:", sender)
        return
    end
    
    DebugPrint("COMM", "Received sync from leader:", sender)
    
    local success, profileData = AceSerializer:Deserialize(message)
    if not success then
        DebugPrint("COMM", "Failed to deserialize sync message")
        return
    end
    
    if profileData.transmissionHash then
        local dataToVerify = {
            spells = profileData.spells,
            customNPCs = profileData.customNPCs,
            priorityPlayers = profileData.priorityPlayers
        }
        local calculatedHash = CalculateDataHash(dataToVerify)
        
        if calculatedHash == profileData.transmissionHash then
            DebugPrint("COMM", "Transmission integrity verified (hash:", calculatedHash, ")")
        else
            DebugPrint("COMM", "WARNING: Transmission hash mismatch! Expected:", profileData.transmissionHash, "Got:", calculatedHash)
        end
    end
    
    DebugPrint("COMM", "Applying synced data from leader:", sender)
    addon.PartySync:ApplyProfileData(profileData)
end

function addon.PartySync:ApplyProfileData(profileData)
    DebugPrint("SYNC", "ApplyProfileData called")
    
    if not addon.Config or not addon.CCRotation then
        DebugPrint("SYNC", "Missing Config or CCRotation, aborting")
        return
    end
    
    -- Store original profile spell data for restoration later if needed
    if not originalData.spells then
        originalData.spells = addon.Config:GetTrackedSpells()
        DebugPrint("SYNC", "Stored original spells for restoration")
    end
    
    -- Apply sync data directly to the rotation system
    if profileData.spells then
        DebugPrint("SYNC", "Processing synced spells data")
        local syncedSpells = {}
        local activeCount = 0
        
        -- Convert synced spells to the format expected by rotation system
        for spellID, spell in pairs(profileData.spells) do
            if spell.active then
                activeCount = activeCount + 1
                syncedSpells[spellID] = {
                    priority = spell.priority,
                    type = addon.Config:NormalizeCCType(spell.ccType)
                }
            end
        end
        
        DebugPrint("SYNC", "Converted", activeCount, "active synced spells")
        
        -- Update rotation system directly with synced data
        addon.CCRotation.trackedCooldowns = syncedSpells
        
        -- Store synced data for UI display and status checking
        syncedData.spells = profileData.spells
        DebugPrint("SYNC", "Updated syncedData.spells with", activeCount, "spells")
        
        if addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
            DebugPrint("SYNC", "Rebuilt rotation queue")
        end
    else
        DebugPrint("SYNC", "No spells data in profileData")
    end
    
    -- Store other sync data
    if profileData.priorityPlayers then
        syncedData.priorityPlayers = profileData.priorityPlayers
        DebugPrint("SYNC", "Updated priority players")
    end
    
    if profileData.customNPCs then
        syncedData.customNPCs = profileData.customNPCs
        DebugPrint("SYNC", "Updated custom NPCs")
    end
    
    -- Fire events for UI updates
    addon.Config:FireEvent("PROFILE_SYNC_RECEIVED", profileData)
    if addon.CCRotation then
        addon.CCRotation:FireEvent("PROFILE_SYNC_RECEIVED", profileData)
    end
    
    DebugPrint("SYNC", "Applied sync data and fired events")
end

-- Data restoration
function addon.PartySync:RestoreOriginalSettings()
    if originalData.spells and addon.CCRotation then
        addon.CCRotation.trackedCooldowns = originalData.spells
        originalData.spells = nil
        
        if addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
    end
    
    -- Clear synced data
    syncedData.spells = nil
    syncedData.priorityPlayers = nil
    syncedData.customNPCs = nil
    
    -- Fire event to notify UI that sync ended
    addon.Config:FireEvent("PROFILE_SYNC_ENDED")
end

-- Event handlers
function addon.PartySync:GROUP_ROSTER_UPDATE()
    -- Delay operations to avoid taint issues with Blizzard frames
    C_Timer.After(0.1, function()
        -- Immediately stop broadcasting if no longer in group
        if not addon.PartySync:IsInGroup() then
            addon.PartySync:StopBroadcasting()
        end
        addon.PartySync:UpdateGroupStatus()
    end)
end

function addon.PartySync:PARTY_LEADER_CHANGED()
    addon.PartySync:UpdateGroupStatus()
end

-- Public API for status checking
function addon.PartySync:GetStatus()
    if not self:IsInGroup() then
        return "Not in group"
    elseif self:IsGroupLeader() then
        return "Broadcasting (Leader)"
    else
        return "Receiving"
    end
end

function addon.PartySync:IsActive()
    return self:IsInGroup()
end

function addon.PartySync:IsInPartySync()
    return self:IsInGroup() and not self:IsGroupLeader() and syncedData.spells ~= nil
end

function addon.PartySync:IsProfileSelectionLocked()
    return self:IsInPartySync()
end


-- User profile choice tracking (legacy compatibility)
function addon.PartySync:TrackUserProfileChoice(profileName)
    userProfileTracking.lastUserChosenProfile = profileName
    
    -- Store in global config
    if addon.Config and addon.Config.global then
        addon.Config.global.lastUserChosenProfile = profileName
    end
    
    DebugPrint("profile", "User chose profile:", profileName)
end

function addon.PartySync:GetUserLastChosenProfile()
    return userProfileTracking.lastUserChosenProfile
end

function addon.PartySync:GetRecommendedLeaderProfile()
    -- Check if user has a preferred profile
    if userProfileTracking.lastUserChosenProfile then
        -- Verify the profile still exists
        local profiles = addon.Config and addon.Config:GetProfileNames() or {}
        for _, name in ipairs(profiles) do
            if name == userProfileTracking.lastUserChosenProfile then
                return userProfileTracking.lastUserChosenProfile
            end
        end
    end
    
    -- Fall back to current profile
    if addon.Config then
        return addon.Config:GetCurrentProfileName()
    end
    
    return nil
end


-- Data access methods for UI (returns synced data when in sync, otherwise normal data)
function addon.PartySync:GetDisplaySpells()
    if self:IsInPartySync() and syncedData.spells then
        return syncedData.spells
    end
    return addon.Config and addon.Config.database and addon.Config.database.profile.spells
end

function addon.PartySync:GetDisplayPriorityPlayers()
    if self:IsInPartySync() and syncedData.priorityPlayers then
        return syncedData.priorityPlayers
    end
    return addon.Config and addon.Config.database and addon.Config.database.profile.priorityPlayers
end

function addon.PartySync:GetDisplayCustomNPCs()
    if self:IsInPartySync() and syncedData.customNPCs then
        return syncedData.customNPCs
    end
    return addon.Config and addon.Config.database and addon.Config.database.profile.customNPCs
end

-- Get current data hash for debugging
function addon.PartySync:GetCurrentDataHash()
    if not addon.Config or not addon.Config.db then
        return nil
    end
    
    -- Use the same data structure as BroadcastProfile for consistency
    local profileData = {
        spells = addon.Config.db.spells or {},
        customNPCs = addon.Config.db.customNPCs or {},
        priorityPlayers = addon.Config.db.priorityPlayers or {}
    }
    
    return CalculateDataHash(profileData)
end

-- Debug methods
function addon.PartySync:ShowDebugFrame()
    if addon.DebugFrame then
        addon.DebugFrame:ShowFrame("PartySync", "Party Sync Debug")
    end
end

function addon.PartySync:HideDebugFrame()
    if addon.DebugFrame then
        addon.DebugFrame:HideFrame("PartySync")
    end
end

function addon.PartySync:ToggleDebugFrame()
    if addon.DebugFrame then
        addon.DebugFrame:ToggleFrame("PartySync", "Party Sync Debug")
    end
end