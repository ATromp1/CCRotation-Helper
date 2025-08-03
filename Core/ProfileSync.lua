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
    lastActiveProfile = nil,  -- Profile that was active before sync started
    syncProfileName = "Party Sync",
    isDirty = false, -- Has the current profile had changes since last sync?
    lastSync = nil
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

    -- Register for config change events to trigger debounced sync
    addon.Config:RegisterEventListener("PROFILE_DATA_CHANGED", function()
        self:DebouncedSync()
    end)

    -- Ensure the permanent Party Sync profile exists
    self:EnsurePartySyncProfileExists()
    
    -- Check if we need to restore profile after login
    self:CheckProfileRestoreOnLogin()
    
    -- Send ping to detect other addon users when joining a group
    C_Timer.After(2, function()
        self:PingAddonUsers()

        C_Timer.After(2, function()
            if self:CheckPartySyncConditions() then
                self:StartPartySync()
            end
        end)
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
    if UnitName(playerName) == UnitName("player") then return true end

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
            local leader = addon.ProfileSync:GetGroupLeader()
            
            -- Handle leadership changes
            if partySyncState.isActive and leader and leader ~= partySyncState.leaderName then
                -- If we became the leader, transition to leader mode
                if leader == UnitName("player") then
                    addon.ProfileSync:TransitionToLeader()
                else
                    -- New leader, restart sync with them if they have addon
                    if addon.ProfileSync:PlayerHasAddon(leader) then
                        partySyncState.leaderName = leader
                        addon.ProfileSync:RequestLeaderProfile(leader)
                    else
                        -- New leader doesn't have addon, cleanup
                        addon.ProfileSync:CleanupPartySync()
                    end
                end
            elseif addon.ProfileSync:CheckPartySyncConditions() then
                addon.ProfileSync:StartPartySync()
            elseif partySyncState.isActive and not leader then
                -- Leader left completely, cleanup
                addon.ProfileSync:CleanupPartySync()
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
    if not leader then return false end
    
    -- Only sync if leader has the addon
    return self:PlayerHasAddon(leader)
end

-- Start party synchronization with leader
function addon.ProfileSync:StartPartySync()
    local leader = self:GetGroupLeader()
    if not leader or not self:PlayerHasAddon(leader) then return end
    
    -- If we're the leader, we don't sync - we just broadcast our current profile
    if leader == UnitName("player") then
        if not partySyncState.isActive then
            partySyncState.isActive = true
            partySyncState.leaderName = leader
            self:EnsurePartySyncProfileExists()
            print("|cff00ff00CC Rotation Helper|r: Started party sync as leader")
            -- Broadcast our current profile to party members
            C_Timer.After(1, function()
                self:BroadcastProfileAsLeader()
            end)
        end
        return
    end
    
    -- Save current profile if not already in party sync (and it's not already the Party Sync profile)
    local currentProfile = addon.Config:GetCurrentProfileName()
    if not partySyncState.isActive then
        if currentProfile ~= partySyncState.syncProfileName then
            partySyncState.lastActiveProfile = currentProfile
            -- Persist this to saved variables
            addon.Config.global.partySyncLastActiveProfile = currentProfile
        end
        partySyncState.isActive = true
        partySyncState.leaderName = leader
        
        -- Ensure Party Sync profile exists
        self:EnsurePartySyncProfileExists()
        
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
    partySyncState.lastSync = GetTime()
    partySyncState.isDirty = false 
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

-- Ensure the Party Sync profile exists
function addon.ProfileSync:EnsurePartySyncProfileExists()
    if not addon.Config:ProfileExists(partySyncState.syncProfileName) then
        local currentProfile = addon.Config:GetCurrentProfileName()
        addon.Config.database:SetProfile(partySyncState.syncProfileName)
        addon.Config:DebugPrint("Created Party Sync profile")
        -- Switch back to the original profile if we weren't creating it intentionally
        if currentProfile ~= partySyncState.syncProfileName then
            addon.Config.database:SetProfile(currentProfile)
        end
    end
end

-- Create or update the party sync profile
function addon.ProfileSync:CreatePartySyncProfile(profileData)
    -- Ensure the profile exists first
    self:EnsurePartySyncProfileExists()
    
    -- Switch to party sync profile
    addon.Config.database:SetProfile(partySyncState.syncProfileName)
    
    -- Clear existing profile-specific data and copy new data
    local profile = addon.Config.database.profile
    profile.priorityPlayers = {}
    profile.customNPCs = {}
    profile.customSpells = {}
    profile.inactiveSpells = {}
    
    -- Copy the new profile data
    for key, value in pairs(profileData) do
        profile[key] = value
    end
    
    addon.Config:DebugPrint("Updated Party Sync profile with leader's data")
end

-- Clean up party sync when leaving group
function addon.ProfileSync:CleanupPartySync()
    if not partySyncState.isActive then return end
    
    addon.Config:DebugPrint("Cleaning up party sync")
    
    -- Switch back to last active profile (only if we're not the leader and we have a saved profile)
    if partySyncState.lastActiveProfile and partySyncState.leaderName ~= UnitName("player") then
        addon.Config.database:SetProfile(partySyncState.lastActiveProfile)
        print("|cff00ff00CC Rotation Helper|r: Restored profile: " .. partySyncState.lastActiveProfile)
    end
    
    -- Keep the Party Sync profile - it's permanent and always available
    
    -- Clear persistent data since party sync ended normally
    addon.Config.global.partySyncLastActiveProfile = nil
    
    -- Reset sync state
    partySyncState.isActive = false
    partySyncState.leaderName = nil
    partySyncState.lastActiveProfile = nil
    partySyncState.isDirty = false
    partySyncState.lastSync = nil
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
        lastActiveProfile = partySyncState.lastActiveProfile,
        syncProfile = partySyncState.syncProfileName,
        isDirty = partySyncState.isDirty,
        lastSync = partySyncState.lastSync
    }
end

-- Check if profile selection should be locked (when in party sync as non-leader)
function addon.ProfileSync:IsProfileSelectionLocked()
    return partySyncState.isActive and partySyncState.leaderName ~= UnitName("player")
end

-- Get the name of the permanent party sync profile
function addon.ProfileSync:GetPartySyncProfileName()
    return partySyncState.syncProfileName
end

-- Sync to party, debounced in order to not spam syncs if multiple sync requests
-- are made right after eachother
function addon.ProfileSync:DebouncedSync(delay)
    if not partySyncState.isActive then return end
    delay = delay == nil and 10 or delay
    partySyncState.isDirty = true

    if partySyncState.lastSync == nil or GetTime() - partySyncState.lastSync > (delay * 2) then
        partySyncState.isDirty = false
        addon.Config:BroadcastProfileChangeIfLeader()
    else
        C_Timer.After(delay, function()
            -- If we don't need to resync, or it's not active anymore, then return early
            if not partySyncState.isDirty or not partySyncState.isActive then return end

            partySyncState.isDirty = false
            addon.Config:BroadcastProfileChangeIfLeader()
        end)
    end
end

-- Check if we need to restore profile after login (in case we logged out during party sync)
function addon.ProfileSync:CheckProfileRestoreOnLogin()
    local currentProfile = addon.Config:GetCurrentProfileName()
    local savedProfile = addon.Config.global.partySyncLastActiveProfile
    local inGroup = IsInGroup()
    
    print("|cff00ff00CC Rotation Helper|r: Login check - Current profile: " .. currentProfile)
    print("|cff00ff00CC Rotation Helper|r: Login check - Saved profile: " .. (savedProfile or "none"))
    print("|cff00ff00CC Rotation Helper|r: Login check - In group: " .. tostring(inGroup))
    print("|cff00ff00CC Rotation Helper|r: Login check - Sync profile name: " .. partySyncState.syncProfileName)
    
    -- If we're on the Party Sync profile but not in active party sync, switch away from it
    if currentProfile == partySyncState.syncProfileName and not partySyncState.isActive then
        if savedProfile then
            -- We have a saved profile to restore
            print("|cff00ff00CC Rotation Helper|r: Restoring saved profile: " .. savedProfile)
            addon.Config.database:SetProfile(savedProfile)
            addon.Config.global.partySyncLastActiveProfile = nil
            print("|cff00ff00CC Rotation Helper|r: Restored profile after login: " .. savedProfile)
        else
            -- No saved profile, switch to Default as fallback
            print("|cff00ff00CC Rotation Helper|r: No saved profile found, switching to Default")
            addon.Config.database:SetProfile("Default")
            print("|cff00ff00CC Rotation Helper|r: Switched to Default profile as fallback")
        end
        return
    end
    
    -- Handle party sync state restoration if we're still in a group
    if currentProfile == partySyncState.syncProfileName and inGroup and savedProfile then
        -- We're on Party Sync profile and in group - save the profile for later restoration
        partySyncState.lastActiveProfile = savedProfile
        print("|cff00ff00CC Rotation Helper|r: Restored party sync state from saved data")
    elseif not inGroup and savedProfile then
        -- We're not in group but have saved profile data - clear it since it's no longer relevant
        addon.Config.global.partySyncLastActiveProfile = nil
        print("|cff00ff00CC Rotation Helper|r: Cleared stale party sync profile data")
    else
        print("|cff00ff00CC Rotation Helper|r: No profile restoration needed")
    end
end

-- Transition from follower to leader mode when leadership is passed to us
function addon.ProfileSync:TransitionToLeader()
    if not partySyncState.isActive then return end
    
    local currentProfile = addon.Config:GetCurrentProfileName()
    
    -- Update leader name
    partySyncState.leaderName = UnitName("player")
    
    -- If we're currently on the Party Sync profile and have a saved profile, switch back
    if currentProfile == partySyncState.syncProfileName and partySyncState.lastActiveProfile then
        addon.Config.database:SetProfile(partySyncState.lastActiveProfile)
        print("|cff00ff00CC Rotation Helper|r: Became party leader - switched to profile: " .. partySyncState.lastActiveProfile)
    else
        print("|cff00ff00CC Rotation Helper|r: Became party leader - staying on current profile: " .. currentProfile)
    end
    
    -- Broadcast our current profile to party members
    C_Timer.After(1, function()
        self:BroadcastProfileAsLeader()
    end)
end