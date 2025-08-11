-- ProfilesDataProvider.lua - Data abstraction layer for profile components
-- Provides clean interface between components and data layer

local addonName, addon = ...

local ProfilesDataProvider = {}

-- Get current profile information
function ProfilesDataProvider:getCurrentProfileInfo()
    return {
        name = addon.Config:GetCurrentProfileName(),
        isLocked = addon.Config:IsProfileSelectionLocked()
    }
end

-- Get party sync status
function ProfilesDataProvider:getPartySyncStatus()
    return addon.Config:GetPartySyncStatus()
end

-- Get list of all profiles
function ProfilesDataProvider:getProfileNames()
    return addon.Config:GetProfileNames()
end

-- Switch to a different profile
function ProfilesDataProvider:switchProfile(profileName)
    return addon.Config:SwitchProfile(profileName)
end

-- Create a new profile
function ProfilesDataProvider:createProfile(profileName)
    return addon.Config:CreateProfile(profileName)
end

-- Delete a profile
function ProfilesDataProvider:deleteProfile(profileName)
    return addon.Config:DeleteProfile(profileName)
end

-- Reset current profile
function ProfilesDataProvider:resetCurrentProfile()
    return addon.Config:ResetProfile()
end


-- Get addon users in party
function ProfilesDataProvider:getAddonUsers()
    if addon.ProfileSync and addon.ProfileSync.GetAddonUsers then
        return addon.ProfileSync:GetAddonUsers()
    end
    return {}
end

-- Refresh addon user detection
function ProfilesDataProvider:refreshAddonUsers()
    if addon.ProfileSync and addon.ProfileSync.RefreshAddonUsers then
        addon.ProfileSync:RefreshAddonUsers()
        return true
    end
    return false
end

-- Check if profile sync is available
function ProfilesDataProvider:isProfileSyncAvailable()
    return addon.ProfileSync ~= nil
end

-- Register in addon namespace
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.Profiles = ProfilesDataProvider

return ProfilesDataProvider