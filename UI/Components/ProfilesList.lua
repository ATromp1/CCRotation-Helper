-- ProfilesList.lua - Profile management components
-- Contains ProfileManagement, ProfileSync, and ProfileRequest components

local addonName, addon = ...
local BaseComponent = addon.BaseComponent

-- Helper function to create profile dropdown (moved from Component.lua)
local function createProfilesDropdown(label, onChange)
    local AceGUI = LibStub("AceGUI-3.0")
    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel(label)
    dropdown:SetWidth(200)
    local profiles = addon.Config:GetProfileNames()
    dropdown:SetList(profiles)

    if onChange then
        dropdown:SetCallback("OnValueChanged", function(widget, _event, index) 
            onChange(profiles[index], widget) 
        end)
    end

    function dropdown:RefreshProfiles()
        profiles = addon.Config:GetProfileNames()
        dropdown:SetList(profiles)
    end

    return dropdown
end

-- Profile Management Component - handles profile switching, creation, deletion, reset
local ProfileManagement = {}
setmetatable(ProfileManagement, {__index = BaseComponent})

function ProfileManagement:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.DataProviders.Profiles)
    setmetatable(instance, {__index = self})
    self:validateImplementation("ProfileManagement")
    
    -- Initialize event listeners for group changes
    instance:Initialize()
    
    return instance
end

function ProfileManagement:Initialize()
    -- Register for group status change events to refresh profile availability
    -- Using BaseComponent method for standardized registration
    self:RegisterEventListener("GROUP_STATUS_CHANGED", function(changeType)
        
        -- Handle profile switching when becoming leader
        if changeType == "became_leader" then
            self:handleBecameLeader()
        else
            self:refreshUI()
        end
    end)
end

function ProfileManagement:handleBecameLeader()
    -- Handle profile switching when becoming party leader
    if addon.ProfileSync and addon.ProfileSync.GetRecommendedLeaderProfile then
        local recommendedProfile = addon.ProfileSync:GetRecommendedLeaderProfile()
        local currentProfile = addon.Config:GetCurrentProfileName()
        
        if recommendedProfile ~= currentProfile then
            local success, msg = self.dataProvider:switchProfile(recommendedProfile)
            -- Profile switch result handled by dataProvider
        else
        end
    end
    
    -- Refresh UI after profile operations
    self:refreshUI()
end

function ProfileManagement:refreshUI()
    -- Clear current internal container and rebuild UI with updated party sync status
    if self.internalGroup then
        self.internalGroup:ReleaseChildren()
        self:buildInternalUI()
    end
end

function ProfileManagement:buildUI()
    -- Create internal container for this component's content
    self.internalGroup = self.AceGUI:Create("SimpleGroup")
    self.internalGroup:SetFullWidth(true)
    self.internalGroup:SetLayout("Flow")
    self.container:AddChild(self.internalGroup)
    
    -- Build the actual UI content
    self:buildInternalUI()
end

function ProfileManagement:buildInternalUI()
    
    local currentProfile = self.dataProvider:getCurrentProfileInfo()
    local partySyncStatus = self.dataProvider:getPartySyncStatus()
    
    -- Current profile display
    local currentLabel = self.AceGUI:Create("Label")
    currentLabel:SetText("Current Profile: " .. currentProfile.name)
    currentLabel:SetFullWidth(true)
    self.internalGroup:AddChild(currentLabel)
    
    -- Party sync status display
    local syncStatusLabel = self.AceGUI:Create("Label")
    if partySyncStatus.isActive then
        if partySyncStatus.leaderName == UnitName("player") then
            syncStatusLabel:SetText("|cff00ff00Party Sync Active|r - You are the leader")
        else
            syncStatusLabel:SetText("|cff00ff00Party Sync Active|r - Leader: " .. (partySyncStatus.leaderName or "Unknown"))
        end
        syncStatusLabel:SetColor(0, 1, 0)
    else
        syncStatusLabel:SetText("Party Sync: Inactive")
        syncStatusLabel:SetColor(0.7, 0.7, 0.7)
    end
    syncStatusLabel:SetFullWidth(true)
    self.internalGroup:AddChild(syncStatusLabel)
    
    -- Profile dropdown for switching
    self:buildProfileSwitcher(currentProfile, self.internalGroup)
    
    -- Create new profile section
    self:buildProfileCreator(self.internalGroup)
    
    -- Reset and delete buttons
    self:buildProfileActions(self.internalGroup)
end

function ProfileManagement:buildProfileSwitcher(currentProfile, container)
    local profileDropdown = self.AceGUI:Create("Dropdown")
    profileDropdown:SetLabel(currentProfile.isLocked and "Switch to Profile (Locked - Party Sync Active)" or "Switch to Profile")
    profileDropdown:SetWidth(200)
    profileDropdown:SetDisabled(currentProfile.isLocked)
    
    local profiles = self.dataProvider:getProfileNames()
    local profileList = {}
    local currentIndex = nil
    
    for i, name in ipairs(profiles) do
        profileList[i] = name
        if name == currentProfile.name then
            currentIndex = i
        end
    end
    
    profileDropdown:SetList(profileList)
    if currentIndex then
        profileDropdown:SetValue(currentIndex)
    end
    
    profileDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        local profileName = profiles[value]
        if profileName then
            local success, msg = self.dataProvider:switchProfile(profileName)
            if success then
                self:triggerCallback("onProfileSwitched", profileName)
            end
        end
    end)
    
    container:AddChild(profileDropdown)
