local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

-- Configuration frame using AceGUI
function addon.UI:CreateConfigFrame()
    if self.configFrame then 
        self.configFrame:Show()
        return 
    end
    
    -- Create main frame using AceGUI
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("CC Rotation Helper - Configuration")
    frame:SetStatusText("Configure your CC rotation settings")
    frame:SetWidth(900)
    frame:SetHeight(800)
    frame:SetLayout("Fill")
    
    -- Create tab group for organized settings
    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetTabs({
        {text="Profiles", value="profiles"},
        {text="Display", value="display"},
        {text="Text", value="text"}, 
        {text="Icons", value="icons"},
        {text="Spells", value="spells"},
        {text="Npcs", value="npcs"},
        {text="Players", value="players"}
    })
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        function container:RefreshCurrentTab()
            tabGroup:SelectTab(group)
        end

        container:ReleaseChildren()
        if group == "profiles" then
            self:CreateProfilesTab(container)
        elseif group == "display" then
            self:CreateDisplayTab(container)
        elseif group == "text" then
            self:CreateTextTab(container)
        elseif group == "icons" then
            self:CreateIconsTab(container)
        elseif group == "spells" then
            self:CreateSpellsTab(container)
        elseif group == "npcs" then
            self:CreateNpcsTab(container)
        elseif group == "players" then
            self:CreatePlayersTab(container)
        end
    end)
    tabGroup:SelectTab("profiles")
    frame:AddChild(tabGroup)
    
    -- Store reference
    self.configFrame = frame
    
    -- Handle frame closing
    frame:SetCallback("OnClose", function(widget)
        widget:Hide()
    end)
end

-- Create Profiles tab content using AceDBOptions
function addon.UI:CreateProfilesTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Standard AceDB profile management - create manual UI instead of using AceConfigDialog
    local profileGroup = AceGUI:Create("InlineGroup")
    profileGroup:SetFullWidth(true)
    profileGroup:SetTitle("Profile Management")
    profileGroup:SetLayout("Flow")
    scroll:AddChild(profileGroup)
    
    -- Current profile display
    local currentLabel = AceGUI:Create("Label")
    currentLabel:SetText("Current Profile: " .. addon.Config:GetCurrentProfileName())
    currentLabel:SetFullWidth(true)
    profileGroup:AddChild(currentLabel)
    
    -- Profile dropdown for switching
    local profileDropdown = AceGUI:Create("Dropdown")
    profileDropdown:SetLabel("Switch to Profile")
    profileDropdown:SetWidth(200)
    local profiles = addon.Config:GetProfileNames()
    
    -- Create proper dropdown list format for AceGUI
    local profileList = {}
    for i, name in ipairs(profiles) do
        profileList[i] = name  -- Use numeric indices for AceGUI dropdown
    end
    profileDropdown:SetList(profileList)
    
    -- Find the current profile index
    local currentProfile = addon.Config:GetCurrentProfileName()
    local currentIndex = nil
    for i, name in ipairs(profiles) do
        if name == currentProfile then
            currentIndex = i
            break
        end
    end
    if currentIndex then
        profileDropdown:SetValue(currentIndex)
    end
    profileDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        -- Get fresh profile list since it might have changed
        local currentProfiles = addon.Config:GetProfileNames()
        local profileName = currentProfiles[value]
        if profileName then
            local success, msg = addon.Config:SwitchProfile(profileName)
            if success then
                currentLabel:SetText("Current Profile: " .. profileName)
                print("|cff00ff00CC Rotation Helper|r: " .. msg)
            else
                print("|cffff0000CC Rotation Helper|r: " .. msg)
            end
        end
    end)
    profileGroup:AddChild(profileDropdown)
    
    -- Create new profile
    local newProfileInput = AceGUI:Create("EditBox")
    newProfileInput:SetLabel("New Profile Name")
    newProfileInput:SetWidth(150)
    profileGroup:AddChild(newProfileInput)
    
    local createBtn = AceGUI:Create("Button")
    createBtn:SetText("Create")
    createBtn:SetWidth(80)
    createBtn:SetCallback("OnClick", function()
        local name = newProfileInput:GetText()
        if name and name ~= "" then
            local success, msg = addon.Config:CreateProfile(name)
            if success then
                -- Refresh dropdown with new profile list
                local newProfiles = addon.Config:GetProfileNames()
                local newProfileList = {}
                for i, pname in ipairs(newProfiles) do
                    newProfileList[i] = pname
                end
                profileDropdown:SetList(newProfileList)
                
                -- Update the profiles variable for callbacks
                profiles = newProfiles
                
                -- Find and select the newly created profile
                local newProfileIndex = nil
                for i, pname in ipairs(newProfiles) do
                    if pname == name then
                        newProfileIndex = i
                        break
                    end
                end
                if newProfileIndex then
                    profileDropdown:SetValue(newProfileIndex)
                    currentLabel:SetText("Current Profile: " .. name)
                end
                
                newProfileInput:SetText("")
                print("|cff00ff00CC Rotation Helper|r: " .. msg)
            else
                print("|cffff0000CC Rotation Helper|r: " .. msg)
            end
        end
    end)
    profileGroup:AddChild(createBtn)
    
    -- Reset profile button
    local resetBtn = AceGUI:Create("Button")
    resetBtn:SetText("Reset Current Profile")
    resetBtn:SetWidth(150)
    resetBtn:SetCallback("OnClick", function()
        local success, msg = addon.Config:ResetProfile()
        if success then
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
    end)
    profileGroup:AddChild(resetBtn)

    profileGroup:AddChild(addon.UI.Component:VerticalSpacer(5))
    local deleteDropdown = addon.UI.Component:ProfilesDropdown("Delete profile", function(profile, widget)
        if #addon.Config:GetProfileNames() <= 1 then
            print("|cffff0000CC Rotation Helper|r: You cannot delete your last profile")
            widget:SetValue(0)
            return
        end

        addon.UI.Component:ConfirmationDialog(
            "DELETE_PROFILE_CONFIRMATION",
            "Do you want to delete profile: "..profile.."?", 
            "Delete",
            function()
                local success, msg = addon.Config:DeleteProfile(profile)
                if success then
                    container:RefreshCurrentTab()
                    print("|cff00ff00CC Rotation Helper|r: " .. msg)
                else
                    print("|cffff0000CC Rotation Helper|r: " .. msg)
                end

                -- Set dropdown to unselected value
                widget:SetValue(0)
            end,
            "Cancel",
            function()
                -- Set dropdown to unselected value
                widget:SetValue(0)
            end
        )
    end)
    profileGroup:AddChild(deleteDropdown)
    
    -- Profile Sync section
    local syncGroup = AceGUI:Create("InlineGroup")
    syncGroup:SetFullWidth(true)
    syncGroup:SetTitle("Profile Sync (Party/Raid)")
    syncGroup:SetLayout("Flow")
    scroll:AddChild(syncGroup)
    
    -- Info text
    local infoLabel = AceGUI:Create("Label")
    infoLabel:SetText("Share profiles with party/raid members who also have CC Rotation Helper installed.")
    infoLabel:SetFullWidth(true)
    syncGroup:AddChild(infoLabel)
    
    -- Current profile sync button
    local syncCurrentBtn = AceGUI:Create("Button")
    syncCurrentBtn:SetText("Share Current Profile")
    syncCurrentBtn:SetWidth(200)
    syncCurrentBtn:SetCallback("OnClick", function()
        if not addon.ProfileSync then
            print("|cffff0000CC Rotation Helper|r: Profile sync not available")
            return
        end
        local success, msg = addon.Config:SyncProfileToParty()
        if success then
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
    end)
    syncGroup:AddChild(syncCurrentBtn)

    syncGroup:AddChild(addon.UI.Component:HorizontalSpacer(40))
    
    -- Profile selection dropdown for sharing specific profiles
    local shareProfileDropdown = AceGUI:Create("Dropdown")
    shareProfileDropdown:SetLabel("Share Specific Profile")
    shareProfileDropdown:SetWidth(200)
    local shareProfiles = addon.Config:GetProfileNames()
    local shareProfileList = {}
    local profileToShare = nil
    for i, name in ipairs(shareProfiles) do
        shareProfileList[i] = name
    end
    shareProfileDropdown:SetList(shareProfileList)
    shareProfileDropdown:SetCallback("OnValueChanged", function(_, _, value)
        if not addon.ProfileSync then
            print("|cffff0000CC Rotation Helper|r: Profile sync not available")
            return
        end
        -- value is the index, get the profile name
        profileToShare = shareProfiles[value] or nil
    end)
    syncGroup:AddChild(shareProfileDropdown)

    local shareProfileButton = AceGUI:Create("Button")
    shareProfileButton:SetText("Share selected profile")
    shareProfileButton:SetWidth(150)
    shareProfileButton:SetCallback("OnClick", function()
        if profileToShare == nil then
            print("|cffff0000CC Rotation Helper|r: No profile selected")
            return
        end

        local success, msg = addon.Config:SyncProfileToParty(profileToShare)
        if success then
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
    end)
    syncGroup:AddChild(shareProfileButton)

    -- Request profile section
    local requestGroup = AceGUI:Create("InlineGroup")
    requestGroup:SetFullWidth(true)
    requestGroup:SetTitle("Request Profile from Party Member")
    requestGroup:SetLayout("Flow")
    scroll:AddChild(requestGroup)
    
    -- Party member dropdown
    local partyDropdown = AceGUI:Create("Dropdown")
    partyDropdown:SetLabel("Party Member (with addon)")
    partyDropdown:SetWidth(150)
    local members = {}
    if addon.ProfileSync and addon.ProfileSync.GetAddonUsers then
        members = addon.ProfileSync:GetAddonUsers()
    end
    
    -- Add placeholder if no addon users found
    if #members == 0 then
        members = {"(No addon users found)"}
    end
    
    local memberList = {}
    for i, name in ipairs(members) do
        memberList[i] = name
    end
    partyDropdown:SetList(memberList)
    requestGroup:AddChild(partyDropdown)
    
    -- Profile name input
    local profileInput = AceGUI:Create("EditBox")
    profileInput:SetLabel("Profile Name")
    profileInput:SetWidth(150)
    requestGroup:AddChild(profileInput)
    
    -- Request button
    local requestBtn = AceGUI:Create("Button")
    requestBtn:SetText("Request Profile")
    requestBtn:SetWidth(120)
    requestBtn:SetCallback("OnClick", function()
        if not addon.ProfileSync then
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
        
        local success, msg = addon.Config:RequestProfileFromPlayer(selectedMember, profileName)
        if success then
            print("|cff00ff00CC Rotation Helper|r: " .. msg)
        else
            print("|cffff0000CC Rotation Helper|r: " .. msg)
        end
    end)
    requestGroup:AddChild(requestBtn)
    
    -- Refresh addon users button
    local refreshBtn = AceGUI:Create("Button")
    refreshBtn:SetText("Scan for Addon Users")
    refreshBtn:SetWidth(150)
    refreshBtn:SetCallback("OnClick", function()
        -- Trigger addon detection ping
        if addon.ProfileSync and addon.ProfileSync.RefreshAddonUsers then
            addon.ProfileSync:RefreshAddonUsers()
            
            -- Refresh dropdown after a short delay to allow responses
            C_Timer.After(2, function()
                local newMembers = {}
                if addon.ProfileSync and addon.ProfileSync.GetAddonUsers then
                    newMembers = addon.ProfileSync:GetAddonUsers()
                end
                
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
    requestGroup:AddChild(refreshBtn)
end

-- Create Display tab content
function addon.UI:CreateDisplayTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Main enabled checkbox
    local enabledCheck = AceGUI:Create("CheckBox")
    enabledCheck:SetLabel("Enable CC Rotation Helper")
    enabledCheck:SetValue(addon.Config:Get("enabled"))
    enabledCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("enabled", value)
        if addon.UI.UpdateVisibility then
            addon.UI:UpdateVisibility()
        end
    end)
    enabledCheck:SetFullWidth(true)
    scroll:AddChild(enabledCheck)
    
    -- Show in solo checkbox
    local soloCheck = AceGUI:Create("CheckBox")
    soloCheck:SetLabel("Show when not in group")
    soloCheck:SetValue(addon.Config:Get("showInSolo"))
    soloCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showInSolo", value)
        
        -- Rebuild queue first in case visibility affects queue logic
        if addon.CCRotation and addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
        
        -- Update visibility (this shows/hides the frame)
        if addon.UI.UpdateVisibility then
            addon.UI:UpdateVisibility()
        end
        
        -- Force display refresh to show the rebuilt queue
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    soloCheck:SetFullWidth(true)
    scroll:AddChild(soloCheck)
    
    -- Show spell names
    local spellNameCheck = AceGUI:Create("CheckBox")
    spellNameCheck:SetLabel("Show spell names")
    spellNameCheck:SetValue(addon.Config:Get("showSpellName"))
    spellNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showSpellName", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameCheck:SetFullWidth(true)
    scroll:AddChild(spellNameCheck)
    
    -- Show player names
    local playerNameCheck = AceGUI:Create("CheckBox")
    playerNameCheck:SetLabel("Show player names")
    playerNameCheck:SetValue(addon.Config:Get("showPlayerName"))
    playerNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showPlayerName", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameCheck:SetFullWidth(true)
    scroll:AddChild(playerNameCheck)
    
    -- Show cooldown text
    local cooldownTextCheck = AceGUI:Create("CheckBox")
    cooldownTextCheck:SetLabel("Show cooldown numbers")
    cooldownTextCheck:SetValue(addon.Config:Get("showCooldownText"))
    cooldownTextCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showCooldownText", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    cooldownTextCheck:SetFullWidth(true)
    scroll:AddChild(cooldownTextCheck)
    
    -- Show tooltips
    local tooltipCheck = AceGUI:Create("CheckBox")
    tooltipCheck:SetLabel("Show tooltips on hover")
    tooltipCheck:SetValue(addon.Config:Get("showTooltips"))
    tooltipCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showTooltips", value)
        -- Update mouse settings to enable/disable click-through
        if addon.UI.UpdateMouseSettings then
            addon.UI:UpdateMouseSettings()
        end
    end)
    tooltipCheck:SetFullWidth(true)
    scroll:AddChild(tooltipCheck)
    
    -- Highlight next spell
    local highlightCheck = AceGUI:Create("CheckBox")
    highlightCheck:SetLabel("Highlight next spell")
    highlightCheck:SetValue(addon.Config:Get("highlightNext"))
    highlightCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("highlightNext", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    highlightCheck:SetFullWidth(true)
    scroll:AddChild(highlightCheck)
    
    -- Cooldown decimal threshold slider
    local decimalThresholdSlider = AceGUI:Create("Slider")
    decimalThresholdSlider:SetLabel("Show decimals below (seconds)")
    decimalThresholdSlider:SetSliderValues(0, 10, 1)
    decimalThresholdSlider:SetValue(addon.Config:Get("cooldownDecimalThreshold"))
    decimalThresholdSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("cooldownDecimalThreshold", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    decimalThresholdSlider:SetFullWidth(true)
    scroll:AddChild(decimalThresholdSlider)
    
    -- Anchor lock checkbox
    local anchorLockCheck = AceGUI:Create("CheckBox")
    anchorLockCheck:SetLabel("Lock frame position (prevents Shift+drag movement)")
    anchorLockCheck:SetValue(addon.Config:Get("anchorLocked"))
    anchorLockCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("anchorLocked", value)
        -- Update mouse settings to enable/disable click-through
        if addon.UI.UpdateMouseSettings then
            addon.UI:UpdateMouseSettings()
        end
    end)
    anchorLockCheck:SetFullWidth(true)
    scroll:AddChild(anchorLockCheck)
    
    -- Debug mode checkbox
    local debugCheck = AceGUI:Create("CheckBox")
    debugCheck:SetLabel("Debug mode (shows detailed debug messages)")
    debugCheck:SetValue(addon.Config:Get("debugMode"))
    debugCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("debugMode", value)
        local state = value and "enabled" or "disabled"
        print("|cff00ff00CC Rotation Helper|r: Debug mode " .. state)
    end)
    debugCheck:SetFullWidth(true)
    scroll:AddChild(debugCheck)
    
    
