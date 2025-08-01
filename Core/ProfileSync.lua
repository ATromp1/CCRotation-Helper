-- Profile Sync Module for CC Rotation Helper
local addonName, addon = ...

-- Load required libraries
local AceSerializer = LibStub("AceSerializer-3.0")

addon.ProfileSync = {}

-- Constants
local COMM_PREFIX = "CCRH_PROFILE"
local SYNC_VERSION = 1

-- Track which party members have the addon
local addonUsers = {}

-- Party sync state
local partySyncState = {
    isActive = false,
    leaderName = nil,
    originalProfile = nil,
    syncProfileName = "Party Sync"
}

-- Message types
local MSG_PROFILE_REQUEST = "REQUEST"
local MSG_PROFILE_SHARE = "SHARE"
local MSG_PROFILE_LIST = "LIST"
local MSG_ADDON_PING = "PING"
local MSG_ADDON_PONG = "PONG"
local MSG_LEADER_PROFILE_BROADCAST = "LEADER_BROADCAST"
local MSG_PROFILE_UPDATE = "PROFILE_UPDATE"

-- Initialize ProfileSync module
function addon.ProfileSync:Initialize()
    -- Register communication handler
    addon:RegisterComm(COMM_PREFIX, "OnCommReceived")
    
    -- Register for group roster events
    addon:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    addon:RegisterEvent("GROUP_JOINED", "OnGroupJoined")
    addon:RegisterEvent("GROUP_LEFT", "OnGroupLeft")
    
    -- Send ping to detect other addon users when joining a group
    C_Timer.After(2, function()
        self:PingAddonUsers()
    end)
    
    print("|cff00ff00CC Rotation Helper|r: Profile sync initialized")
end

-- Handle incoming comm messages
function addon:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    
    -- Don't process our own messages
    if sender == UnitName("player") then return end
    
    -- Deserialize the message
    local success, msgType, data = AceSerializer:Deserialize(message)
    if not success then
        print("|cffff0000CC Rotation Helper|r: Failed to deserialize sync message from " .. sender)
        return
    end
    
    -- Handle different message types
    if msgType == MSG_PROFILE_REQUEST then
        addon.ProfileSync:HandleProfileRequest(sender, data)
    elseif msgType == MSG_PROFILE_SHARE then
        addon.ProfileSync:HandleProfileShare(sender, data)
    elseif msgType == MSG_PROFILE_LIST then
        addon.ProfileSync:HandleProfileList(sender, data)
    elseif msgType == MSG_ADDON_PING then
        addon.ProfileSync:HandleAddonPing(sender, data) 
    elseif msgType == MSG_ADDON_PONG then
        addon.ProfileSync:HandleAddonPong(sender, data)
    elseif msgType == MSG_LEADER_PROFILE_BROADCAST then
        addon.ProfileSync:HandleLeaderProfileBroadcast(sender, data)
    elseif msgType == MSG_PROFILE_UPDATE then
        addon.ProfileSync:HandleProfileUpdate(sender, data)
    end
end

-- Request a profile from a party member
function addon.ProfileSync:RequestProfile(targetPlayer, profileName)
    if not IsInGroup() then
        return false, "Not in a party or raid"
    end
    
    if not targetPlayer or targetPlayer == "" then
        return false, "Target player name required"
    end
    
    if not profileName or profileName == "" then
        return false, "Profile name required"
    end
    
    local requestData = {
        version = SYNC_VERSION,
        profileName = profileName,
        requester = UnitName("player")
    }
    
    local serialized = AceSerializer:Serialize(MSG_PROFILE_REQUEST, requestData)
    addon:SendCommMessage(COMM_PREFIX, serialized, "WHISPER", targetPlayer)
    
    print("|cff00ff00CC Rotation Helper|r: Requested profile '" .. profileName .. "' from " .. targetPlayer)
    return true, "Profile request sent"
end

