local addonName, addon = ...

-- Simple Party Sync - Direct profile copying without complex state management
addon.SimplePartySync = {}

local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

local broadcastTimer = nil
local SYNC_CHANNEL = "CCRotationSync"
local BROADCAST_INTERVAL = 5 -- seconds

function addon.SimplePartySync:Initialize()
    -- Register for communication
    self:RegisterComm(SYNC_CHANNEL, "OnCommReceived")
    
    -- Start broadcasting if we're in a group
    self:UpdateGroupStatus()
    
    -- Register for group events
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PARTY_LEADER_CHANGED")
end

function addon.SimplePartySync:UpdateGroupStatus()
    if self:IsInGroup() and self:IsGroupLeader() then
        self:StartBroadcasting()
    else
        self:StopBroadcasting()
    end
end

function addon.SimplePartySync:IsInGroup()
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

function addon.SimplePartySync:IsGroupLeader()
    return UnitIsGroupLeader("player")
end

function addon.SimplePartySync:StartBroadcasting()
    if broadcastTimer then
        broadcastTimer:Cancel()
    end
    
    -- Immediate broadcast
    self:BroadcastProfile()
    
    -- Then broadcast every 5 seconds
    broadcastTimer = C_Timer.NewTicker(BROADCAST_INTERVAL, function()
        if addon.SimplePartySync:IsInGroup() and addon.SimplePartySync:IsGroupLeader() then
            addon.SimplePartySync:BroadcastProfile()
        else
            addon.SimplePartySync:StopBroadcasting()
        end
    end)
end

function addon.SimplePartySync:StopBroadcasting()
    if broadcastTimer then
        broadcastTimer:Cancel()
        broadcastTimer = nil
    end
    
    -- Restore original settings when leaving group
    self:RestoreOriginalSettings()
end

function addon.SimplePartySync:RestoreOriginalSettings()
    if self.originalSpells and addon.CCRotation then
        addon.Config:DebugPrint("Restoring original spell settings - UI will now show local profile")
        addon.CCRotation.trackedCooldowns = self.originalSpells
        self.originalSpells = nil
        
        if addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
    end
    
    -- Clear synced data
    self.syncedSpells = nil
    self.syncedPriorityPlayers = nil
end

function addon.SimplePartySync:BroadcastProfile()
    if not addon.Config or not addon.Config.database then
        return
    end
    
    -- Get current profile data - single source of truth  
    local profileData = {
        spells = addon.Config.database.profile.spells or {},
        customNPCs = addon.Config.database.profile.customNPCs or {},
        priorityPlayers = addon.Config.database.profile.priorityPlayers or {}
    }
    
    -- Serialize and send
    local serialized = AceSerializer:Serialize(profileData)
    self:SendCommMessage(SYNC_CHANNEL, serialized, "PARTY")
end

function addon.SimplePartySync:OnCommReceived(prefix, message, distribution, sender)
    -- Ignore our own messages
    if sender == UnitName("player") then
        return
    end
    
    -- Only accept from group leader
    if not UnitIsGroupLeader(sender) then
        return
    end
    
    -- Deserialize data
    local success, profileData = AceSerializer:Deserialize(message)
    if not success then
        return
    end
    
    -- Apply the data
    self:ApplyProfileData(profileData)
end

function addon.SimplePartySync:ApplyProfileData(profileData)
    if not addon.Config or not addon.CCRotation then
        return
    end
    
    -- Store original profile spell data for restoration later if needed
    if not self.originalSpells then
        self.originalSpells = addon.Config:GetTrackedSpells()
    end
    
    -- Apply sync data directly to the rotation system without touching saved profile
    if profileData.spells then
        local syncedSpells = {}
        
        -- Convert synced spells to the format expected by rotation system
        for spellID, spell in pairs(profileData.spells) do
            if spell.active then
                syncedSpells[spellID] = {
                    priority = spell.priority,
                    type = addon.Config:NormalizeCCType(spell.ccType)
                }
            end
        end
        
        -- Update rotation system directly with synced data
        addon.CCRotation.trackedCooldowns = syncedSpells
        
        -- Store synced spell data for UI display
        addon.SimplePartySync.syncedSpells = profileData.spells
        addon.Config:DebugPrint("Stored synced spell data - UI will now show leader's configuration")
        
        if addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
    end
    
    -- Apply other sync data temporarily 
    if profileData.priorityPlayers then
        addon.SimplePartySync.syncedPriorityPlayers = profileData.priorityPlayers
    end
    
    -- Fire events for UI updates - use Config for proper event routing to UI components
    addon.Config:FireEvent("PROFILE_SYNC_RECEIVED", profileData)
    if addon.CCRotation then
        addon.CCRotation:FireEvent("PROFILE_SYNC_RECEIVED", profileData)
    end
end

-- Event handlers
function addon.SimplePartySync:GROUP_ROSTER_UPDATE()
    -- Immediately stop broadcasting if no longer in group
    if not self:IsInGroup() then
        self:StopBroadcasting()
    end
    self:UpdateGroupStatus()
end

function addon.SimplePartySync:PARTY_LEADER_CHANGED()
    self:UpdateGroupStatus()
end

-- Public API for status checking
function addon.SimplePartySync:GetStatus()
    if not self:IsInGroup() then
        return "Not in group"
    elseif self:IsGroupLeader() then
        return "Broadcasting (Leader)"
    else
        return "Receiving"
    end
end

function addon.SimplePartySync:IsActive()
    return self:IsInGroup()
end

-- Make it inherit from AceEvent for event handling
local AceEvent = LibStub("AceEvent-3.0")
AceEvent:Embed(addon.SimplePartySync)

-- Make it inherit from AceComm for communication
AceComm:Embed(addon.SimplePartySync)