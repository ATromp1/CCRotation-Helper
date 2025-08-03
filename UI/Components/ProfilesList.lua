-- ProfilesList.lua - Profile management components
-- Contains ProfileManagement, ProfileSync, and ProfileRequest components

local addonName, addon = ...
local BaseComponent = addon.BaseComponent

-- Profile Management Component - handles profile switching, creation, deletion, reset
local ProfileManagement = {}
setmetatable(ProfileManagement, {__index = BaseComponent})

function ProfileManagement:new(container, callbacks)
    local instance = BaseComponent:new(container, callbacks, addon.DataProviders.Profiles)
    setmetatable(instance, {__index = self})
    self:validateImplementation("ProfileManagement")
    return instance
end

function ProfileManagement:buildUI()
    -- Create internal container for this component's content
    local internalGroup = self.AceGUI:Create("SimpleGroup")
    internalGroup:SetFullWidth(true)
    internalGroup:SetLayout("Flow")
    self.container:AddChild(internalGroup)
    
    local currentProfile = self.dataProvider:getCurrentProfileInfo()
    local partySyncStatus = self.dataProvider:getPartySyncStatus()
    
    -- Current profile display
    local currentLabel = self.AceGUI:Create("Label")
    currentLabel:SetText("Current Profile: " .. currentProfile.name)
    currentLabel:SetFullWidth(true)
    internalGroup:AddChild(currentLabel)
    
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
    internalGroup:AddChild(syncStatusLabel)
    
    -- Profile dropdown for switching
    self:buildProfileSwitcher(currentProfile, internalGroup)
    
    -- Create new profile section
    self:buildProfileCreator(internalGroup)
    
    -- Reset and delete buttons
    self:buildProfileActions(internalGroup)
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
                print("|cff00ff00CC Rotation Helper|r: " .. msg)
                self:triggerCallback("onProfileSwitched", profileName)
            else
                print("|cffff0000CC Rotation Helper|r: " .. msg)
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
                print("|cff00ff00CC Rotation Helper|r: " .. msg)
                self:triggerCallback("onProfileCreated", name)
            else
                print("|cffff0000CC Rotation Helper|r: " .. msg)
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
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
            self:triggerCallback("onProfileReset")
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
    end)
    container:AddChild(resetBtn)
    
    -- Delete profile dropdown
    container:AddChild(addon.UI.Component:VerticalSpacer(5))
    local deleteDropdown = addon.UI.Component:ProfilesDropdown("Delete profile", function(profile, widget)
        if #self.dataProvider:getProfileNames() <= 1 then
            print("|cffff0000CC Rotation Helper|r: You cannot delete your last profile")
            widget:SetValue(0)
            return
        end
        
        addon.UI.Component:ConfirmationDialog(
            "DELETE_PROFILE_CONFIRMATION",
            "Do you want to delete profile: "..profile.."?", 
            "Delete",
            function()
                local success, msg = self.dataProvider:deleteProfile(profile)
                if success then
                    print("|cff00ff00CC Rotation Helper|r: " .. msg)
                    self:triggerCallback("onProfileDeleted", profile)
                else
                    print("|cffff0000CC Rotation Helper|r: " .. msg)
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
    return instance
end

function ProfileSync:buildUI()
    -- Create internal container for this component's content
    local internalGroup = self.AceGUI:Create("SimpleGroup")
    internalGroup:SetFullWidth(true)
    internalGroup:SetLayout("Flow")
    self.container:AddChild(internalGroup)
    
    -- Info text
    local infoLabel = self.AceGUI:Create("Label")
    infoLabel:SetText("Share profiles with party/raid members who also have CC Rotation Helper installed.")
    infoLabel:SetFullWidth(true)
    internalGroup:AddChild(infoLabel)
    
    -- Share current profile button
    local syncCurrentBtn = self.AceGUI:Create("Button")
    syncCurrentBtn:SetText("Share Current Profile")
    syncCurrentBtn:SetWidth(200)
    syncCurrentBtn:SetCallback("OnClick", function()
        if not self.dataProvider:isProfileSyncAvailable() then
            print("|cffff0000CC Rotation Helper|r: Profile sync not available")
            return
        end
        
        local success, msg = self.dataProvider:shareCurrentProfile()
        if success then
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
    end)
    internalGroup:AddChild(syncCurrentBtn)
    
    internalGroup:AddChild(addon.UI.Component:HorizontalSpacer(40))
    
    -- Profile selection dropdown for sharing specific profiles
    self:buildSpecificProfileSharer(internalGroup)
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
            print("|cffff0000CC Rotation Helper|r: Profile sync not available")
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
            print("|cffff0000CC Rotation Helper|r: No profile selected")
            return
        end
        
        local success, msg = self.dataProvider:shareProfile(profileToShare)
        if success then
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
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
    return instance
end

function ProfileRequest:buildUI()
    -- Create internal container for this component's content
    local internalGroup = self.AceGUI:Create("SimpleGroup")
    internalGroup:SetFullWidth(true)
    internalGroup:SetLayout("Flow")
    self.container:AddChild(internalGroup)
    
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
    internalGroup:AddChild(partyDropdown)
    
    -- Profile name input
    local profileInput = self.AceGUI:Create("EditBox")
    profileInput:SetLabel("Profile Name")
    profileInput:SetWidth(150)
    internalGroup:AddChild(profileInput)
    
    -- Request button
    local requestBtn = self.AceGUI:Create("Button")
    requestBtn:SetText("Request Profile")
    requestBtn:SetWidth(120)
    requestBtn:SetCallback("OnClick", function()
        if not self.dataProvider:isProfileSyncAvailable() then
            print("|cffff0000CC Rotation Helper|r: Profile sync not available")
            return
        end
        
        local selectedIndex = partyDropdown:GetValue()
        local selectedMember = members[selectedIndex]
        local profileName = profileInput:GetText()
        
        if not selectedMember or selectedMember == "" or selectedMember == "(No addon users found)" then
            print("|cffff0000CC Rotation Helper|r: Please select a valid party member with the addon")
            return
        end
        
        if not profileName or profileName == "" then
            print("|cffff0000CC Rotation Helper|r: Please enter a profile name")
            return
        end
        
        local success, msg = self.dataProvider:requestProfile(selectedMember, profileName)
        if success then
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
    end)
    internalGroup:AddChild(requestBtn)
    
    -- Refresh addon users button
    local refreshBtn = self.AceGUI:Create("Button")
    refreshBtn:SetText("Scan for Addon Users")
    refreshBtn:SetWidth(150)
    refreshBtn:SetCallback("OnClick", function()
        if self.dataProvider:refreshAddonUsers() then
            print("|cff00ff00CC Rotation Helper|r: Pinging party members for addon detection...")
            
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
                
                local count = #newMembers == 1 and newMembers[1] == "(No addon users found)" and "0" or tostring(#newMembers)
                print("|cff00ff00CC Rotation Helper|r: Found " .. count .. " party members with the addon")
            end)
        else
            print("|cffff0000CC Rotation Helper|r: Profile sync not available")
        end
    end)
    internalGroup:AddChild(refreshBtn)
end

-- Register components in addon namespace
if not addon.Components then
    addon.Components = {}
end
addon.Components.ProfileManagement = ProfileManagement
addon.Components.ProfileSync = ProfileSync
addon.Components.ProfileRequest = ProfileRequest