-- Share a profile with party members
function addon.ProfileSync:ShareProfile(profileName, target)
    if not IsInGroup() and not target then
        return false, "Not in a party/raid and no target specified"
    end
    
    if not profileName or profileName == "" then
        return false, "Profile name required"
    end
    
    -- Check if profile exists by getting the profile list as array
    local profiles = {}
    addon.Config.database:GetProfiles(profiles)
    local profileExists = false
    for _, name in ipairs(profiles) do
        if name == profileName then
            profileExists = true
            break
        end
    end
    
    if not profileExists then
        return false, "Profile '" .. profileName .. "' does not exist"
    end
    
    -- Get the actual profile data from the internal profiles table
    local fullProfileData = addon.Config.database.profiles[profileName]
    
    -- Only share profile-specific settings (not UI/display settings)
    local profileData = {
        priorityPlayers = fullProfileData.priorityPlayers or {},
        customNPCs = fullProfileData.customNPCs or {},
        customSpells = fullProfileData.customSpells or {},
        inactiveSpells = fullProfileData.inactiveSpells or {}
    }
    
    local shareData = {
        version = SYNC_VERSION,
        profileName = profileName,
        profileData = profileData,
        sender = UnitName("player")
    }
    
    local serialized = AceSerializer:Serialize(MSG_PROFILE_SHARE, shareData)
    local distribution = target and "WHISPER" or (IsInRaid() and "RAID" or "PARTY")
    
    addon:SendCommMessage(COMM_PREFIX, serialized, distribution, target)
    
    local targetStr = target or (IsInRaid() and "raid" or "party")
    print("|cff00ff00CC Rotation Helper|r: Shared profile '" .. profileName .. "' with " .. targetStr)
    return true, "Profile shared successfully"
end

-- Request profile list from a party member
function addon.ProfileSync:RequestProfileList(targetPlayer)
    if not IsInGroup() then
        return false, "Not in a party or raid"
    end
    
    if not targetPlayer or targetPlayer == "" then
        return false, "Target player name required"
    end
    
    local requestData = {
        version = SYNC_VERSION,
        requester = UnitName("player")
    }
    
    local serialized = AceSerializer:Serialize(MSG_PROFILE_LIST, requestData)
    addon:SendCommMessage(COMM_PREFIX, serialized, "WHISPER", targetPlayer)
    
    print("|cff00ff00CC Rotation Helper|r: Requested profile list from " .. targetPlayer)
    return true, "Profile list request sent"
end

-- Handle profile request from another player
function addon.ProfileSync:HandleProfileRequest(sender, data)
    if not data or data.version ~= SYNC_VERSION then
        print("|cffff0000CC Rotation Helper|r: Invalid profile request from " .. sender)
        return
    end
    
    print("|cff00ff00CC Rotation Helper|r: " .. sender .. " requested profile '" .. data.profileName .. "'")
    
    -- Check if we have the profile
    local profiles = addon.Config.database:GetProfiles()
    if not profiles[data.profileName] then
        print("|cffff0000CC Rotation Helper|r: Profile '" .. data.profileName .. "' not found")
        return
    end
    
    -- Automatically share the requested profile
    self:ShareProfile(data.profileName, sender)
end

-- Handle incoming profile share
function addon.ProfileSync:HandleProfileShare(sender, data)
    if not data or data.version ~= SYNC_VERSION then
        print("|cffff0000CC Rotation Helper|r: Invalid profile share from " .. sender)
        return
    end
    
    local profileName = data.profileName
    local profileData = data.profileData
    
    -- Check if profile already exists
    local profiles = addon.Config.database:GetProfiles()
    local finalProfileName = profileName
    
    if profiles[profileName] then
        -- Generate a unique name
        local counter = 1
        repeat
            finalProfileName = profileName .. "_" .. sender .. "_" .. counter
            counter = counter + 1
        until not profiles[finalProfileName]
    end
    
    -- Create the new profile
    addon.Config.database:SetProfile(finalProfileName)
    
    -- Copy the profile data
    for key, value in pairs(profileData) do
        addon.Config.database.profile[key] = value
    end
    
    print("|cff00ff00CC Rotation Helper|r: Received profile '" .. finalProfileName .. "' from " .. sender)
    print("|cff00ff00CC Rotation Helper|r: Use /ccr profile to switch to it")