end

function ProfileManagement:buildProfileCreator(container)
    local newProfileInput = self.AceGUI:Create("EditBox")
    newProfileInput:SetLabel("New Profile Name")
    newProfileInput:SetWidth(150)
    container:AddChild(newProfileInput)
    
    local createBtn = self.AceGUI:Create("Button")
    createBtn:SetText("Create")
    createBtn:SetWidth(80)
    createBtn:SetCallback("OnClick", function()
        local name = newProfileInput:GetText()
        if name and name ~= "" then
            local success, msg = self.dataProvider:createProfile(name)
            if success then
                newProfileInput:SetText("")
                self:triggerCallback("onProfileCreated", name)
            end
        end
    end)
    container:AddChild(createBtn)
end

function ProfileManagement:buildProfileActions(container)
    -- Reset profile button
    local resetBtn = self.AceGUI:Create("Button")
    resetBtn:SetText("Reset Current Profile")
    resetBtn:SetWidth(150)
    resetBtn:SetCallback("OnClick", function()
        local success, msg = self.dataProvider:resetCurrentProfile()
        if success then
            self:triggerCallback("onProfileReset")
        end
    end)
    container:AddChild(resetBtn)
    
    -- Delete profile dropdown
    container:AddChild(addon.UI.Helpers:VerticalSpacer(5))
    local deleteDropdown = createProfilesDropdown("Delete profile", function(profile, widget)
        if #self.dataProvider:getProfileNames() <= 1 then
            widget:SetValue(0)
            return
        end
        
        addon.UI.Helpers:ConfirmationDialog(
            "DELETE_PROFILE_CONFIRMATION",
            "Do you want to delete profile: "..profile.."?", 
            "Delete",
            function()
                local success, msg = self.dataProvider:deleteProfile(profile)
                if success then
                    self:triggerCallback("onProfileDeleted", profile)
                end
                widget:SetValue(0)
            end,
            "Cancel",
            function()
                widget:SetValue(0)
            end
        )
    end)
    container:AddChild(deleteDropdown)
end

-- Profile Sync Component - handles sharing profiles with party
local ProfileSync = {}
setmetatable(ProfileSync, {__index = BaseComponent})

function ProfileSync:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.DataProviders.Profiles)
    setmetatable(instance, {__index = self})
    self:validateImplementation("ProfileSync")
    
    -- Initialize event listeners for group changes
    instance:Initialize()
    
    return instance
end

function ProfileSync:Initialize()
    -- Register for group status change events to refresh sync status display
    -- Using BaseComponent method for standardized registration
    self:RegisterEventListener("GROUP_STATUS_CHANGED", function(changeType)
        self:refreshUI()
    end)
end

function ProfileSync:refreshUI()
    -- Clear current internal container and rebuild UI with updated sync status
    if self.syncInternalGroup then
        self.syncInternalGroup:ReleaseChildren()
        self:buildSyncInternalUI()
    end
end

function ProfileSync:buildUI()
    -- Create internal container for this component's content
    self.syncInternalGroup = self.AceGUI:Create("SimpleGroup")
    self.syncInternalGroup:SetFullWidth(true)
    self.syncInternalGroup:SetLayout("Flow")
    self.container:AddChild(self.syncInternalGroup)
    
    -- Build the actual UI content
    self:buildSyncInternalUI()
end

function ProfileSync:buildSyncInternalUI()
    
    -- Info text
    local infoLabel = self.AceGUI:Create("Label")
    infoLabel:SetText("Share profiles with party/raid members who also have CC Rotation Helper installed.")
    infoLabel:SetFullWidth(true)
    self.syncInternalGroup:AddChild(infoLabel)
    
    -- Share current profile button
    local syncCurrentBtn = self.AceGUI:Create("Button")
    syncCurrentBtn:SetText("Share Current Profile")
    syncCurrentBtn:SetWidth(200)
    syncCurrentBtn:SetCallback("OnClick", function()
        if not self.dataProvider:isProfileSyncAvailable() then
            return
        end
        
        self.dataProvider:shareCurrentProfile()
    end)
    self.syncInternalGroup:AddChild(syncCurrentBtn)
    
    self.syncInternalGroup:AddChild(addon.UI.Helpers:HorizontalSpacer(40))
    
    -- Profile selection dropdown for sharing specific profiles
    self:buildSpecificProfileSharer(self.syncInternalGroup)
end

