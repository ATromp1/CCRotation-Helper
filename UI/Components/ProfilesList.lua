-- ProfilesList.lua - Profile management components  
-- Contains ProfileManagement and AddonUsersList components

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
    local instance = BaseComponent:new(container, callbacks, addon.Components.DataManager)
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
        addon.Config:DebugPrint("ProfileManagement: GROUP_STATUS_CHANGED event -", changeType)
        
        -- Handle profile switching when becoming leader
        if changeType == "became_leader" then
            addon.Config:DebugPrint("ProfileManagement: Handling became_leader event")
            self:handleBecameLeader()
        else  
            -- refreshUI will check if tab is active internally
            self:refreshUI()
        end
    end)
    
    -- Register for profile sync events to update locked status
    self:RegisterEventListener("PROFILE_SYNC_RECEIVED", function(profileData)
        addon.Config:DebugPrint("ProfileManagement: PROFILE_SYNC_RECEIVED - refreshing UI to show locked state")
        self:refreshUI()
    end)
end

function ProfileManagement:handleBecameLeader()
    -- Handle profile switching when becoming party leader
    if addon.PartySync and addon.PartySync.GetRecommendedLeaderProfile then
        local recommendedProfile = addon.PartySync:GetRecommendedLeaderProfile()
        local currentProfile = addon.Config:GetCurrentProfileName()
        
        if recommendedProfile ~= currentProfile then
            local success, msg = addon.Config:SwitchProfile(recommendedProfile)
            -- Profile switch result handled by dataProvider
        else
        end
    end
    
    -- refreshUI will check if tab is active internally
    self:refreshUI()
end