end

-- Handle profile list request
function addon.ProfileSync:HandleProfileList(sender, data)
    if not data or data.version ~= SYNC_VERSION then
        print("|cffff0000CC Rotation Helper|r: Invalid profile list request from " .. sender)
        return
    end
    
    print("|cff00ff00CC Rotation Helper|r: " .. sender .. " requested your profile list")
    
    -- Get our profile names
    local profileNames = addon.Config:GetProfileNames()
    local currentProfile = addon.Config:GetCurrentProfileName()
    
    print("|cff00ff00CC Rotation Helper|r: Your profiles: " .. table.concat(profileNames, ", "))
    print("|cff00ff00CC Rotation Helper|r: Current: " .. currentProfile)
end

-- Get party members who might have the addon
function addon.ProfileSync:GetPartyMembers()
    local members = {}
    
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local name = UnitName(unit)
            if name and name ~= UnitName("player") then
                table.insert(members, name)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                table.insert(members, name)
            end
        end
    end
    
    return members
end

-- Ping party/raid members to detect who has the addon
function addon.ProfileSync:PingAddonUsers()
    if not IsInGroup() then return end
    
    addon.Config:DebugPrint("Pinging party members to detect addon users")
    
    local pingData = {
        version = SYNC_VERSION,
        sender = UnitName("player")
    }
    
    local serialized = AceSerializer:Serialize(MSG_ADDON_PING, pingData)
    local distribution = IsInRaid() and "RAID" or "PARTY"
    addon:SendCommMessage(COMM_PREFIX, serialized, distribution)
end

-- Handle ping from another player
function addon.ProfileSync:HandleAddonPing(sender, data)
    if not data or data.version ~= SYNC_VERSION then return end
    
    addon.Config:DebugPrint("Received addon ping from", sender, "- responding with pong")
    
    -- Respond with pong
    local pongData = {
        version = SYNC_VERSION,
        sender = UnitName("player")
    }
    
    local serialized = AceSerializer:Serialize(MSG_ADDON_PONG, pongData)
    addon:SendCommMessage(COMM_PREFIX, serialized, "WHISPER", sender)
end

-- Handle pong response
function addon.ProfileSync:HandleAddonPong(sender, data)
    if not data or data.version ~= SYNC_VERSION then return end
    
    addon.Config:DebugPrint("Received addon pong from", sender, "- marking as addon user")
    
    -- Mark this player as having the addon
    addonUsers[sender] = {
        hasAddon = true,
        lastSeen = time(),
        version = data.version
    }
    
    addon.Config:DebugPrint("Detected addon user:", sender)
end

-- Get party members who have the addon installed
function addon.ProfileSync:GetAddonUsers()
    local users = {}
    local currentTime = time()
    
    -- Clean up old entries (older than 5 minutes) and collect current users
    for playerName, info in pairs(addonUsers) do
        if currentTime - info.lastSeen > 300 then
            addonUsers[playerName] = nil
        else
            table.insert(users, playerName)
        end
    end
    
    return users
end

-- Check if a specific player has the addon
function addon.ProfileSync:PlayerHasAddon(playerName)
    local info = addonUsers[playerName]
    if not info then return false end
    
    local currentTime = time()
    if currentTime - info.lastSeen > 300 then
        addonUsers[playerName] = nil
        return false
    end
    
    return info.hasAddon
end

-- Manual ping command
function addon.ProfileSync:RefreshAddonUsers()
    addonUsers = {} -- Clear existing data
    self:PingAddonUsers()
    print("|cff00ff00CC Rotation Helper|r: Pinging party members for addon detection...")
end

