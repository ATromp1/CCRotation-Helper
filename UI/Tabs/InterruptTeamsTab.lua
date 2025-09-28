local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local InterruptTeamsTab = {}

-- Target marker info for display
local RAID_TARGET_MARKERS = {
    [1] = {name = "Star", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:16|t", color = "ffffffff"},
    [2] = {name = "Circle", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:16|t", color = "ffffff00"},
    [3] = {name = "Diamond", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:16|t", color = "ff800080"},
    [4] = {name = "Triangle", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:16|t", color = "ff00ff00"},
    [5] = {name = "Moon", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:16|t", color = "ff00ffff"},
    [6] = {name = "Square", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:16|t", color = "ffff0000"},
    [7] = {name = "Cross", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:16|t", color = "ffffffff"},
    [8] = {name = "Skull", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:16|t", color = "ffffffff"}
}

-- Store reference to container for refreshing
local currentContainer = nil

-- Create InterruptTeams tab content
function InterruptTeamsTab.create(container)
    currentContainer = container  -- Store reference for refresh

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)

    -- Enable/Disable checkbox
    local enableCheckbox = AceGUI:Create("CheckBox")
    enableCheckbox:SetLabel("Enable Interrupt Teams |cffff8800(WORK IN PROGRESS)|r")

    -- Safely get current value
    local currentValue = false
    if addon.Config and addon.Config.db then
        currentValue = addon.Config.db.interruptTeamsEnabled or false
    end
    enableCheckbox:SetValue(currentValue)
    enableCheckbox:SetFullWidth(true)

    enableCheckbox:SetCallback("OnValueChanged", function(widget, event, value)
        if addon.Config and addon.Config.db then
            addon.Config.db.interruptTeamsEnabled = value
            addon.Config:FireEvent("CONFIG_CHANGED")
        end
    end)
    scroll:AddChild(enableCheckbox)

    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("Assign interrupt teams to target markers. Players will interrupt in priority order when their assigned marker is targeted.\n|cffff8800Tip:|r Use 'Add Marker Team' to set up teams only for markers you actually use.")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)

    -- Available group members section
    InterruptTeamsTab.createAvailableMembersSection(scroll)

    -- Active teams section
    InterruptTeamsTab.createActiveTeamsSection(scroll)

    -- Add new team section
    InterruptTeamsTab.createAddTeamSection(scroll)

    -- Management buttons
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetLayout("Flow")
    scroll:AddChild(buttonGroup)

    local debugButton = AceGUI:Create("Button")
    debugButton:SetText("Print Teams to Chat")
    debugButton:SetWidth(150)
    debugButton:SetCallback("OnClick", function()
        if addon.InterruptTeams then
            addon.InterruptTeams:PrintTeams()
        end
    end)
    buttonGroup:AddChild(debugButton)

    local clearButton = AceGUI:Create("Button")
    clearButton:SetText("Clear All Teams")
    clearButton:SetWidth(150)
    clearButton:SetCallback("OnClick", function()
        InterruptTeamsTab.clearAllTeams()
    end)
    buttonGroup:AddChild(clearButton)

    local debugDataButton = AceGUI:Create("Button")
    debugDataButton:SetText("Debug Data")
    debugDataButton:SetWidth(100)
    debugDataButton:SetCallback("OnClick", function()
        if addon.Config and addon.Config.db then
            -- Debug data removed
            for k, v in pairs(addon.Config.db.interruptTeams or {}) do
                print("  Marker", k, ":", v, "team size:", #v)
            end
        else
            -- DEBUG removed: No config available")
        end
    end)
    buttonGroup:AddChild(debugDataButton)
end

-- Create available group members section
function InterruptTeamsTab.createAvailableMembersSection(parent)
    local group = AceGUI:Create("InlineGroup")
    group:SetTitle("Available Group Members")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    parent:AddChild(group)

    -- Get available members with interrupt capability
    local availableMembers = {}
    if addon.InterruptTeams then
        availableMembers = addon.InterruptTeams:GetAvailableGroupMembers()
    end

    if #availableMembers == 0 then
        local noMembersLabel = AceGUI:Create("Label")
        noMembersLabel:SetText("|cffff8800No group members with interrupt abilities found.|r\nMake sure you're in a group or party.")
        noMembersLabel:SetFullWidth(true)
        group:AddChild(noMembersLabel)
    else
        local membersText = "Players with interrupt abilities: |cff00ff00" .. table.concat(availableMembers, "|r, |cff00ff00") .. "|r"
        local membersLabel = AceGUI:Create("Label")
        membersLabel:SetText(membersText)
        membersLabel:SetFullWidth(true)
        group:AddChild(membersLabel)
    end
end

-- Create active teams section
function InterruptTeamsTab.createActiveTeamsSection(parent)
    local group = AceGUI:Create("InlineGroup")
    group:SetTitle("Active Interrupt Teams")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    parent:AddChild(group)

    local hasActiveTeams = false


    -- Only show teams that have members assigned
    for markerIndex = 1, 8 do
        local currentTeam = {}
        if addon.Config and addon.Config.db then
            currentTeam = addon.Config.db.interruptTeams[markerIndex] or {}
        end

        -- Show teams that exist (even if empty) or have members
        if currentTeam and (type(currentTeam) == "table") then
            hasActiveTeams = true
            InterruptTeamsTab.createCompactMarkerSection(group, markerIndex)
        end
    end

    if not hasActiveTeams then
        local noTeamsLabel = AceGUI:Create("Label")
        noTeamsLabel:SetText("|cffccccccNo teams configured yet. Use 'Add Marker Team' below to create your first team.|r")
        noTeamsLabel:SetFullWidth(true)
        group:AddChild(noTeamsLabel)
    end
end

-- Create add new team section
function InterruptTeamsTab.createAddTeamSection(parent)
    local group = AceGUI:Create("InlineGroup")
    group:SetTitle("Add Marker Team")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    parent:AddChild(group)

    -- Marker selection dropdown
    local markerDropdown = AceGUI:Create("Dropdown")
    markerDropdown:SetLabel("Target Marker")
    markerDropdown:SetWidth(200)

    -- Build list of unused markers
    local unusedMarkers = {}
    for markerIndex = 1, 8 do
        local currentTeam = {}
        if addon.Config and addon.Config.db then
            currentTeam = addon.Config.db.interruptTeams[markerIndex] or {}
        end

        if #currentTeam == 0 then
            local marker = RAID_TARGET_MARKERS[markerIndex]
            unusedMarkers[markerIndex] = marker.icon .. " " .. marker.name
        end
    end


    markerDropdown:SetList(unusedMarkers)
    group:AddChild(markerDropdown)

    -- Show message if no markers available
    if next(unusedMarkers) == nil then
        local noMarkersLabel = AceGUI:Create("Label")
        noMarkersLabel:SetText("|cffff8800All markers already have teams assigned.|r")
        noMarkersLabel:SetFullWidth(true)
        group:AddChild(noMarkersLabel)
    end

    -- Add team button
    local addButton = AceGUI:Create("Button")
    addButton:SetText("Add Team")
    addButton:SetCallback("OnClick", function()
        local selectedMarker = markerDropdown:GetValue()

        if selectedMarker then
            -- Convert to number if it's a string representation of a number
            local markerIndex = tonumber(selectedMarker) or selectedMarker

            -- Use the correct config reference - addon.Config.db IS the profile
            if addon.Config and addon.Config.db then
                -- Ensure interruptTeams table exists
                if not addon.Config.db.interruptTeams then
                    addon.Config.db.interruptTeams = {}
                end

                addon.Config.db.interruptTeams[markerIndex] = {}
                addon.Config:FireEvent("CONFIG_CHANGED")

                -- Refresh the tab content by recreating it
                InterruptTeamsTab.refreshTab()
            end
        end
    end)
    group:AddChild(addButton)
end

-- Create compact marker section for active teams
function InterruptTeamsTab.createCompactMarkerSection(parent, markerIndex)
    local marker = RAID_TARGET_MARKERS[markerIndex]

    -- Create inline group for this marker
    local group = AceGUI:Create("InlineGroup")
    group:SetTitle(marker.icon .. " " .. marker.name .. " Team")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    parent:AddChild(group)

    -- Get current team
    local currentTeam = {}
    if addon.Config and addon.Config.db then
        currentTeam = addon.Config.db.interruptTeams[markerIndex] or {}
    end

    -- Display current team members in a more compact way
    InterruptTeamsTab.createTeamMembersList(group, markerIndex, currentTeam)

    -- Add player section
    InterruptTeamsTab.createAddPlayerSection(group, markerIndex)
end

-- Create team members list with better UX
function InterruptTeamsTab.createTeamMembersList(parent, markerIndex, team)
    if #team == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cffccccccNo players assigned to this team yet.|r")
        emptyLabel:SetFullWidth(true)
        parent:AddChild(emptyLabel)
        return
    end

    for i, playerName in ipairs(team) do
        local playerGroup = AceGUI:Create("SimpleGroup")
        playerGroup:SetFullWidth(true)
        playerGroup:SetLayout("Flow")
        parent:AddChild(playerGroup)


        -- Priority number and player name
        local nameLabel = AceGUI:Create("Label")
        nameLabel:SetText(string.format("|cffff8800%d.|r %s", i, playerName))
        nameLabel:SetWidth(150)
        playerGroup:AddChild(nameLabel)

        -- Move up button (if not first)
        if i > 1 then
            local moveUpButton = AceGUI:Create("Button")
            moveUpButton:SetText("Move Up")
            moveUpButton:SetCallback("OnClick", function()
                InterruptTeamsTab.movePlayerUp(markerIndex, i)
            end)
            playerGroup:AddChild(moveUpButton)
        end

        -- Move down button (if not last)
        if i < #team then
            local moveDownButton = AceGUI:Create("Button")
            moveDownButton:SetText("Move Down")
            moveDownButton:SetCallback("OnClick", function()
                InterruptTeamsTab.movePlayerDown(markerIndex, i)
            end)
            playerGroup:AddChild(moveDownButton)
        end

        -- Remove button
        local removeButton = AceGUI:Create("Button")
        removeButton:SetText("Remove")
        removeButton:SetCallback("OnClick", function()
            if addon.InterruptTeams then
                if addon.InterruptTeams:RemovePlayerFromTeam(markerIndex, playerName) then
                    -- Refresh the tab content
                    InterruptTeamsTab.refreshTab()
                end
            end
        end)
        playerGroup:AddChild(removeButton)
    end
end

-- Create add player section for a team
function InterruptTeamsTab.createAddPlayerSection(parent, markerIndex)
    local addGroup = AceGUI:Create("SimpleGroup")
    addGroup:SetFullWidth(true)
    addGroup:SetLayout("Flow")
    parent:AddChild(addGroup)

    -- Add player dropdown
    local addDropdown = AceGUI:Create("Dropdown")
    addDropdown:SetLabel("Add Player")
    addDropdown:SetWidth(150)

    -- Populate with available group members
    local availableMembers = {}
    if addon.InterruptTeams then
        local members = addon.InterruptTeams:GetAvailableGroupMembers()
        for _, memberName in ipairs(members) do
            availableMembers[memberName] = memberName
        end
    end

    addDropdown:SetList(availableMembers)
    addGroup:AddChild(addDropdown)

    local addPlayerButton = AceGUI:Create("Button")
    addPlayerButton:SetText("Add Player")
    addPlayerButton:SetCallback("OnClick", function()
        local selectedPlayer = addDropdown:GetValue()
        if selectedPlayer and addon.InterruptTeams then
            if addon.InterruptTeams:AddPlayerToTeam(markerIndex, selectedPlayer) then
                -- Refresh the tab content
                InterruptTeamsTab.refreshTab()
            else
                print("Failed to add " .. selectedPlayer .. " to team")
            end
        end
        addDropdown:SetValue("")  -- Reset dropdown
    end)
    addGroup:AddChild(addPlayerButton)

    -- Remove team button
    local removeTeamButton = AceGUI:Create("Button")
    removeTeamButton:SetText("Remove Team")
    removeTeamButton:SetCallback("OnClick", function()
        InterruptTeamsTab.removeTeam(markerIndex)
    end)
    addGroup:AddChild(removeTeamButton)
end

-- Clear all teams function
function InterruptTeamsTab.clearAllTeams()
    if addon.Config and addon.Config.db then
        addon.Config.db.interruptTeams = {}
        addon.Config:FireEvent("CONFIG_CHANGED")
        addon.Config:RefreshConfigUI()
    end
end

-- Remove a team function
function InterruptTeamsTab.removeTeam(markerIndex)
    if addon.Config and addon.Config.db then
        addon.Config.db.interruptTeams[markerIndex] = {}
        addon.Config:FireEvent("CONFIG_CHANGED")
        InterruptTeamsTab.refreshTab()
    end
end

-- Create a section for configuring one marker's team (legacy function - keeping for compatibility)
function InterruptTeamsTab.createMarkerSection(parent, markerIndex)
    local marker = RAID_TARGET_MARKERS[markerIndex]

    -- Create inline group for this marker
    local group = AceGUI:Create("InlineGroup")
    group:SetTitle(marker.icon .. " " .. marker.name .. " Team")
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    parent:AddChild(group)

    -- Get current team
    local currentTeam = {}
    if addon.Config and addon.Config.db then
        currentTeam = addon.Config.db.interruptTeams[markerIndex] or {}
    end

    -- Display current team members
    for i, playerName in ipairs(currentTeam) do
        InterruptTeamsTab.createPlayerEntry(group, markerIndex, playerName, i)
    end

    -- Add player dropdown
    local addDropdown = AceGUI:Create("Dropdown")
    addDropdown:SetLabel("Add Player")
    addDropdown:SetWidth(200)

    -- Populate with available group members
    local availableMembers = {}
    if addon.InterruptTeams then
        local members = addon.InterruptTeams:GetAvailableGroupMembers()
        for _, memberName in ipairs(members) do
            availableMembers[memberName] = memberName
        end
    end

    addDropdown:SetList(availableMembers)
    addDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        if value and addon.InterruptTeams then
            if addon.InterruptTeams:AddPlayerToTeam(markerIndex, value) then
                -- Refresh the config UI
                addon.Config:RefreshConfigUI()
            end
        end
        widget:SetValue("")  -- Reset dropdown
    end)

    group:AddChild(addDropdown)
end

-- Create a player entry in a team
function InterruptTeamsTab.createPlayerEntry(parent, markerIndex, playerName, position)
    local entryGroup = AceGUI:Create("SimpleGroup")
    entryGroup:SetFullWidth(true)
    entryGroup:SetLayout("Flow")
    parent:AddChild(entryGroup)

    -- Player name label with priority number
    local nameLabel = AceGUI:Create("Label")
    nameLabel:SetText(string.format("%d. %s", position, playerName))
    nameLabel:SetWidth(150)
    entryGroup:AddChild(nameLabel)

    -- Move up button (if not first)
    if position > 1 then
        local moveUpButton = AceGUI:Create("Button")
        moveUpButton:SetText("↑")
        moveUpButton:SetWidth(30)
        moveUpButton:SetCallback("OnClick", function()
            InterruptTeamsTab.movePlayerUp(markerIndex, position)
        end)
        entryGroup:AddChild(moveUpButton)
    end

    -- Move down button (if not last)
    local currentTeam = {}
    if addon.Config and addon.Config.db then
        currentTeam = addon.Config.db.interruptTeams[markerIndex] or {}
    end
    if position < #currentTeam then
        local moveDownButton = AceGUI:Create("Button")
        moveDownButton:SetText("↓")
        moveDownButton:SetWidth(30)
        moveDownButton:SetCallback("OnClick", function()
            InterruptTeamsTab.movePlayerDown(markerIndex, position)
        end)
        entryGroup:AddChild(moveDownButton)
    end

    -- Remove button
    local removeButton = AceGUI:Create("Button")
    removeButton:SetText("Remove")
    removeButton:SetWidth(80)
    removeButton:SetCallback("OnClick", function()
        if addon.InterruptTeams then
            if addon.InterruptTeams:RemovePlayerFromTeam(markerIndex, playerName) then
                -- Refresh the tab content
                InterruptTeamsTab.refreshTab()
            end
        end
    end)
    entryGroup:AddChild(removeButton)
end

-- Move a player up in the priority order
function InterruptTeamsTab.movePlayerUp(markerIndex, position)
    if not addon.Config or not addon.Config.db then
        return
    end

    local teams = addon.Config.db.interruptTeams
    if not teams[markerIndex] or position <= 1 then
        return
    end

    -- Swap with previous player
    local temp = teams[markerIndex][position]
    teams[markerIndex][position] = teams[markerIndex][position - 1]
    teams[markerIndex][position - 1] = temp

    addon.Config:FireEvent("CONFIG_CHANGED")
    InterruptTeamsTab.refreshTab()
end

-- Move a player down in the priority order
function InterruptTeamsTab.movePlayerDown(markerIndex, position)
    if not addon.Config or not addon.Config.db then
        return
    end

    local teams = addon.Config.db.interruptTeams
    if not teams[markerIndex] or position >= #teams[markerIndex] then
        return
    end

    -- Swap with next player
    local temp = teams[markerIndex][position]
    teams[markerIndex][position] = teams[markerIndex][position + 1]
    teams[markerIndex][position + 1] = temp

    addon.Config:FireEvent("CONFIG_CHANGED")
    InterruptTeamsTab.refreshTab()
end

-- Refresh the tab by clearing and recreating content
function InterruptTeamsTab.refreshTab()
    -- DEBUG removed: refreshTab called, currentContainer =", currentContainer)
    if currentContainer then
        -- DEBUG removed: Clearing and recreating tab content")
        -- Clear existing content
        currentContainer:ReleaseChildren()

        -- Recreate the tab content
        InterruptTeamsTab.create(currentContainer)
        -- DEBUG removed: Tab content recreated")
    else
        -- DEBUG removed: No currentContainer available")
    end
end

-- Register InterruptTeamsTab module for ConfigFrame to load
addon.InterruptTeamsTabModule = InterruptTeamsTab

return InterruptTeamsTab