function ProfileManagement:refreshUI()
    -- Only refresh if the profiles tab is currently active
    if not (addon.UI and addon.UI:IsConfigTabActive("profiles")) then
        return
    end
    
    addon.Config:DebugPrint("ProfileManagement:refreshUI - Refreshing UI")
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
    
    local currentProfile = self.dataProvider.profiles:getCurrentProfileInfo()
    local partySyncStatus = addon.Config:GetPartySyncStatus()
    
    -- Current profile display (or party sync status)
    local currentLabel = self.AceGUI:Create("Label")
    if currentProfile.isLocked then
        currentLabel:SetText("Party Sync Active")
        currentLabel:SetColor(0, 1, 0) -- Green color to indicate active sync
    else
        currentLabel:SetText("Current Profile: " .. currentProfile.name)
        currentLabel:SetColor(1, 1, 1) -- Default white color
    end
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
    
    local profiles = addon.Config:GetProfileNames()
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
            local success, msg = addon.Config:SwitchProfile(profileName)
            if success then
                self:triggerCallback("onProfileSwitched", profileName)
                -- Refresh UI to update current profile display
                self:refreshUI()
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
            local success, msg = addon.Config:CreateProfile(name)
            if success then
                newProfileInput:SetText("")
                self:triggerCallback("onProfileCreated", name)
                -- Refresh UI to show the new profile in dropdown
                self:refreshUI()
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
        local success, msg = addon.Config:ResetProfile()
        if success then
            self:triggerCallback("onProfileReset")
        end
    end)
    container:AddChild(resetBtn)
    
    -- Delete profile dropdown
    container:AddChild(addon.UI.Helpers:VerticalSpacer(5))
    local deleteDropdown = createProfilesDropdown("Delete profile", function(profile, widget)
        if #addon.Config:GetProfileNames() <= 1 then
            widget:SetValue(0)
            return
        end
        
        addon.UI.Helpers:ConfirmationDialog(
            "DELETE_PROFILE_CONFIRMATION",
            "Do you want to delete profile: "..profile.."?", 
            "Delete",
            function()
                local success, msg = addon.Config:DeleteProfile(profile)
                if success then
                    self:triggerCallback("onProfileDeleted", profile)
                    -- Refresh UI to update profile dropdown
                    self:refreshUI()
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

-- Addon Users List Component - shows group members and their addon status
local AddonUsersList = {}
setmetatable(AddonUsersList, {__index = BaseComponent})

function AddonUsersList:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.Components.DataManager)
    setmetatable(instance, {__index = self})
    self:validateImplementation("AddonUsersList")
    
    -- Initialize event listeners for group changes
    instance:Initialize()
    
    return instance
end

function AddonUsersList:Initialize()
    -- Register for group status change events to refresh user list
    self:RegisterEventListener("GROUP_STATUS_CHANGED", function(changeType)
        -- refreshUI will check if tab is active internally
        self:refreshUI()
    end)
end

function AddonUsersList:refreshUI()
    -- Only refresh if the profiles tab is currently active
    if not (addon.UI and addon.UI:IsConfigTabActive("profiles")) then
        return
    end
    
    addon.Config:DebugPrint("AddonUsersList:refreshUI - Refreshing UI")
    -- Clear current internal container and rebuild UI with updated user list
    if self.usersInternalGroup then
        self.usersInternalGroup:ReleaseChildren()
        self:buildUsersInternalUI()
    end
end

function AddonUsersList:buildUI()
    -- Create internal container for this component's content
    self.usersInternalGroup = self.AceGUI:Create("SimpleGroup")
    self.usersInternalGroup:SetFullWidth(true)
    self.usersInternalGroup:SetLayout("Flow")
    self.container:AddChild(self.usersInternalGroup)
    
    -- Build the actual UI content
    self:buildUsersInternalUI()
end

function AddonUsersList:buildUsersInternalUI()
    -- Check if we're in a group
    if not IsInGroup() then
        local soloLabel = self.AceGUI:Create("Label")
        soloLabel:SetText("|cff888888Not in a group - addon detection only works in groups|r")
        soloLabel:SetFullWidth(true)
        self.usersInternalGroup:AddChild(soloLabel)
        return
    end
    
    -- Get detailed addon user information
    local addonUsersInfo = {}
    
    if #addonUsersInfo == 0 then
        local noUsersLabel = self.AceGUI:Create("Label")
        noUsersLabel:SetText("|cff888888No addon users detected - try scanning|r")
        noUsersLabel:SetFullWidth(true)
        self.usersInternalGroup:AddChild(noUsersLabel)
        return
    end
    
    -- Display each user
    for _, userInfo in ipairs(addonUsersInfo) do
        local userRowGroup = self.AceGUI:Create("SimpleGroup")
        userRowGroup:SetFullWidth(true)
        userRowGroup:SetLayout("Flow")
        self.usersInternalGroup:AddChild(userRowGroup)
        
        -- Player name
        local nameLabel = self.AceGUI:Create("Label")
        local nameText = userInfo.name
        if userInfo.isYou then
            nameText = nameText .. " (You)"
        end
        nameLabel:SetText(nameText)
        nameLabel:SetWidth(150)
        userRowGroup:AddChild(nameLabel)
        
        -- Addon status and version
        local statusLabel = self.AceGUI:Create("Label")
        if userInfo.hasAddon then
            local versionText = userInfo.addonVersion or "Unknown"
            statusLabel:SetText("|cff00ff00Has Addon|r - v" .. versionText)
        else
            statusLabel:SetText("|cffff4444No Addon|r")
        end
        statusLabel:SetWidth(150)
        userRowGroup:AddChild(statusLabel)
        
        -- Last seen (for non-current users)
        if not userInfo.isYou and userInfo.hasAddon and userInfo.lastSeen then
            local timeSince = time() - userInfo.lastSeen
            local timeText
            if timeSince < 60 then
                timeText = "Just now"
            elseif timeSince < 3600 then
                timeText = math.floor(timeSince / 60) .. "m ago"
            else
                timeText = math.floor(timeSince / 3600) .. "h ago"
            end
            
            local timeLabel = self.AceGUI:Create("Label")
            timeLabel:SetText("|cff888888" .. timeText .. "|r")
            timeLabel:SetWidth(100)
            userRowGroup:AddChild(timeLabel)
        end
    end
    
    -- Show sync status
    local partySyncInfo = addon.PartySync and addon.PartySync:GetPartySyncInfo() or {isActive = false}
    local syncStatusLabel = self.AceGUI:Create("Label")
    if partySyncInfo.isActive then
        syncStatusLabel:SetText("|cff00ff00Party Sync: Active|r")
    else
        local addonUserCount = 0
        for _, userInfo in ipairs(addonUsersInfo) do
            if userInfo.hasAddon then
                addonUserCount = addonUserCount + 1
            end
        end
        
        if addonUserCount >= 2 then
            syncStatusLabel:SetText("|cffffff00Party Sync: Ready (waiting for conditions)|r")
        else
            syncStatusLabel:SetText("|cffff4444Party Sync: Inactive (need 2+ addon users)|r")
        end
    end
    syncStatusLabel:SetFullWidth(true)
    self.usersInternalGroup:AddChild(syncStatusLabel)
    
    -- Manual refresh button
    if IsInGroup() then
        local refreshButton = self.AceGUI:Create("Button")
        refreshButton:SetText("Scan for Addon Users")
        refreshButton:SetWidth(150)
        refreshButton:SetCallback("OnClick", function()
            if self.usersInternalGroup then
                self:refreshUI()
            end
        end)
        self.usersInternalGroup:AddChild(refreshButton)
    end
end

-- Register components in addon namespace
if not addon.Components then
    addon.Components = {}
end
addon.Components.ProfileManagement = ProfileManagement
addon.Components.AddonUsersList = AddonUsersList