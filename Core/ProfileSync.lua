-- ProfileSync.lua - Simplified adapter for the new party sync system
-- This maintains compatibility with existing code while delegating to new components

local addonName, addon = ...

-- Legacy ProfileSync interface - delegates to new components
addon.ProfileSync = {}

-- User profile choice tracking
local userProfileTracking = {
    lastUserChosenProfile = nil
}

-- Communication prefix (for compatibility)
local COMM_PREFIX = "CCRH_SYNC"

-- Convenience function for debug messages - uses dedicated ProfileSync debug window
local function DebugPrint(category, ...)
    if addon.DebugFrame and addon.DebugFrame.Print then
        addon.DebugFrame:Print("ProfileSync", category, ...)
    end
end

function addon.ProfileSync:ShowDebugFrame()
    if addon.DebugFrame then
        addon.DebugFrame:ShowFrame("ProfileSync", "Party Sync Debug")
    end
end

function addon.ProfileSync:HideDebugFrame()
    if addon.DebugFrame then
        addon.DebugFrame:HideFrame("ProfileSync")
    end
end

function addon.ProfileSync:ToggleDebugFrame()
    if addon.DebugFrame then
        addon.DebugFrame:ToggleFrame("ProfileSync", "Party Sync Debug")
    end
end

-- Legacy user profile choice tracking
function addon.ProfileSync:TrackUserProfileChoice(profileName)
    userProfileTracking.lastUserChosenProfile = profileName
    
    -- Store in global config
    if addon.Config and addon.Config.global then
        addon.Config.global.lastUserChosenProfile = profileName
    end
    
    DebugPrint("profile", "User chose profile:", profileName)
end

function addon.ProfileSync:GetUserLastChosenProfile()
    return userProfileTracking.lastUserChosenProfile
end

-- Get recommended profile for when player becomes leader
function addon.ProfileSync:GetRecommendedLeaderProfile()
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

-- Initialize ProfileSync module (simplified)
function addon.ProfileSync:Initialize()
    DebugPrint("init", "Initializing legacy ProfileSync interface")
    
    -- Register communication handler (delegates to CommunicationManager)
    if addon.RegisterComm then
        addon:RegisterComm(COMM_PREFIX, function(prefix, message, distribution, sender)
            self:OnCommReceived(prefix, message, distribution, sender)
        end)
    end
    
    -- Register for group roster events (delegates to GroupManager)
    if addon.RegisterEvent then
        addon:RegisterEvent("GROUP_ROSTER_UPDATE", function() self:OnGroupRosterUpdate() end)
    end

    -- Register for config change events
    if addon.Config and addon.Config.RegisterEventListener then
        addon.Config:RegisterEventListener("PROFILE_DATA_CHANGED", function()
            self:DebouncedSync()
        end)
    end

    -- Ensure the permanent Party Sync profile exists
    self:EnsurePartySyncProfileExists()
    
    -- Initialize user profile tracking from saved variables
    if addon.Config and addon.Config.global and addon.Config.global.lastUserChosenProfile then
        userProfileTracking.lastUserChosenProfile = addon.Config.global.lastUserChosenProfile
    end
    
    -- Check if we need to restore profile after login
    self:CheckProfileRestoreOnLogin()
end

-- Legacy communication handler (delegates to CommunicationManager)
function addon.ProfileSync:OnCommReceived(prefix, message, distribution, sender)
    if addon.CommunicationManager then
        addon.CommunicationManager:OnCommReceived(prefix, message, distribution, sender)
    end
end

-- Legacy group roster handler (delegates to GroupManager)
function addon.ProfileSync:OnGroupRosterUpdate()
    if addon.GroupManager then
        addon.GroupManager:RefreshComposition()
    end
end

-- Legacy methods that delegate to new components
function addon.ProfileSync:GetGroupComposition()
    if addon.GroupManager then
        return addon.GroupManager:GetComposition()
    end
    return { inGroup = false, groupSize = 0, members = {} }
end

function addon.ProfileSync:GetPartyMembers()
    if addon.GroupManager then
        return addon.GroupManager:GetMemberNames()
    end
    return {}
end

function addon.ProfileSync:GetAddonUsers()
    if addon.CommunicationManager then
        return addon.CommunicationManager:GetAddonUsers()
    end
    return {}
end

function addon.ProfileSync:GetAddonUsersWithDetails()
    if addon.CommunicationManager then
        return addon.CommunicationManager:GetAddonUsersWithDetails()
    end
    return {}
end

function addon.ProfileSync:RefreshAddonUsers()
    if addon.CommunicationManager then
        return addon.CommunicationManager:PingAddonUsers()
    end
    return false
end

function addon.ProfileSync:GetGroupLeader()
    if addon.GroupManager then
        return addon.GroupManager:GetLeader()
    end
    return nil
end

-- Party sync status methods (delegate to new system)
function addon.ProfileSync:IsInPartySync()
    if addon.PartySyncOrchestrator then
        local syncInfo = addon.PartySyncOrchestrator:GetSyncInfo()
        return syncInfo.status == "active"
    end
    return false