-- Event handlers for group changes
function addon:OnGroupRosterUpdate()
    if not addon.ProfileSync then return end
    
    addon.Config:DebugPrint("Group roster updated - checking party sync conditions")
    
    -- Ping after a short delay to allow the roster to stabilize
    C_Timer.After(1, function()
        addon.ProfileSync:PingAddonUsers()
        
        -- Check for party sync after addon detection
        C_Timer.After(3, function()
            if addon.ProfileSync:CheckPartySyncConditions() then
                addon.ProfileSync:StartPartySync()
            else
                -- Check if we need to clean up sync (leader left, etc.)
                local leader = addon.ProfileSync:GetGroupLeader()
                if partySyncState.isActive and (not leader or leader ~= partySyncState.leaderName) then
                    addon.ProfileSync:CleanupPartySync()
                end
            end
        end)
    end)
end

function addon:OnGroupJoined()
    if not addon.ProfileSync then return end
    
    addon.Config:DebugPrint("Joined group - checking for party sync setup")
    
    -- Clear existing addon user data since we're in a new group
    addonUsers = {}
    
    -- Ping after a short delay
    C_Timer.After(2, function()
        addon.ProfileSync:PingAddonUsers()
        
        -- Check for party sync after addon detection
        C_Timer.After(4, function()
            if addon.ProfileSync:CheckPartySyncConditions() then
                addon.ProfileSync:StartPartySync()
            end
        end)
    end)
end

function addon:OnGroupLeft()
    if not addon.ProfileSync then return end
    
    addon.Config:DebugPrint("Left group - clearing addon user data")
    
    -- Clear addon user data since we're no longer in a group
    addonUsers = {}
    
    -- Clean up party sync
    addon.ProfileSync:CleanupPartySync()
end

-- ==============================
-- PARTY LEADER SYNCHRONIZATION
-- ==============================

-- Get the current party/raid leader
function addon.ProfileSync:GetGroupLeader()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitIsGroupLeader(unit) then
                return UnitName(unit)
            end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            return UnitName("player")
        end
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if UnitIsGroupLeader(unit) then
                return UnitName(unit)
            end
        end
    end
    return nil
end

-- Check if we should start party sync
function addon.ProfileSync:CheckPartySyncConditions()
    if not IsInGroup() then return false end
    
    local leader = self:GetGroupLeader()
    if not leader or leader == UnitName("player") then return false end
    
    -- Only sync if leader has the addon
    return self:PlayerHasAddon(leader)
end

-- Start party synchronization with leader
function addon.ProfileSync:StartPartySync()
    local leader = self:GetGroupLeader()
    if not leader or not self:PlayerHasAddon(leader) then return end
    
    -- Save current profile if not already in party sync
    if not partySyncState.isActive then
        partySyncState.originalProfile = addon.Config:GetCurrentProfileName()
        partySyncState.isActive = true
        partySyncState.leaderName = leader
        
        print("|cff00ff00CC Rotation Helper|r: Starting party sync with leader " .. leader)
        
        -- Request leader's current profile
        self:RequestLeaderProfile(leader)
    elseif partySyncState.leaderName ~= leader then
        -- Leader changed, update sync
        print("|cff00ff00CC Rotation Helper|r: Party leader changed to " .. leader)
        partySyncState.leaderName = leader
        self:RequestLeaderProfile(leader)
    end
end

-- Request the leader's current profile
function addon.ProfileSync:RequestLeaderProfile(leaderName)
    if not leaderName then return end
    
    local requestData = {
        version = SYNC_VERSION,
        requester = UnitName("player"),
        requestType = "current_profile"
    }
    
    local serialized = AceSerializer:Serialize(MSG_LEADER_PROFILE_BROADCAST, requestData)
    addon:SendCommMessage(COMM_PREFIX, serialized, "WHISPER", leaderName)
    
    addon.Config:DebugPrint("Requesting current profile from leader:", leaderName)
end