end

-- Create Text tab content
function addon.UI:CreateTextTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Spell name font size slider
    local spellNameFontSlider = AceGUI:Create("Slider")
    spellNameFontSlider:SetLabel("Spell Name Font Size")
    spellNameFontSlider:SetSliderValues(8, 24, 1)
    spellNameFontSlider:SetValue(addon.Config:Get("spellNameFontSize"))
    spellNameFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("spellNameFontSize", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameFontSlider:SetFullWidth(true)
    scroll:AddChild(spellNameFontSlider)
    
    -- Spell name max length slider
    local spellNameLengthSlider = AceGUI:Create("Slider")
    spellNameLengthSlider:SetLabel("Spell Name Max Length")
    spellNameLengthSlider:SetSliderValues(5, 50, 1)
    spellNameLengthSlider:SetValue(addon.Config:Get("spellNameMaxLength"))
    spellNameLengthSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("spellNameMaxLength", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameLengthSlider:SetFullWidth(true)
    scroll:AddChild(spellNameLengthSlider)
    
    -- Player name font size slider
    local playerNameFontSlider = AceGUI:Create("Slider")
    playerNameFontSlider:SetLabel("Player Name Font Size")
    playerNameFontSlider:SetSliderValues(8, 24, 1)
    playerNameFontSlider:SetValue(addon.Config:Get("playerNameFontSize"))
    playerNameFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("playerNameFontSize", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameFontSlider:SetFullWidth(true)
    scroll:AddChild(playerNameFontSlider)
    
    -- Player name max length slider
    local playerNameLengthSlider = AceGUI:Create("Slider")
    playerNameLengthSlider:SetLabel("Player Name Max Length")
    playerNameLengthSlider:SetSliderValues(3, 30, 1)
    playerNameLengthSlider:SetValue(addon.Config:Get("playerNameMaxLength"))
    playerNameLengthSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("playerNameMaxLength", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameLengthSlider:SetFullWidth(true)
    scroll:AddChild(playerNameLengthSlider)
    
    -- Cooldown font size percentage slider
    local cooldownFontSlider = AceGUI:Create("Slider")
    cooldownFontSlider:SetLabel("Cooldown Font Size (% of icon)")
    cooldownFontSlider:SetSliderValues(10, 50, 1)
    cooldownFontSlider:SetValue(addon.Config:Get("cooldownFontSizePercent") or 25)
    cooldownFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("cooldownFontSizePercent", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    cooldownFontSlider:SetFullWidth(true)
    scroll:AddChild(cooldownFontSlider)
end

-- Create Icons tab content
function addon.UI:CreateIconsTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Icon zoom slider
    local iconZoomSlider = AceGUI:Create("Slider")
    iconZoomSlider:SetLabel("Icon Zoom (Texture scale within frame)")
    iconZoomSlider:SetSliderValues(0.3, 3.0, 0.1)
    iconZoomSlider:SetValue(addon.Config:Get("iconZoom"))
    iconZoomSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("iconZoom", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    iconZoomSlider:SetFullWidth(true)
    scroll:AddChild(iconZoomSlider)
    
    -- Max icons slider
    local maxIconsSlider = AceGUI:Create("Slider")
    maxIconsSlider:SetLabel("Max Icons")
    maxIconsSlider:SetSliderValues(1, 5, 1)
    maxIconsSlider:SetValue(addon.Config:Get("maxIcons"))
    
    -- Individual icon controls
    local iconSizeSliders = {}
    local iconSpellNameChecks = {}
    local iconPlayerNameChecks = {}
    
    for i = 1, 5 do
        -- Icon size slider
        local iconSlider = AceGUI:Create("Slider")
        iconSlider:SetLabel("Icon " .. i .. " Size")
        iconSlider:SetSliderValues(16, 128, 1)
        iconSlider:SetValue(addon.Config:Get("iconSize" .. i))
        iconSlider:SetCallback("OnValueChanged", function(widget, event, value)
            addon.Config:Set("iconSize" .. i, value)
            if addon.UI.RefreshDisplay then
                addon.UI:RefreshDisplay()
            end
        end)
        iconSlider:SetFullWidth(true)
        scroll:AddChild(iconSlider)
        iconSizeSliders[i] = iconSlider
        
        -- Spell name checkbox for this icon
        local spellNameCheck = AceGUI:Create("CheckBox")
        spellNameCheck:SetLabel("Icon " .. i .. " - Show spell name")
        spellNameCheck:SetValue(addon.Config:Get("showSpellName" .. i))
        spellNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
            addon.Config:Set("showSpellName" .. i, value)
            if addon.UI.RefreshDisplay then
                addon.UI:RefreshDisplay()
            end
        end)
        spellNameCheck:SetFullWidth(true)
        scroll:AddChild(spellNameCheck)
        iconSpellNameChecks[i] = spellNameCheck
        
        -- Player name checkbox for this icon
        local playerNameCheck = AceGUI:Create("CheckBox")
        playerNameCheck:SetLabel("Icon " .. i .. " - Show player name")
        playerNameCheck:SetValue(addon.Config:Get("showPlayerName" .. i))
        playerNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
            addon.Config:Set("showPlayerName" .. i, value)
            if addon.UI.RefreshDisplay then
                addon.UI:RefreshDisplay()
            end
        end)
        playerNameCheck:SetFullWidth(true)
        scroll:AddChild(playerNameCheck)
        iconPlayerNameChecks[i] = playerNameCheck
        
        -- Initially hide controls beyond maxIcons
        if i > addon.Config:Get("maxIcons") then
            iconSlider.frame:Hide()
            spellNameCheck.frame:Hide()
            playerNameCheck.frame:Hide()
        end
    end
    
    -- Add callback and widget for max icons slider
    maxIconsSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("maxIcons", value)
        
        -- Show/hide icon controls based on maxIcons
        for i = 1, 5 do
            if iconSizeSliders[i] then
                if i <= value then
                    iconSizeSliders[i].frame:Show()
                    iconSpellNameChecks[i].frame:Show()
                    iconPlayerNameChecks[i].frame:Show()
                else
                    iconSizeSliders[i].frame:Hide()
                    iconSpellNameChecks[i].frame:Hide()
                    iconPlayerNameChecks[i].frame:Hide()
                end
            end
        end
        
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    maxIconsSlider:SetFullWidth(true)
    scroll:AddChild(maxIconsSlider)
end

-- Function to renumber spell priorities to eliminate gaps
function addon.UI:RenumberSpellPriorities()
    -- Get all active spells
    local allSpells = {}
    
    -- Add database spells (if not inactive)
    for spellID, data in pairs(addon.Database.defaultSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "database"
            }
        end
    end
    
    -- Add custom spells (if not inactive, override database if same ID)
    for spellID, data in pairs(addon.Config.db.customSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "custom"
            }
        end
    end
    
    -- Sort spells by current priority
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    table.sort(sortedSpells, function(a, b) return a.data.priority < b.data.priority end)
    
    -- Renumber priorities starting from 1
    for i, spell in ipairs(sortedSpells) do
        local newPriority = i
        
        if spell.data.source == "custom" then
            -- Update custom spell priority
            addon.Config.db.customSpells[spell.spellID].priority = newPriority
        else
            -- Create custom entry to override database spell
            addon.Config.db.customSpells[spell.spellID] = {
                name = spell.data.name,
                ccType = spell.data.ccType,
                priority = newPriority
            }
        end
    end
end

-- Function to move spell priority up or down
function addon.UI:MoveSpellPriority(spellID, spellData, direction, sortedSpells, currentIndex)
    local targetIndex = direction == "up" and currentIndex - 1 or currentIndex + 1
    
    if targetIndex < 1 or targetIndex > #sortedSpells then
        return -- Can't move beyond bounds
    end
    
    local targetSpell = sortedSpells[targetIndex]
    local currentPriority = spellData.priority
    local targetPriority = targetSpell.data.priority
    
    -- Swap priorities
    if spellData.source == "custom" then
        -- Update custom spell priority
        addon.Config.db.customSpells[spellID].priority = targetPriority
    else
        -- Create custom entry to override database spell
        addon.Config.db.customSpells[spellID] = {
            name = spellData.name,
            ccType = spellData.ccType,
            priority = targetPriority
        }
    end
    
    if targetSpell.data.source == "custom" then
        -- Update target custom spell priority
        addon.Config.db.customSpells[targetSpell.spellID].priority = currentPriority
    else
        -- Create custom entry to override target database spell
        addon.Config.db.customSpells[targetSpell.spellID] = {
            name = targetSpell.data.name,
            ccType = targetSpell.data.ccType,
            priority = currentPriority
        }
    end
    
    -- Immediately update tracked cooldowns cache and rebuild queue
    if addon.CCRotation then
        -- Update the tracked cooldowns cache with new priorities
        addon.CCRotation.trackedCooldowns = addon.Config:GetTrackedSpells()
        -- Force immediate synchronous rebuild instead of debounced rebuild
        if addon.CCRotation.DoRebuildQueue then
            addon.CCRotation:DoRebuildQueue()
        elseif addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
    end
end

-- Create Spells tab content
function addon.UI:CreateSpellsTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("Manage which spells are tracked in the rotation.")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)
    
    -- CC Type filter section
    local filterGroup = AceGUI:Create("InlineGroup")
    filterGroup:SetTitle("Queue Filters")
    filterGroup:SetFullWidth(true)
    filterGroup:SetLayout("Flow")
    scroll:AddChild(filterGroup)
    
    -- CC type filter state - using string names that match ccTypeLookup
    local ccTypeFilters = {
        ["stun"] = true,
        ["disorient"] = true,
        ["fear"] = true,
        ["knock"] = true,
        ["incapacitate"] = true
    }
    
    -- CC type filter buttons
    local ccTypeButtons = {}
    local ccTypeOrder = {"stun", "disorient", "fear", "knock", "incapacitate"}
    local ccTypeDisplayNames = {
        ["stun"] = "Stun",
        ["disorient"] = "Disorient", 
        ["fear"] = "Fear",
        ["knock"] = "Knock",
        ["incapacitate"] = "Incapacitate"
    }
    
    -- Queue display section (create queueGroup first)
    local queueGroup = AceGUI:Create("InlineGroup")
    queueGroup:SetTitle("Current Rotation Queue")
    queueGroup:SetFullWidth(true)
    queueGroup:SetLayout("Flow")
    scroll:AddChild(queueGroup)
    
    -- Queue display function (defined before buttons so it's in scope)
    local createQueueDisplay
    createQueueDisplay = function()
        queueGroup:ReleaseChildren()
        
        if not addon.CCRotation then
            local noRotationText = AceGUI:Create("Label")
            noRotationText:SetText("Rotation system not initialized.")
            noRotationText:SetFullWidth(true)
            queueGroup:AddChild(noRotationText)
            return
        end
        
        -- Get the full unfiltered queue by rebuilding it manually
        local fullQueue = {}
        
        if addon.CCRotation and addon.CCRotation.GUIDToUnit then
            -- Use LibOpenRaid to get all cooldowns from all units
            local lib = LibStub("LibOpenRaid-1.0", true)
            if lib then
                local allUnits = lib.GetAllUnitsCooldown()
                if allUnits then
                    for unit, cds in pairs(allUnits) do
                        for spellID, info in pairs(cds) do
                            if addon.CCRotation.trackedCooldowns and addon.CCRotation.trackedCooldowns[spellID] then
                                local spellInfo = addon.CCRotation.trackedCooldowns[spellID]
                                local ccType = spellInfo.type -- This contains string values like "stun", "disorient", etc.
                                                                
                                -- Apply CC type filter
                                if not ccType or ccTypeFilters[ccType] then
                                    local guid = UnitGUID(unit)
                                    if guid then
                                        local _, _, timeLeft, charges, _, _, _, duration = lib.GetCooldownStatusFromCooldownInfo(info)
                                        local currentTime = GetTime()
                                        
                                        table.insert(fullQueue, {
                                            GUID = guid,
                                            unit = unit,
                                            spellID = spellID,
                                            priority = spellInfo.priority,
                                            expirationTime = timeLeft + currentTime,
                                            duration = duration,
                                            charges = charges,
                                            ccType = ccType
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if #fullQueue == 0 then
            local emptyText = AceGUI:Create("Label")
            emptyText:SetText("No abilities found. Join a group to see available cooldowns.")
            emptyText:SetFullWidth(true)
            queueGroup:AddChild(emptyText)
            return
        end
        
        -- Sort the full queue using the same logic as the rotation system
        table.sort(fullQueue, function(a, b)
            local nameA, nameB = UnitName(a.unit), UnitName(b.unit)
            local isPriorityA = addon.Config:IsPriorityPlayer(nameA)
            local isPriorityB = addon.Config:IsPriorityPlayer(nameB)
            
            local now = GetTime()
            local readyA = a.charges > 0 or a.expirationTime <= now
            local readyB = b.charges > 0 or b.expirationTime <= now
            
            -- 1. Ready spells first
            if readyA ~= readyB then return readyA end
            
            -- 2. Among ready spells, prioritize priority players
            if readyA and readyB and (isPriorityA ~= isPriorityB) then
                return isPriorityA
            end
            
            -- 3. Finally, fallback on configured priority (or soonest available cooldown)
            if readyA then
                return a.priority < b.priority
            else
                return a.expirationTime < b.expirationTime
            end
        end)
        
        -- Create a horizontal container for the spell icons
        local iconRow = AceGUI:Create("SimpleGroup")
        iconRow:SetFullWidth(true)
        iconRow:SetLayout("Flow")
        queueGroup:AddChild(iconRow)
        
        -- Display spell icons in a row
        for i, entry in ipairs(fullQueue) do
            local spellIcon = AceGUI:Create("Icon")
            spellIcon:SetWidth(32)
            spellIcon:SetHeight(32)
            spellIcon:SetImageSize(32, 32)
            
            -- Get spell icon from WoW API
            local spellInfo = C_Spell.GetSpellInfo(entry.spellID)
            if spellInfo and spellInfo.iconID then
                spellIcon:SetImage(spellInfo.iconID)
            else
                -- Fallback icon if spell not found
                spellIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            
            iconRow:AddChild(spellIcon)
        end
    end
    
    for _, ccType in ipairs(ccTypeOrder) do
        local filterButton = AceGUI:Create("Button")
        local displayName = ccTypeDisplayNames[ccType]
        filterButton:SetText(displayName)
        filterButton:SetWidth(100)
        
        -- Store the ccType and displayName on the button widget for the callback
        filterButton.ccType = ccType
        filterButton.displayName = displayName
        
        filterButton:SetCallback("OnClick", function(widget, event)
            local buttonCcType = widget.ccType
            local buttonDisplayName = widget.displayName
            
            ccTypeFilters[buttonCcType] = not ccTypeFilters[buttonCcType]
            -- Update button appearance
            if ccTypeFilters[buttonCcType] then
                widget:SetText(buttonDisplayName)
            else
                widget:SetText("|cff888888" .. buttonDisplayName .. "|r")
            end
            -- Rebuild the actual rotation queue first
            if addon.CCRotation and addon.CCRotation.RebuildQueue then
                addon.CCRotation:RebuildQueue()
            end
            -- Then refresh queue display
            createQueueDisplay()
        end)
        ccTypeButtons[ccType] = filterButton
        filterGroup:AddChild(filterButton)
    end
    
    -- Initial queue display
    createQueueDisplay()
    
    -- Current tracked spells display
    local spellListGroup = AceGUI:Create("InlineGroup")
    spellListGroup:SetTitle("Currently Tracked Spells")
    spellListGroup:SetFullWidth(true)
    spellListGroup:SetLayout("Flow")
    scroll:AddChild(spellListGroup)
    
    -- Build the spell list
    self:RebuildSpellList(spellListGroup, createQueueDisplay)
    
    -- Add the management sections (add/inactive spells)
    self:CreateSpellManagementSections(scroll)
end

-- Rebuild spell list content (extracted for partial updates)
function addon.UI:RebuildSpellList(spellListGroup, queueDisplayRefreshFn)
    -- Get all active spells (from database + custom, excluding inactive)
    local allSpells = {}
    
    -- Add database spells (if not inactive)
    for spellID, data in pairs(addon.Database.defaultSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "database"
            }
        end
    end
    
    -- Add custom spells (if not inactive, override database if same ID)
    for spellID, data in pairs(addon.Config.db.customSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "custom"
            }
        end
    end
    
    -- Sort spells by priority
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    table.sort(sortedSpells, function(a, b) return a.data.priority < b.data.priority end)
    
    -- Create header row
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")
    spellListGroup:AddChild(headerGroup)
    
    -- Header spacer for buttons
    local headerSpacer = AceGUI:Create("Label")
    headerSpacer:SetText("Actions")
    headerSpacer:SetWidth(140)
    headerGroup:AddChild(headerSpacer)
    
    -- Icon header
    local iconHeader = AceGUI:Create("Label")
    iconHeader:SetText("Icon")
    iconHeader:SetWidth(40)
    headerGroup:AddChild(iconHeader)
    
    -- Spell name header
    local nameHeader = AceGUI:Create("Label")
    nameHeader:SetText("Spell Name")
    nameHeader:SetWidth(150)
    headerGroup:AddChild(nameHeader)
    
    -- Spell ID header
    local idHeader = AceGUI:Create("Label")
    idHeader:SetText("Spell ID")
    idHeader:SetWidth(80)
    headerGroup:AddChild(idHeader)
    
    -- CC Type header
    local typeHeader = AceGUI:Create("Label")
    typeHeader:SetText("CC Type")
    typeHeader:SetWidth(120)
    headerGroup:AddChild(typeHeader)
    
    -- Action header
    local actionHeader = AceGUI:Create("Label")
    actionHeader:SetText("Action")
    actionHeader:SetWidth(80)
    headerGroup:AddChild(actionHeader)
    
    -- Display spells as tabular rows
    for i, spell in ipairs(sortedSpells) do
        local rowGroup = AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("Flow")
        spellListGroup:AddChild(rowGroup)
        
        -- Move up button (disabled for first item)
        local upButton = AceGUI:Create("Button")
        upButton:SetText("Up")
        upButton:SetWidth(60)
        if i == 1 then
            upButton:SetDisabled(true)
        else
            upButton:SetCallback("OnClick", function()
                -- Update priorities and rotation queue
                self:MoveSpellPriority(spell.spellID, spell.data, "up", sortedSpells, i)
                
                -- Rebuild just the spell list group, not the entire tab
                spellListGroup:ReleaseChildren()
                self:RebuildSpellList(spellListGroup, queueDisplayRefreshFn)
                
                -- Also refresh the queue display preview
                if queueDisplayRefreshFn then
                    queueDisplayRefreshFn()
                end
            end)
        end
        rowGroup:AddChild(upButton)
        
        -- Move down button (disabled for last item)
        local downButton = AceGUI:Create("Button")
        downButton:SetText("Down")
        downButton:SetWidth(70)
        if i == #sortedSpells then
            downButton:SetDisabled(true)
        else
            downButton:SetCallback("OnClick", function()
                -- Update priorities and rotation queue
                self:MoveSpellPriority(spell.spellID, spell.data, "down", sortedSpells, i)
                
                -- Rebuild just the spell list group, not the entire tab
                spellListGroup:ReleaseChildren()
                self:RebuildSpellList(spellListGroup, queueDisplayRefreshFn)
                
                -- Also refresh the queue display preview
                if queueDisplayRefreshFn then
                    queueDisplayRefreshFn()
                end
            end)
        end
        rowGroup:AddChild(downButton)
        
        -- Spell icon
        local spellIcon = AceGUI:Create("Icon")
        spellIcon:SetWidth(32)
        spellIcon:SetHeight(32)
        spellIcon:SetImageSize(32, 32)
        
        -- Get spell icon from WoW API
        local spellInfo = C_Spell.GetSpellInfo(spell.spellID)
        if spellInfo and spellInfo.iconID then
            spellIcon:SetImage(spellInfo.iconID)
        else
            -- Fallback icon if spell not found
            spellIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        rowGroup:AddChild(spellIcon)
        
        -- Editable spell name
        local spellNameEdit = AceGUI:Create("EditBox")
        spellNameEdit:SetText(spell.data.name)
        spellNameEdit:SetWidth(150)
        spellNameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
            local newName = text:trim()
            if newName ~= "" then
                -- Update the spell name
                if spell.data.source == "custom" then
                    addon.Config.db.customSpells[spell.spellID].name = newName
                else
                    -- Create custom entry to override database spell
                    addon.Config.db.customSpells[spell.spellID] = {
                        name = newName,
                        ccType = spell.data.ccType,
                        priority = spell.data.priority
                    }
                end
                
                -- Rebuild rotation queue
                if addon.CCRotation and addon.CCRotation.RebuildQueue then
                    addon.CCRotation:RebuildQueue()
                end
            end
        end)
        rowGroup:AddChild(spellNameEdit)
        
        -- Editable spell ID
        local spellIDEdit = AceGUI:Create("EditBox")
        spellIDEdit:SetText(tostring(spell.spellID))
        spellIDEdit:SetWidth(80)
        spellIDEdit:SetCallback("OnEnterPressed", function(widget, event, text)
            local newSpellID = tonumber(text)
            if newSpellID and newSpellID ~= spell.spellID then
                -- Remove old spell entry
                if spell.data.source == "custom" then
                    addon.Config.db.customSpells[spell.spellID] = nil
                else
                    -- Mark old database spell as inactive
                    addon.Config.db.inactiveSpells[spell.spellID] = {
                        name = spell.data.name,
                        ccType = spell.data.ccType,
                        priority = spell.data.priority,
                        source = spell.data.source
                    }
                end
                
                -- Add new spell entry
                addon.Config.db.customSpells[newSpellID] = {
                    name = spell.data.name,
                    ccType = spell.data.ccType,
                    priority = spell.data.priority
                }
                
                -- Refresh tab
                container:ReleaseChildren()
                self:CreateSpellsTab(container)
                
                -- Rebuild rotation queue
                if addon.CCRotation and addon.CCRotation.RebuildQueue then
                    addon.CCRotation:RebuildQueue()
                end
            end
        end)
        rowGroup:AddChild(spellIDEdit)
        
        -- Editable CC type dropdown
        local ccTypeDropdown = AceGUI:Create("Dropdown")
        ccTypeDropdown:SetWidth(120)
        local ccTypeList = {}
        local ccTypeDisplayList = {}
        for _, ccType in ipairs(addon.Database.ccTypeOrder) do
            ccTypeList[ccType] = addon.Database.ccTypeDisplayNames[ccType]
            ccTypeDisplayList[ccType] = addon.Database.ccTypeDisplayNames[ccType]
        end
        ccTypeDropdown:SetList(ccTypeList)
        ccTypeDropdown:SetValue(addon.Config:NormalizeCCType(spell.data.ccType))
        ccTypeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
            -- Update the CC type
            if spell.data.source == "custom" then
                addon.Config.db.customSpells[spell.spellID].ccType = value
            else
                -- Create custom entry to override database spell
                addon.Config.db.customSpells[spell.spellID] = {
                    name = spell.data.name,
                    ccType = value,
                    priority = spell.data.priority
                }
            end
            
            -- Rebuild rotation queue
            if addon.CCRotation and addon.CCRotation.RebuildQueue then
                addon.CCRotation:RebuildQueue()
            end
        end)
        rowGroup:AddChild(ccTypeDropdown)
        
        -- Disable button (for all spells)
        local disableButton = AceGUI:Create("Button")
        disableButton:SetText("Disable")
        disableButton:SetWidth(80)
        disableButton:SetCallback("OnClick", function()
            -- Move spell to inactive list
            addon.Config.db.inactiveSpells[spell.spellID] = {
                name = spell.data.name,
                ccType = spell.data.ccType,
                priority = spell.data.priority,
                source = spell.data.source
            }
            
            -- Renumber remaining active spells to eliminate gaps
            self:RenumberSpellPriorities()
            
            -- Update tracked cooldowns immediately
            if addon.CCRotation then
                addon.CCRotation.trackedCooldowns = addon.Config:GetTrackedSpells()
                -- Force immediate queue rebuild
                addon.CCRotation:DoRebuildQueue()
            end
            
            -- Rebuild just the spell list, not the entire tab
            spellListGroup:ReleaseChildren()
            self:RebuildSpellList(spellListGroup, queueDisplayRefreshFn)
            
            -- Also refresh the queue display preview
            if queueDisplayRefreshFn then
                queueDisplayRefreshFn()
            end
        end)
        rowGroup:AddChild(disableButton)
    end
end

-- Continue with CreateSpellsTab - add management sections
function addon.UI:CreateSpellManagementSections(scroll)
    -- Add new spell section
    local addSpellGroup = AceGUI:Create("InlineGroup")
    addSpellGroup:SetTitle("Add Custom Spell")
    addSpellGroup:SetFullWidth(true)
    addSpellGroup:SetLayout("Flow")
    scroll:AddChild(addSpellGroup)
    
    -- Spell ID input
    local spellIDEdit = AceGUI:Create("EditBox")
    spellIDEdit:SetLabel("Spell ID")
    spellIDEdit:SetWidth(150)
    addSpellGroup:AddChild(spellIDEdit)
    
    -- Spell name input
    local spellNameEdit = AceGUI:Create("EditBox")
    spellNameEdit:SetLabel("Spell Name")
    spellNameEdit:SetWidth(200)
    addSpellGroup:AddChild(spellNameEdit)
    
    -- CC Type dropdown
    local ccTypeDropdown = AceGUI:Create("Dropdown")
    ccTypeDropdown:SetLabel("CC Type")
    ccTypeDropdown:SetWidth(150)
    local ccTypeList = {}
    for _, ccType in ipairs(addon.Database.ccTypeOrder) do
        ccTypeList[ccType] = addon.Database.ccTypeDisplayNames[ccType]
    end
    ccTypeDropdown:SetList(ccTypeList)
    ccTypeDropdown:SetValue("stun")
    addSpellGroup:AddChild(ccTypeDropdown)
    
    -- Priority input
    local priorityEdit = AceGUI:Create("EditBox")
    priorityEdit:SetLabel("Priority (1-50)")
    priorityEdit:SetWidth(100)
    priorityEdit:SetText("25")
    addSpellGroup:AddChild(priorityEdit)
    
    -- Add button
    local addButton = AceGUI:Create("Button")
    addButton:SetText("Add Spell")
    addButton:SetWidth(100)
    addButton:SetCallback("OnClick", function()
        local spellID = tonumber(spellIDEdit:GetText())
        local spellName = spellNameEdit:GetText():trim()
        local ccType = ccTypeDropdown:GetValue()
        local priority = tonumber(priorityEdit:GetText()) or 25
        
        if spellID and spellName ~= "" and ccType and priority then
            -- Add to custom spells
            addon.Config.db.customSpells[spellID] = {
                name = spellName,
                ccType = ccType,
                priority = priority
            }
            
            -- Clear inputs
            spellIDEdit:SetText("")
            spellNameEdit:SetText("")
            priorityEdit:SetText("25")
            
            -- Refresh the tab
            container:ReleaseChildren()
            self:CreateSpellsTab(container)
            
            -- Rebuild rotation queue
            if addon.CCRotation and addon.CCRotation.RebuildQueue then
                addon.CCRotation:RebuildQueue()
            end
        end
    end)
    addSpellGroup:AddChild(addButton)
    
    -- Inactive spells section
    local inactiveSpellsGroup = AceGUI:Create("InlineGroup")
    inactiveSpellsGroup:SetTitle("Disabled Spells")
    inactiveSpellsGroup:SetFullWidth(true)
    inactiveSpellsGroup:SetLayout("Flow")
    scroll:AddChild(inactiveSpellsGroup)
    
    -- Check if there are any inactive spells
    local hasInactiveSpells = false
    for _ in pairs(addon.Config.db.inactiveSpells) do
        hasInactiveSpells = true
        break
    end
    
    if hasInactiveSpells then
        -- Display inactive spells
        for spellID, spellData in pairs(addon.Config.db.inactiveSpells) do
            local inactiveRowGroup = AceGUI:Create("SimpleGroup")
            inactiveRowGroup:SetFullWidth(true)
            inactiveRowGroup:SetLayout("Flow")
            inactiveSpellsGroup:AddChild(inactiveRowGroup)
            
            -- Enable button
            local enableButton = AceGUI:Create("Button")
            enableButton:SetText("Enable")
            enableButton:SetWidth(80)
            enableButton:SetCallback("OnClick", function()
                -- Remove from inactive list
                addon.Config.db.inactiveSpells[spellID] = nil
                
                -- Renumber all active spells (including the newly enabled one)
                self:RenumberSpellPriorities()
                
                -- Update tracked cooldowns immediately
                if addon.CCRotation then
                    addon.CCRotation.trackedCooldowns = addon.Config:GetTrackedSpells()
                    -- Force immediate queue rebuild
                    addon.CCRotation:DoRebuildQueue()
                end
                
                container:ReleaseChildren()
                self:CreateSpellsTab(container)
            end)
            inactiveRowGroup:AddChild(enableButton)
            
            -- Spell icon
            local inactiveIcon = AceGUI:Create("Icon")
            inactiveIcon:SetWidth(32)
            inactiveIcon:SetHeight(32)
            inactiveIcon:SetImageSize(32, 32)
            
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            if spellInfo and spellInfo.iconID then
                inactiveIcon:SetImage(spellInfo.iconID)
            else
                inactiveIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            inactiveRowGroup:AddChild(inactiveIcon)
            
            -- Spell info (grayed out)
            local inactiveSpellLine = AceGUI:Create("Label")
            local ccTypeName = addon.Config:NormalizeCCType(spellData.ccType) or "unknown"
            local ccTypeDisplay = addon.Database.ccTypeDisplayNames[ccTypeName] or ccTypeName
            inactiveSpellLine:SetText(string.format("|cff888888%s (ID: %d, Type: %s)|r", 
                spellData.name, spellID, ccTypeDisplay))
            inactiveSpellLine:SetWidth(350)
            inactiveRowGroup:AddChild(inactiveSpellLine)
            
            -- Delete button (permanent removal)
            if spellData.source == "custom" then
                local deleteButton = AceGUI:Create("Button")
                deleteButton:SetText("Delete")
                deleteButton:SetWidth(80)
                deleteButton:SetCallback("OnClick", function()
                    -- Permanently remove custom spell
                    addon.Config.db.inactiveSpells[spellID] = nil
                    addon.Config.db.customSpells[spellID] = nil
                    
                    container:ReleaseChildren()
                    self:CreateSpellsTab(container)
                    if addon.CCRotation and addon.CCRotation.RebuildQueue then
                        addon.CCRotation:RebuildQueue()
                    end
                end)
                inactiveRowGroup:AddChild(deleteButton)
            end
        end
    else
        local noInactiveText = AceGUI:Create("Label")
        noInactiveText:SetText("No disabled spells.")
        noInactiveText:SetFullWidth(true)
        inactiveSpellsGroup:AddChild(noInactiveText)
    end
    
    -- Help text for spell management
    local manageHelpText = AceGUI:Create("Label")
    manageHelpText:SetText("Use Up/Down buttons to reorder spells. Use Disable button to temporarily remove spells from rotation. Use Enable button to restore disabled spells.")
    manageHelpText:SetFullWidth(true)
    scroll:AddChild(manageHelpText)
end

-- Create Npcs tab content
function addon.UI:CreateNpcsTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("Manage NPC crowd control effectiveness. Configure which types of CC work on each NPC.")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)
    
    -- Current dungeon status and filter
    local currentDungeonGroup = AceGUI:Create("InlineGroup")
    currentDungeonGroup:SetTitle("Current Location")
    currentDungeonGroup:SetFullWidth(true)
    currentDungeonGroup:SetLayout("Flow")
    scroll:AddChild(currentDungeonGroup)
    
    -- Get current dungeon info
    local currentAbbrev, currentDungeonName, instanceType = addon.Database:GetCurrentDungeonInfo()
    
    -- Current dungeon status label
    local dungeonStatusLabel = AceGUI:Create("Label")
    dungeonStatusLabel:SetWidth(400)
    if currentDungeonName then
        if currentAbbrev then
            dungeonStatusLabel:SetText("|cff00ff00Currently in: " .. currentDungeonName .. " (" .. instanceType .. ")|r")
        else
            dungeonStatusLabel:SetText("|cffff8800Currently in: " .. currentDungeonName .. " (" .. instanceType .. ") - Unknown dungeon|r")
        end
    else
        if instanceType == "none" then
            dungeonStatusLabel:SetText("|cffccccccNot currently in a dungeon.|r")
        else
            dungeonStatusLabel:SetText("|cffccccccCurrently in: " .. (instanceType or "unknown") .. " - Not a supported instance type.|r")
        end
    end
    currentDungeonGroup:AddChild(dungeonStatusLabel)
    
    -- Current dungeon filter toggle (only show if in a known dungeon)
    local filterCurrentButton = nil
    if currentAbbrev and currentDungeonName then
        filterCurrentButton = AceGUI:Create("Button")
        filterCurrentButton:SetText("Show Only Current Dungeon")
        filterCurrentButton:SetWidth(180)
        currentDungeonGroup:AddChild(filterCurrentButton)
        
        -- Refresh button to update dungeon status
        local refreshButton = AceGUI:Create("Button")
        refreshButton:SetText("Refresh Location")
        refreshButton:SetWidth(120)
        refreshButton:SetCallback("OnClick", function()
            -- Refresh the entire tab to update dungeon status
            container:ReleaseChildren()
            self:CreateNpcsTab(container)
        end)
        currentDungeonGroup:AddChild(refreshButton)
    end
    
    -- State for collapsed dungeons and filters (using closure to persist between refreshes)
    if not self.collapsedDungeons then
        self.collapsedDungeons = {}
    end
    if not self.showOnlyCurrentDungeon then
        self.showOnlyCurrentDungeon = false
    end
    
    -- Add filter button callback if in known dungeon
    if filterCurrentButton then
        filterCurrentButton:SetText(self.showOnlyCurrentDungeon and "Show All Dungeons" or "Show Only Current Dungeon")
        filterCurrentButton:SetCallback("OnClick", function()
            self.showOnlyCurrentDungeon = not self.showOnlyCurrentDungeon
            -- Refresh tab to apply filter
            container:ReleaseChildren()
            self:CreateNpcsTab(container)
        end)
    end
    
    -- Get all NPCs (from database + custom) and group by dungeon
    local dungeonGroups = {}
    
    -- Apply current dungeon filter if enabled
    local filterToDungeon = (self.showOnlyCurrentDungeon and currentDungeonName) and currentDungeonName or nil
    
    -- Process database NPCs
    for npcID, data in pairs(addon.Database.defaultNPCs) do
        local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(data.name)
        
        -- Apply filter if active
        if not filterToDungeon or dungeonName == filterToDungeon then
            if not dungeonGroups[dungeonName] then
                dungeonGroups[dungeonName] = {
                    abbreviation = abbrev,
                    npcs = {}
                }
            end
            
            dungeonGroups[dungeonName].npcs[npcID] = {
                name = data.name,
                mobName = mobName,
                cc = data.cc,
                source = "database"
            }
        end
    end
    
    -- Override with custom NPCs
    for npcID, data in pairs(addon.Config.db.customNPCs) do
        local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(data.name)
        -- Also check explicit dungeon field for custom NPCs
        local actualDungeon = data.dungeon or dungeonName
        
        -- Apply filter if active
        if not filterToDungeon or actualDungeon == filterToDungeon or dungeonName == filterToDungeon then
            local groupName = actualDungeon or dungeonName
            if not dungeonGroups[groupName] then
                dungeonGroups[groupName] = {
                    abbreviation = abbrev,
                    npcs = {}
                }
            end
            
            dungeonGroups[groupName].npcs[npcID] = {
                name = data.name,
                mobName = mobName,
                cc = data.cc,
                source = "custom",
                dungeon = data.dungeon -- Custom NPCs might have explicit dungeon field
            }
        end
    end
    
    -- Sort dungeons by name
    local sortedDungeons = {}
    for dungeonName, dungeonData in pairs(dungeonGroups) do
        table.insert(sortedDungeons, {name = dungeonName, data = dungeonData})
    end
    table.sort(sortedDungeons, function(a, b) return a.name < b.name end)
    
    -- CC Types for headers
    local ccTypes = {"Stun", "Disorient", "Fear", "Knock", "Incap"}
    
    -- Display dungeons with collapsible groups
    for _, dungeon in ipairs(sortedDungeons) do
        local dungeonName = dungeon.name
        local dungeonData = dungeon.data
        
        -- Create dungeon group
        local dungeonGroup = AceGUI:Create("InlineGroup")
        -- Count NPCs in this dungeon
        local npcCount = 0
        for _ in pairs(dungeonData.npcs) do
            npcCount = npcCount + 1
        end
        dungeonGroup:SetTitle(dungeonName .. " (" .. npcCount .. " NPCs)")
        dungeonGroup:SetFullWidth(true)
        dungeonGroup:SetLayout("Flow")
        scroll:AddChild(dungeonGroup)
        
        -- Collapse/Expand button
        local toggleButton = AceGUI:Create("Button")
        local isCollapsed = self.collapsedDungeons[dungeonName]
        toggleButton:SetText(isCollapsed and "Expand" or "Collapse")
        toggleButton:SetWidth(100)
        toggleButton:SetCallback("OnClick", function()
            self.collapsedDungeons[dungeonName] = not self.collapsedDungeons[dungeonName]
            -- Refresh tab to show/hide content
            container:ReleaseChildren()
            self:CreateNpcsTab(container)
        end)
        dungeonGroup:AddChild(toggleButton)
        
        -- Only show content if not collapsed
        if not isCollapsed then
            -- Create header for this dungeon
            local headerGroup = AceGUI:Create("SimpleGroup")
            headerGroup:SetFullWidth(true)
            headerGroup:SetLayout("Flow")
            dungeonGroup:AddChild(headerGroup)
            
            -- Headers
            local nameHeader = AceGUI:Create("Label")
            nameHeader:SetText("NPC Name")
            nameHeader:SetWidth(180)
            headerGroup:AddChild(nameHeader)
            
            local idHeader = AceGUI:Create("Label")
            idHeader:SetText("ID")
            idHeader:SetWidth(60)
            headerGroup:AddChild(idHeader)
            
            local dungeonHeader = AceGUI:Create("Label")
            dungeonHeader:SetText("Dungeon")
            dungeonHeader:SetWidth(100)
            headerGroup:AddChild(dungeonHeader)
            
            for i, ccType in ipairs(ccTypes) do
                local ccHeader = AceGUI:Create("Label")
                ccHeader:SetText(ccType)
                ccHeader:SetWidth(60)
                headerGroup:AddChild(ccHeader)
            end
            
            local actionHeader = AceGUI:Create("Label")
            actionHeader:SetText("Action")
            actionHeader:SetWidth(80)
            headerGroup:AddChild(actionHeader)
            
            -- Sort NPCs within dungeon by mob name
            local sortedNPCs = {}
            for npcID, npcData in pairs(dungeonData.npcs) do
                table.insert(sortedNPCs, {npcID = npcID, data = npcData})
            end
            table.sort(sortedNPCs, function(a, b) return (a.data.mobName or a.data.name) < (b.data.mobName or b.data.name) end)
            
            -- Display NPCs
            for _, npc in ipairs(sortedNPCs) do
                local npcID = npc.npcID
                local npcData = npc.data
                
                local rowGroup = AceGUI:Create("SimpleGroup")
                rowGroup:SetFullWidth(true)
                rowGroup:SetLayout("Flow")
                dungeonGroup:AddChild(rowGroup)
                
                -- Editable mob name (without dungeon prefix)
                local mobNameEdit = AceGUI:Create("EditBox")
                mobNameEdit:SetText(npcData.mobName or npcData.name)
                mobNameEdit:SetWidth(180)
                mobNameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
                    local newMobName = text:trim()
                    if newMobName ~= "" then
                        local newFullName
                        if dungeonData.abbreviation then
                            newFullName = dungeonData.abbreviation .. " - " .. newMobName
                        else
                            newFullName = newMobName
                        end
                        
                        -- Update the NPC name
                        if npcData.source == "custom" then
                            addon.Config.db.customNPCs[npcID].name = newFullName
                        else
                            -- Create custom entry to override database NPC
                            addon.Config.db.customNPCs[npcID] = {
                                name = newFullName,
                                cc = npcData.cc,
                                dungeon = dungeonName
                            }
                        end
                    end
                end)
                rowGroup:AddChild(mobNameEdit)
                
                -- NPC ID (read-only display)
                local npcIDLabel = AceGUI:Create("Label")
                npcIDLabel:SetText(tostring(npcID))
                npcIDLabel:SetWidth(60)
                rowGroup:AddChild(npcIDLabel)
                
                -- Dungeon dropdown (editable for custom NPCs)
                local dungeonDropdown = AceGUI:Create("Dropdown")
                dungeonDropdown:SetWidth(100)
                
                -- Build dungeon list for dropdown
                local dungeonList = {["Other"] = "Other"}
                for abbrev, fullName in pairs(addon.Database.dungeonNames) do
                    dungeonList[fullName] = fullName
                end
                dungeonDropdown:SetList(dungeonList)
                dungeonDropdown:SetValue(dungeonName)
                
                if npcData.source == "custom" then
                    dungeonDropdown:SetCallback("OnValueChanged", function(widget, event, value)
                        -- Update dungeon for custom NPC
                        local oldName = npcData.mobName or npcData.name
                        local newAbbrev = nil
                        for abbrev, fullName in pairs(addon.Database.dungeonNames) do
                            if fullName == value then
                                newAbbrev = abbrev
                                break
                            end
                        end
                        
                        local newFullName
                        if newAbbrev then
                            newFullName = newAbbrev .. " - " .. oldName
                        else
                            newFullName = oldName
                        end
                        
                        addon.Config.db.customNPCs[npcID].name = newFullName
                        addon.Config.db.customNPCs[npcID].dungeon = value
                        
                        -- Refresh tab to regroup
                        container:ReleaseChildren()
                        self:CreateNpcsTab(container)
                    end)
                else
                    dungeonDropdown:SetDisabled(true)
                end
                rowGroup:AddChild(dungeonDropdown)
                
                -- CC effectiveness checkboxes
                for i = 1, 5 do
                    local ccCheck = AceGUI:Create("CheckBox")
                    ccCheck:SetWidth(60)
                    ccCheck:SetValue(npcData.cc[i])
                    ccCheck:SetCallback("OnValueChanged", function(widget, event, value)
                        -- Update the CC effectiveness
                        local newCC = {}
                        for j = 1, 5 do
                            if j == i then
                                newCC[j] = value
                            else
                                newCC[j] = npcData.cc[j]
                            end
                        end
                        
                        if npcData.source == "custom" then
                            addon.Config.db.customNPCs[npcID].cc = newCC
                        else
                            -- Create custom entry to override database NPC
                            addon.Config.db.customNPCs[npcID] = {
                                name = npcData.name,
                                cc = newCC,
                                dungeon = dungeonName
                            }
                        end
                        
                        -- Update local data for other checkboxes
                        npcData.cc = newCC
                    end)
                    rowGroup:AddChild(ccCheck)
                end
                
                -- Reset/Delete button
                if npcData.source == "custom" and addon.Database.defaultNPCs[npcID] then
                    local resetButton = AceGUI:Create("Button")
                    resetButton:SetText("Reset")
                    resetButton:SetWidth(80)
                    resetButton:SetCallback("OnClick", function()
                        -- Remove custom entry to revert to database
                        addon.Config.db.customNPCs[npcID] = nil
                        
                        -- Refresh tab
                        container:ReleaseChildren()
                        self:CreateNpcsTab(container)
                    end)
                    rowGroup:AddChild(resetButton)
                elseif npcData.source == "custom" then
                    -- Delete button for custom-only NPCs
                    local deleteButton = AceGUI:Create("Button")
                    deleteButton:SetText("Delete")
                    deleteButton:SetWidth(80)
                    deleteButton:SetCallback("OnClick", function()
                        -- Remove custom NPC entirely
                        addon.Config.db.customNPCs[npcID] = nil
                        
                        -- Refresh tab
                        container:ReleaseChildren()
                        self:CreateNpcsTab(container)
                    end)
                    rowGroup:AddChild(deleteButton)
                end
            end
        end
    end
    
    -- Quick NPC Lookup section
    local lookupGroup = AceGUI:Create("InlineGroup")
    lookupGroup:SetTitle("Quick NPC Lookup")
    lookupGroup:SetFullWidth(true)
    lookupGroup:SetLayout("Flow")
    scroll:AddChild(lookupGroup)
    
    -- Lookup from target for existing NPCs
    local lookupTargetButton = AceGUI:Create("Button")
    lookupTargetButton:SetText("Find Target in List")
    lookupTargetButton:SetWidth(130)
    lookupGroup:AddChild(lookupTargetButton)
    
    -- Search existing NPCs
    local lookupSearchEdit = AceGUI:Create("EditBox")
    lookupSearchEdit:SetLabel("Search NPCs")
    lookupSearchEdit:SetWidth(200)
    lookupGroup:AddChild(lookupSearchEdit)
    
    -- Search existing button
    local lookupSearchButton = AceGUI:Create("Button")
    lookupSearchButton:SetText("Find")
    lookupSearchButton:SetWidth(60)
    lookupGroup:AddChild(lookupSearchButton)
    
    -- Lookup status
    local lookupStatusLabel = AceGUI:Create("Label")
    lookupStatusLabel:SetText("")
    lookupStatusLabel:SetWidth(400)
    lookupGroup:AddChild(lookupStatusLabel)
    
    -- Lookup callbacks
    lookupTargetButton:SetCallback("OnClick", function()
        local targetInfo = addon.Database:GetTargetNPCInfo()
        if not targetInfo then
            lookupStatusLabel:SetText("|cffff0000No valid NPC target found.|r")
            return
        end
        
        -- Check if target exists in our configuration
        local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(targetInfo.name)
        if targetInfo.exists then
            lookupStatusLabel:SetText("|cff00ff00Found: " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ") in " .. (dungeonName or "Other") .. " dungeon section above.|r")
            
            -- Auto-expand the dungeon if it's collapsed
            if dungeonName and self.collapsedDungeons[dungeonName] then
                self.collapsedDungeons[dungeonName] = false
                -- Refresh to show the expanded section
                container:ReleaseChildren()
                self:CreateNpcsTab(container)
            end
        else
            lookupStatusLabel:SetText("|cffff8800Target " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ") not found in configuration. You can add it below.|r")
        end
    end)
    
    lookupSearchButton:SetCallback("OnClick", function()
        local searchTerm = lookupSearchEdit:GetText():trim()
        if searchTerm == "" then
            lookupStatusLabel:SetText("|cffff0000Enter a name to search.|r")
            return
        end
        
        local results = addon.Database:SearchNPCsByName(searchTerm)
        if #results == 0 then
            lookupStatusLabel:SetText("|cffff8800No NPCs found matching '" .. searchTerm .. "'.|r")
        else
            local resultText = "Found " .. #results .. " NPCs: "
            local dungeonsToExpand = {}
            
            for i = 1, math.min(3, #results) do
                if i > 1 then resultText = resultText .. ", " end
                local result = results[i]
                local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(result.name)
                resultText = resultText .. (mobName or result.name) .. " (" .. result.id .. ")"
                
                if dungeonName then
                    dungeonsToExpand[dungeonName] = true
                end
            end
            
            if #results > 3 then
                resultText = resultText .. "..."
            end
            
            lookupStatusLabel:SetText("|cff00ff00" .. resultText .. "|r")
            
            -- Auto-expand relevant dungeons
            local needsRefresh = false
            for dungeonName in pairs(dungeonsToExpand) do
                if self.collapsedDungeons[dungeonName] then
                    self.collapsedDungeons[dungeonName] = false
                    needsRefresh = true
                end
            end
            
            if needsRefresh then
                container:ReleaseChildren()
                self:CreateNpcsTab(container)
            end
        end
    end)
    
    -- Enter key support for search
    lookupSearchEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        lookupSearchButton.frame:Click()
    end)
    
    -- Add new NPC section
    local addNPCGroup = AceGUI:Create("InlineGroup")
    addNPCGroup:SetTitle("Add Custom NPC")
    addNPCGroup:SetFullWidth(true)
    addNPCGroup:SetLayout("Flow")
    scroll:AddChild(addNPCGroup)
    
    -- Lookup from target button
    local targetButton = AceGUI:Create("Button")
    targetButton:SetText("Get from Target")
    targetButton:SetWidth(120)
    addNPCGroup:AddChild(targetButton)
    
    -- Status label for feedback
    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetText("")
    statusLabel:SetWidth(250)
    addNPCGroup:AddChild(statusLabel)
    
    -- NPC ID input
    local npcIDEdit = AceGUI:Create("EditBox")
    npcIDEdit:SetLabel("NPC ID")
    npcIDEdit:SetWidth(100)
    addNPCGroup:AddChild(npcIDEdit)
    
    -- NPC name input
    local npcNameEdit = AceGUI:Create("EditBox")
    npcNameEdit:SetLabel("NPC Name")
    npcNameEdit:SetWidth(200)
    addNPCGroup:AddChild(npcNameEdit)
    
    -- Search button
    local searchButton = AceGUI:Create("Button")
    searchButton:SetText("Search")
    searchButton:SetWidth(80)
    addNPCGroup:AddChild(searchButton)
    
    -- Dungeon dropdown for new NPC
    local newNPCDungeonDropdown = AceGUI:Create("Dropdown")
    newNPCDungeonDropdown:SetLabel("Dungeon")
    newNPCDungeonDropdown:SetWidth(150)
    local dungeonList = {["Other"] = "Other"}
    for abbrev, fullName in pairs(addon.Database.dungeonNames) do
        dungeonList[fullName] = fullName
    end
    newNPCDungeonDropdown:SetList(dungeonList)
    -- Auto-select current dungeon if we're in one
    if currentAbbrev and currentDungeonName then
        newNPCDungeonDropdown:SetValue(currentDungeonName)
    else
        newNPCDungeonDropdown:SetValue("Other")
    end
    addNPCGroup:AddChild(newNPCDungeonDropdown)
    
    -- Target lookup functionality
    targetButton:SetCallback("OnClick", function()
        local targetInfo = addon.Database:GetTargetNPCInfo()
        if not targetInfo then
            statusLabel:SetText("|cffff0000No valid NPC target found.|r")
            return
        end
        
        -- Fill in the form with target data
        npcIDEdit:SetText(tostring(targetInfo.id))
        npcNameEdit:SetText(targetInfo.name)
        
        -- Try to detect dungeon from name first
        local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(targetInfo.name)
        
        -- If no dungeon detected from name, use current location
        if not dungeonName or dungeonName == "Other" then
            local currentAbbrev, currentDungeonName, instanceType = addon.Database:GetCurrentDungeonInfo()
            if currentDungeonName and currentAbbrev then
                dungeonName = currentDungeonName
                abbrev = currentAbbrev
                mobName = targetInfo.name -- Use full name since no prefix detected
                statusLabel:SetText("|cff00ffff Target loaded from current dungeon: " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ")|r")
            end
        end
        
        -- Set dungeon and clean up name
        if dungeonName and dungeonName ~= "Other" then
            newNPCDungeonDropdown:SetValue(dungeonName)
            if mobName then
                npcNameEdit:SetText(mobName) -- Use just the mob name without prefix
            end
        end
        
        -- Check if NPC already exists
        if targetInfo.exists then
            statusLabel:SetText("|cffff8800NPC already exists in database.|r")
        else
            -- Only override status if we haven't already set a "current dungeon" message
            local currentStatusSet = (dungeonName and currentDungeonName and dungeonName == currentDungeonName)
            if not currentStatusSet then
                statusLabel:SetText("|cff00ff00Target loaded: " .. targetInfo.name .. " (ID: " .. targetInfo.id .. ")|r")
            end
        end
    end)
    
    -- Search functionality
    searchButton:SetCallback("OnClick", function()
        local searchTerm = npcNameEdit:GetText():trim()
        if searchTerm == "" then
            statusLabel:SetText("|cffff0000Enter a name to search.|r")
            return
        end
        
        local results = addon.Database:SearchNPCsByName(searchTerm)
        if #results == 0 then
            statusLabel:SetText("|cffff8800No NPCs found matching '" .. searchTerm .. "'.|r")
        elseif #results == 1 then
            -- Single result - auto fill
            local result = results[1]
            npcIDEdit:SetText(tostring(result.id))
            npcNameEdit:SetText(result.name)
            
            -- Try to detect dungeon
            local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(result.name)
            if dungeonName and dungeonName ~= "Other" then
                newNPCDungeonDropdown:SetValue(dungeonName)
                npcNameEdit:SetText(mobName)
            end
            
            statusLabel:SetText("|cff00ff00Found: " .. result.name .. " (ID: " .. result.id .. ", " .. result.source .. ")|r")
        else
            -- Multiple results - show first few
            local resultText = "Found " .. #results .. " results: "
            for i = 1, math.min(3, #results) do
                if i > 1 then resultText = resultText .. ", " end
                resultText = resultText .. results[i].name .. " (" .. results[i].id .. ")"
            end
            if #results > 3 then
                resultText = resultText .. "..."
            end
            statusLabel:SetText("|cff00ffff" .. resultText .. "|r")
            
            -- Auto-fill with first result
            local result = results[1]
            npcIDEdit:SetText(tostring(result.id))
            npcNameEdit:SetText(result.name)
            
            -- Try to detect dungeon
            local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(result.name)
            if dungeonName and dungeonName ~= "Other" then
                newNPCDungeonDropdown:SetValue(dungeonName)
                npcNameEdit:SetText(mobName)
            end
        end
    end)
    
    -- NPC ID validation
    npcIDEdit:SetCallback("OnTextChanged", function(widget, event, text)
        local npcID = tonumber(text)
        if npcID then
            local exists, source = addon.Database:NPCExists(npcID)
            if exists then
                statusLabel:SetText("|cffff8800NPC ID " .. npcID .. " already exists (" .. source .. ").|r")
            else
                statusLabel:SetText("")
            end
        end
    end)
    
    -- Enter key support for search in add NPC section
    npcNameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        searchButton.frame:Click()
    end)
    
    -- CC effectiveness checkboxes for new NPC
    local newNPCCC = {true, true, true, true, true} -- Default all to true
    local newNPCCCChecks = {}
    
    for i, ccType in ipairs(ccTypes) do
        local ccCheck = AceGUI:Create("CheckBox")
        ccCheck:SetLabel(ccType)
        ccCheck:SetWidth(70)
        ccCheck:SetValue(true)
        ccCheck:SetCallback("OnValueChanged", function(widget, event, value)
            newNPCCC[i] = value
        end)
        addNPCGroup:AddChild(ccCheck)
        newNPCCCChecks[i] = ccCheck
    end
    
    -- Add button
    local addButton = AceGUI:Create("Button")
    addButton:SetText("Add NPC")
    addButton:SetWidth(100)
    addButton:SetCallback("OnClick", function()
        local npcID = tonumber(npcIDEdit:GetText())
        local npcName = npcNameEdit:GetText():trim()
        local selectedDungeon = newNPCDungeonDropdown:GetValue()
        
        if not npcID then
            statusLabel:SetText("|cffff0000Please enter a valid NPC ID.|r")
            return
        end
        
        if npcName == "" then
            statusLabel:SetText("|cffff0000Please enter an NPC name.|r")
            return
        end
        
        -- Check if NPC already exists
        local exists, source = addon.Database:NPCExists(npcID)
        if exists then
            statusLabel:SetText("|cffff0000NPC ID " .. npcID .. " already exists in " .. source .. ". Use Reset button to modify database NPCs.|r")
            return
        end
        
        -- Construct full name based on dungeon
        local fullName = npcName
        if selectedDungeon ~= "Other" then
            local abbrev = nil
            for abbreviation, fullDungeonName in pairs(addon.Database.dungeonNames) do
                if fullDungeonName == selectedDungeon then
                    abbrev = abbreviation
                    break
                end
            end
            if abbrev then
                fullName = abbrev .. " - " .. npcName
            end
        end
        
        -- Add to custom NPCs
        addon.Config.db.customNPCs[npcID] = {
            name = fullName,
            cc = {newNPCCC[1], newNPCCC[2], newNPCCC[3], newNPCCC[4], newNPCCC[5]},
            dungeon = selectedDungeon
        }
        
        statusLabel:SetText("|cff00ff00Successfully added " .. fullName .. " (ID: " .. npcID .. ")|r")
        
        -- Clear inputs
        npcIDEdit:SetText("")
        npcNameEdit:SetText("")
        -- Reset to current dungeon if we're in one, otherwise "Other"
        if currentAbbrev and currentDungeonName then
            newNPCDungeonDropdown:SetValue(currentDungeonName)
        else
            newNPCDungeonDropdown:SetValue("Other")
        end
        
        -- Reset checkboxes to default (all true)
        for i, check in ipairs(newNPCCCChecks) do
            check:SetValue(true)
            newNPCCC[i] = true
        end
        
        -- Refresh the tab
        container:ReleaseChildren()
        self:CreateNpcsTab(container)
    end)
    addNPCGroup:AddChild(addButton)
    
    -- Help text for NPC management
    local manageHelpText = AceGUI:Create("Label")
    manageHelpText:SetText("NPCs are grouped by dungeon with Expand/Collapse buttons. Current Location shows where you are and offers filtering. 'Find Target in List' locates your target, 'Search NPCs' finds existing ones. 'Get from Target' auto-fills from your current target and detects dungeon. When in a dungeon, the addon auto-selects that dungeon for new NPCs. Use Reset to revert database NPCs, Delete to remove custom ones.")
    manageHelpText:SetFullWidth(true)
    scroll:AddChild(manageHelpText)
end

-- Create Players tab content
function addon.UI:CreatePlayersTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Priority players help text
    local priorityHelp = AceGUI:Create("Label")
    priorityHelp:SetText("Players listed here will be prioritized in the rotation order.")
    priorityHelp:SetFullWidth(true)
    scroll:AddChild(priorityHelp)
    
    -- Current priority players display
    local priorityDisplay = AceGUI:Create("Label")
    priorityDisplay:SetFullWidth(true)
    
    local function updatePriorityDisplay()
        local players = {}
        for name in pairs(addon.Config.db.priorityPlayers) do
            table.insert(players, name)
        end
        table.sort(players)
        if #players > 0 then
            priorityDisplay:SetText("Current: " .. table.concat(players, ", "))
        else
            priorityDisplay:SetText("Current: (No priority players set)")
        end
    end
    updatePriorityDisplay()
    scroll:AddChild(priorityDisplay)
    
    -- Add player editbox
    local addPlayerEdit = AceGUI:Create("EditBox")
    addPlayerEdit:SetLabel("Add Player")
    addPlayerEdit:SetWidth(200)
    addPlayerEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        local name = text:trim()
        if name ~= "" then
            addon.Config:AddPriorityPlayer(name)
            widget:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(addPlayerEdit)
    
    -- Add player button
    local addButton = AceGUI:Create("Button")
    addButton:SetText("Add")
    addButton:SetWidth(80)
    addButton:SetCallback("OnClick", function()
        local name = addPlayerEdit:GetText():trim()
        if name ~= "" then
            addon.Config:AddPriorityPlayer(name)
            addPlayerEdit:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(addButton)
    
    -- Add some spacing
    local spacer1 = AceGUI:Create("Label")
    spacer1:SetText(" ")
    spacer1:SetFullWidth(true)
    scroll:AddChild(spacer1)
    
    -- Remove player editbox
    local removePlayerEdit = AceGUI:Create("EditBox")
    removePlayerEdit:SetLabel("Remove Player")
    removePlayerEdit:SetWidth(200)
    removePlayerEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        local name = text:trim()
        if name ~= "" then
            addon.Config:RemovePriorityPlayer(name)
            widget:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(removePlayerEdit)
    
    -- Remove player button
    local removeButton = AceGUI:Create("Button")
    removeButton:SetText("Remove")
    removeButton:SetWidth(80)
    removeButton:SetCallback("OnClick", function()
        local name = removePlayerEdit:GetText():trim()
        if name ~= "" then
            addon.Config:RemovePriorityPlayer(name)
            removePlayerEdit:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(removeButton)
end

-- Show configuration frame
function addon.UI:ShowConfigFrame()
    if not AceGUI then
        print("|cffff0000CC Rotation Helper:|r AceGUI-3.0 not found! Please install Ace3 libraries.")
        return
    end
    
    self:CreateConfigFrame()
    self.configFrame:Show()
end