end

function addon.ProfileSync:GetPartySyncInfo()
    if addon.PartySyncOrchestrator then
        local syncInfo = addon.PartySyncOrchestrator:GetSyncInfo()
        return {
            isActive = (syncInfo.status == "active"),
            leaderName = syncInfo.leader,
            participants = syncInfo.participants or {},
            syncProfile = syncInfo.syncProfile
        }
    end
    return { isActive = false }
end

function addon.ProfileSync:IsProfileSelectionLocked()
    if addon.PartySyncOrchestrator then
        return addon.PartySyncOrchestrator:IsProfileSelectionLocked()
    end
    return false
end

-- Profile management methods
function addon.ProfileSync:GetPartySyncProfileName()
    return "Party Sync"
end

function addon.ProfileSync:EnsurePartySyncProfileExists()
    local partySyncProfileName = self:GetPartySyncProfileName()
    
    if not addon.Config or not addon.Config.database then
        return false
    end
    
    -- Check if profile already exists
    local profiles = {}
    addon.Config.database:GetProfiles(profiles)
    
    for _, name in ipairs(profiles) do
        if name == partySyncProfileName then
            DebugPrint("profile", "Party sync profile already exists")
            return true
        end
    end
    
    -- Create the profile with default settings
    local currentProfile = addon.Config:GetCurrentProfileName()
    addon.Config.database:SetProfile(partySyncProfileName)
    
    -- Set default values for party sync profile
    addon.Config.database.profile.priorityPlayers = {}
    addon.Config.database.profile.customNPCs = {}
    addon.Config.database.profile.customSpells = {}
    addon.Config.database.profile.inactiveSpells = {}
    
    -- Switch back to original profile
    if currentProfile ~= partySyncProfileName then
        addon.Config.database:SetProfile(currentProfile)
    end
    
    DebugPrint("profile", "Created party sync profile:", partySyncProfileName)
    return true
end

-- Profile broadcasting (delegate to new system)
function addon.ProfileSync:BroadcastProfileAsLeader()
    if addon.PartySyncOrchestrator then
        local syncInfo = addon.PartySyncOrchestrator:GetSyncInfo()
        if syncInfo.status == "active" and syncInfo.profileData then
            if addon.CommunicationManager then
                addon.CommunicationManager:BroadcastAsLeader(syncInfo.profileData)
            end
        end
    end
end

-- Debounced sync functionality
local syncTimer = nil
function addon.ProfileSync:DebouncedSync(delay)
    delay = delay or 2
    
    if syncTimer then
        syncTimer:Cancel()
    end
    
    syncTimer = C_Timer.NewTimer(delay, function()
        syncTimer = nil
        
        -- If we're in an active sync and we're the leader, broadcast updates
        if self:IsInPartySync() and addon.GroupManager and addon.GroupManager:IsPlayerLeader() then
            self:BroadcastProfileAsLeader()
        end
        
        DebugPrint("sync", "Debounced sync executed")
    end)
end

-- Profile restoration on login
function addon.ProfileSync:CheckProfileRestoreOnLogin()
    local partySyncProfileName = self:GetPartySyncProfileName()
    local currentProfile = addon.Config and addon.Config:GetCurrentProfileName()
    
    -- If we're on the party sync profile but not in an active sync, switch back
    if currentProfile == partySyncProfileName and not self:IsInPartySync() then
        local lastProfile = self:GetUserLastChosenProfile()
        if lastProfile and lastProfile ~= partySyncProfileName then
            DebugPrint("restore", "Restoring profile after login:", lastProfile)
            if addon.Config then
                addon.Config:SetProfile(lastProfile)
            end
        end
    end
end

-- Leadership transition
function addon.ProfileSync:TransitionToLeader()
    DebugPrint("leadership", "Transitioning to leader role")
    
    -- This is now handled by the PartySyncOrchestrator
    if addon.PartySyncOrchestrator then
        local syncInfo = addon.PartySyncOrchestrator:GetSyncInfo()
        if syncInfo.status == "active" then
            self:BroadcastProfileAsLeader()
        end
    end
end

-- Compatibility methods for UI components
function addon.ProfileSync:PlayerHasAddon(playerName)
    if addon.CommunicationManager then
        local addonUsers = addon.CommunicationManager:GetAddonUsersWithDetails()
        for _, user in ipairs(addonUsers) do
            if user.name == playerName then
                return user.hasAddon
            end
        end
    end
    return false
end

-- Legacy party sync condition checking
function addon.ProfileSync:CheckPartySyncConditions()
    if addon.PartySyncState then
        return addon.PartySyncState:CanStartSync()
    end
    return false
end

-- Legacy party sync start
function addon.ProfileSync:StartPartySync()
    if addon.PartySyncOrchestrator then
        addon.PartySyncOrchestrator:ForceResync()
    end
end

-- Legacy cleanup
function addon.ProfileSync:CleanupPartySync()
    if addon.PartySyncState then
        addon.PartySyncState:Reset()
    end
end