-- Broadcast profile update as leader
function addon.ProfileSync:BroadcastProfileAsLeader()
    if not UnitIsGroupLeader("player") or not IsInGroup() then return end
    
    local currentProfile = addon.Config:GetCurrentProfileName()
    local fullProfileData = addon.Config.database.profiles[currentProfile]
    
    -- Only share profile-specific settings
    local profileData = {
        priorityPlayers = fullProfileData.priorityPlayers or {},
        customNPCs = fullProfileData.customNPCs or {},
        customSpells = fullProfileData.customSpells or {},
        inactiveSpells = fullProfileData.inactiveSpells or {}
    }
    
    local broadcastData = {
        version = SYNC_VERSION,
        profileName = currentProfile,
        profileData = profileData,
        sender = UnitName("player"),
        updateType = "leader_profile"
    }
    
    local serialized = AceSerializer:Serialize(MSG_PROFILE_UPDATE, broadcastData)
    local distribution = IsInRaid() and "RAID" or "PARTY"
    addon:SendCommMessage(COMM_PREFIX, serialized, distribution)
    
    addon.Config:DebugPrint("Broadcasting profile update to party")
end

-- Handle leader profile broadcast request
function addon.ProfileSync:HandleLeaderProfileBroadcast(sender, data)
    if not data or data.version ~= SYNC_VERSION then return end
    
    -- Only leaders should respond to profile requests
    if not UnitIsGroupLeader("player") then return end
    
    addon.Config:DebugPrint("Received profile request from party member:", sender)
    
    -- Send our current profile to the requesting member
    self:BroadcastProfileAsLeader()
end

-- Handle profile updates from leader
function addon.ProfileSync:HandleProfileUpdate(sender, data)
    if not data or data.version ~= SYNC_VERSION then return end
    
    -- Only accept updates from the current leader
    local leader = self:GetGroupLeader()
    if sender ~= leader or sender == UnitName("player") then return end
    
    addon.Config:DebugPrint("Received profile update from leader:", sender)
    
    -- Create or update the party sync profile
    self:CreatePartySyncProfile(data.profileData)
    
    print("|cff00ff00CC Rotation Helper|r: Updated party sync profile from " .. sender)
end

-- Create or update the party sync profile
function addon.ProfileSync:CreatePartySyncProfile(profileData)
    -- Switch to party sync profile
    addon.Config.database:SetProfile(partySyncState.syncProfileName)
    
    -- Clear existing data and copy new data
    for key, value in pairs(profileData) do
        addon.Config.database.profile[key] = value
    end
    
    -- Mark that we're now using the sync profile
    if addon.Config:GetCurrentProfileName() ~= partySyncState.syncProfileName then
        addon.Config.database:SetProfile(partySyncState.syncProfileName)
    end
end

-- Clean up party sync when leaving group
function addon.ProfileSync:CleanupPartySync()
    if not partySyncState.isActive then return end
    
    addon.Config:DebugPrint("Cleaning up party sync")
    
    -- Switch back to original profile
    if partySyncState.originalProfile then
        addon.Config.database:SetProfile(partySyncState.originalProfile)
        print("|cff00ff00CC Rotation Helper|r: Restored profile: " .. partySyncState.originalProfile)
    end
    
    -- Delete the party sync profile
    if addon.Config:ProfileExists(partySyncState.syncProfileName) then
        addon.Config.database:DeleteProfile(partySyncState.syncProfileName)
        addon.Config:DebugPrint("Deleted party sync profile")
    end
    
    -- Reset sync state
    partySyncState.isActive = false
    partySyncState.leaderName = nil
    partySyncState.originalProfile = nil
end

-- Check if currently in party sync mode
function addon.ProfileSync:IsInPartySync()
    return partySyncState.isActive
end

-- Get party sync info
function addon.ProfileSync:GetPartySyncInfo()
    return {
        isActive = partySyncState.isActive,
        leaderName = partySyncState.leaderName,
        originalProfile = partySyncState.originalProfile,
        syncProfile = partySyncState.syncProfileName
    }
end