function ProfileSync:buildSpecificProfileSharer(container)
    local profileToShare = nil
    local shareProfiles = self.dataProvider:getProfileNames()
    
    local shareProfileDropdown = self.AceGUI:Create("Dropdown")
    shareProfileDropdown:SetLabel("Share Specific Profile")
    shareProfileDropdown:SetWidth(200)
    
    local shareProfileList = {}
    for i, name in ipairs(shareProfiles) do
        shareProfileList[i] = name
    end
    shareProfileDropdown:SetList(shareProfileList)
    shareProfileDropdown:SetCallback("OnValueChanged", function(_, _, value)
        if not self.dataProvider:isProfileSyncAvailable() then
            return
        end
        profileToShare = shareProfiles[value] or nil
    end)
    container:AddChild(shareProfileDropdown)
    
    local shareProfileButton = self.AceGUI:Create("Button")
    shareProfileButton:SetText("Share selected profile")
    shareProfileButton:SetWidth(150)
    shareProfileButton:SetCallback("OnClick", function()
        if profileToShare == nil then
            return
        end
        
        self.dataProvider:shareProfile(profileToShare)
    end)
    container:AddChild(shareProfileButton)
end

-- Profile Request Component - handles requesting profiles from party members
local ProfileRequest = {}
setmetatable(ProfileRequest, {__index = BaseComponent})

function ProfileRequest:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.DataProviders.Profiles)
    setmetatable(instance, {__index = self})
    self:validateImplementation("ProfileRequest")
    
    -- Initialize event listeners for group changes
    instance:Initialize()
    
    return instance
end

function ProfileRequest:Initialize()
    -- Register for group status change events to refresh addon user list
    -- Using BaseComponent method for standardized registration
    self:RegisterEventListener("GROUP_STATUS_CHANGED", function(changeType)
        self:refreshUI()
    end)
end

function ProfileRequest:refreshUI()
    -- Clear current internal container and rebuild UI with updated addon users
    if self.requestInternalGroup then
        self.requestInternalGroup:ReleaseChildren()
        self:buildRequestInternalUI()
    end
end

function ProfileRequest:buildUI()
    -- Create internal container for this component's content
    self.requestInternalGroup = self.AceGUI:Create("SimpleGroup")
    self.requestInternalGroup:SetFullWidth(true)
    self.requestInternalGroup:SetLayout("Flow")
    self.container:AddChild(self.requestInternalGroup)
    
    -- Build the actual UI content
    self:buildRequestInternalUI()
end

function ProfileRequest:buildRequestInternalUI()
    
    local members = self.dataProvider:getAddonUsers()
    
    -- Add placeholder if no addon users found
    if #members == 0 then
        members = {"(No addon users found)"}
    end
    
    -- Party member dropdown
    local partyDropdown = self.AceGUI:Create("Dropdown")
    partyDropdown:SetLabel("Party Member (with addon)")
    partyDropdown:SetWidth(150)
    
    local memberList = {}
    for i, name in ipairs(members) do
        memberList[i] = name
    end
    partyDropdown:SetList(memberList)
    self.requestInternalGroup:AddChild(partyDropdown)
    
    -- Profile name input
    local profileInput = self.AceGUI:Create("EditBox")
    profileInput:SetLabel("Profile Name")
    profileInput:SetWidth(150)
    self.requestInternalGroup:AddChild(profileInput)
    
    -- Request button
    local requestBtn = self.AceGUI:Create("Button")
    requestBtn:SetText("Request Profile")
    requestBtn:SetWidth(120)
    requestBtn:SetCallback("OnClick", function()
        if not self.dataProvider:isProfileSyncAvailable() then
            return
        end
        
        local selectedIndex = partyDropdown:GetValue()
        local selectedMember = members[selectedIndex]
        local profileName = profileInput:GetText()
        
        if not selectedMember or selectedMember == "" or selectedMember == "(No addon users found)" then
            return
        end
        
        if not profileName or profileName == "" then
            return
        end
        
        self.dataProvider:requestProfile(selectedMember, profileName)
    end)
    self.requestInternalGroup:AddChild(requestBtn)
    
    -- Refresh addon users button
    local refreshBtn = self.AceGUI:Create("Button")
    refreshBtn:SetText("Scan for Addon Users")
    refreshBtn:SetWidth(150)
    refreshBtn:SetCallback("OnClick", function()
        if self.dataProvider:refreshAddonUsers() then
            -- Refresh dropdown after a short delay to allow responses
            C_Timer.After(2, function()
                local newMembers = self.dataProvider:getAddonUsers()
                
                -- Add placeholder if no addon users found
                if #newMembers == 0 then
                    newMembers = {"(No addon users found)"}
                end
                
                local newMemberList = {}
                for i, name in ipairs(newMembers) do
                    newMemberList[i] = name
                end
                partyDropdown:SetList(newMemberList)
                partyDropdown:SetValue(nil)
                
                -- Update the members variable for the callback
                members = newMembers
            end)
        end
    end)
    self.requestInternalGroup:AddChild(refreshBtn)
end

-- Register components in addon namespace
if not addon.Components then
    addon.Components = {}
end
addon.Components.ProfileManagement = ProfileManagement
addon.Components.ProfileSync = ProfileSync
addon.Components.ProfileRequest = ProfileRequest