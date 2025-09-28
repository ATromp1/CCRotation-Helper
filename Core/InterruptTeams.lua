local addonName, addon = ...

addon.InterruptTeams = {}
local InterruptTeams = addon.InterruptTeams

-- Target marker constants (WoW uses 1-8 for markers)
local RAID_TARGET_MARKERS = {
    [1] = "Star",
    [2] = "Circle",
    [3] = "Diamond",
    [4] = "Triangle",
    [5] = "Moon",
    [6] = "Square",
    [7] = "Cross",
    [8] = "Skull"
}

-- Constants for marker detection
local MARKER_TIMEOUT = 5  -- Seconds before considering a marker "stale"
local SCAN_FREQUENCY = 1  -- Seconds between automatic scans

-- LibOpenRaid reference for cooldown tracking
local lib = LibStub("LibOpenRaid-1.0", true)

-- Tracking variables
local lastInterruptSuggestion = {}  -- [markerIndex] = {player, time}
local playerInterruptCooldowns = {}  -- [playerName] = {spellID, remainingCD}
local interruptUsageTimes = {}  -- [markerIndex][playerName] = timestamp when they used interrupt
local activeMarkers = {}  -- [markerIndex] = timestamp when marker was last seen
local lastScanTime = 0  -- Track when we last scanned

-- Use unified event system
function InterruptTeams:RegisterEventListener(event, callback)
    addon.EventSystem:RegisterEventListener(event, callback)
end

function InterruptTeams:FireEvent(event, ...)
    addon.EventSystem:FireEvent(event, ...)
end

-- Initialize the interrupt teams system
function InterruptTeams:Initialize()
    if not addon.Config then
        return
    end

    -- Initialize tracking tables
    self:RefreshPlayerList()

    -- Initialize interrupt usage tracking
    self:InitializeUsageTracking()

    -- Register LibOpenRaid callbacks if available
    if lib then
        self:RegisterLibOpenRaidCallbacks()
    end

    -- Register for events
    self:RegisterEvents()

    -- Register for config changes
    self:RegisterEventListener("CONFIG_CHANGED", function()
        self:OnConfigChanged()
        self:RefreshDisplay()
    end)

    -- InterruptTeams initialized
end

-- Register game events
function InterruptTeams:RegisterEvents()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end

    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Combat start
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Combat end
    self.eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "GROUP_ROSTER_UPDATE" then
            self:RefreshPlayerList()
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:RefreshPlayerList()
        elseif event == "RAID_TARGET_UPDATE" or
               event == "PLAYER_TARGET_CHANGED" or
               event == "NAME_PLATE_UNIT_ADDED" or
               event == "NAME_PLATE_UNIT_REMOVED" then
            self:OnRaidTargetUpdate()
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Start more frequent scanning during combat
            self:StartCombatScanning()
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Stop frequent scanning after combat
            self:StopCombatScanning()
        end
    end)

    -- Start periodic scanning
    self:StartPeriodicScanning()
end

-- Refresh the list of group members
function InterruptTeams:RefreshPlayerList()
    if not IsInGroup() then
        return
    end

    -- Update cooldown tracking for current group members
    for i = 1, GetNumGroupMembers() do
        local unit
        if IsInRaid() then
            unit = "raid" .. i
        else
            if i == 1 then
                unit = "player"
            else
                unit = "party" .. (i - 1)
            end
        end

        local name = UnitName(unit)
        if name then
            -- Initialize cooldown tracking for this player
            if not playerInterruptCooldowns[name] then
                playerInterruptCooldowns[name] = {}
            end
        end
    end
end

-- Get the interrupt team for a specific target marker
function InterruptTeams:GetTeamForMarker(markerIndex)
    if not addon.Config or not addon.Config.db then
        return {}
    end

    local teams = addon.Config.db.interruptTeams
    return teams[markerIndex] or {}
end

-- Check if interrupt teams feature is enabled
function InterruptTeams:IsEnabled()
    if not addon.Config or not addon.Config.db then
        return false
    end

    -- Setting must be enabled AND we must be in a dungeon
    if not addon.Config.db.interruptTeamsEnabled then
        return false
    end

    -- Check if we're in a dungeon (5-player instance)
    local isInstance, instanceType = IsInInstance()
    return isInstance and instanceType == "party"
end

-- Get the next available interrupter for a team
function InterruptTeams:GetNextInterrupter(markerIndex)
    if not self:IsEnabled() then
        return nil
    end

    local rotatedTeam = self:GetRotatedTeam(markerIndex)
    if not rotatedTeam or #rotatedTeam == 0 then
        return nil
    end

    -- Check players in rotated order with priority resolution
    for i, playerName in ipairs(rotatedTeam) do
        -- Check if this player is first in any other team (higher priority)
        local isFirstElsewhere = self:IsPlayerFirstInOtherTeam(playerName, markerIndex)

        if not isFirstElsewhere then
            -- Check if this player's interrupt is available
            if self:IsPlayerInterruptAvailable(playerName) then
                return playerName
            end
        end
    end

    -- If no one has interrupt available after priority checks, return first available
    for i, playerName in ipairs(rotatedTeam) do
        local isFirstElsewhere = self:IsPlayerFirstInOtherTeam(playerName, markerIndex)
        if not isFirstElsewhere then
            return playerName
        end
    end

    -- Fallback to first player if all have higher priorities elsewhere
    return rotatedTeam[1]
end

-- Check if a player is first in any other team that has an active marker
function InterruptTeams:IsPlayerFirstInOtherTeam(playerName, excludeMarkerIndex)
    if not addon.Config or not addon.Config.db then
        return false
    end

    local teams = addon.Config.db.interruptTeams
    for markerIndex = 1, 8 do
        if markerIndex ~= excludeMarkerIndex then
            local team = teams[markerIndex]
            if team and #team > 0 and team[1] == playerName then
                -- Check if this marker actually exists in the world
                if self:IsMarkerActive(markerIndex) then
                    return true
                end
            end
        end
    end

    return false
end

-- Handle raid target marker updates
function InterruptTeams:OnRaidTargetUpdate()
    -- Scan for all current markers and update our cache
    self:ScanAllMarkers()

    -- Refresh display when markers change
    self:RefreshDisplay()
end

-- Scan all visible units for markers
function InterruptTeams:ScanAllMarkers()
    local foundMarkers = {}

    -- Check all group member targets
    for i = 1, GetNumGroupMembers() do
        local unit
        if IsInRaid() then
            unit = "raid" .. i
        else
            if i == 1 then
                unit = "player"
            else
                unit = "party" .. (i - 1)
            end
        end

        if UnitExists(unit) then
            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) then
                local markerIndex = GetRaidTargetIndex(targetUnit)
                if markerIndex then
                    foundMarkers[markerIndex] = true
                end
            end
        end
    end

    -- Also scan nameplate units for markers (this catches marked mobs even if not targeted)
    for i = 1, 40 do
        local nameplateUnit = "nameplate" .. i
        if UnitExists(nameplateUnit) and UnitCanAttack("player", nameplateUnit) then
            local markerIndex = GetRaidTargetIndex(nameplateUnit)
            if markerIndex then
                foundMarkers[markerIndex] = true
            end
        end
    end

    -- Update active markers with timestamps and clean up stale ones
    local currentTime = GetTime()
    for markerIndex = 1, 8 do
        if foundMarkers[markerIndex] then
            -- Marker found - update timestamp
            activeMarkers[markerIndex] = currentTime
        else
            -- Marker not found - check if it's stale
            local lastSeen = activeMarkers[markerIndex]
            if lastSeen and (currentTime - lastSeen) > MARKER_TIMEOUT then
                -- Marker is stale, remove it
                activeMarkers[markerIndex] = nil
            end
        end
    end

end

-- Check if a target marker is currently active/detected
function InterruptTeams:IsMarkerActive(markerIndex)
    local lastSeen = activeMarkers[markerIndex]
    if not lastSeen then
        return false
    end

    -- Consider marker active if seen recently
    local currentTime = GetTime()
    return (currentTime - lastSeen) <= MARKER_TIMEOUT
end

-- Start periodic scanning for marker changes
function InterruptTeams:StartPeriodicScanning()
    if self.periodicTimer then
        return  -- Already running
    end

    self.periodicTimer = C_Timer.NewTicker(SCAN_FREQUENCY, function()
        local currentTime = GetTime()
        if currentTime - lastScanTime >= SCAN_FREQUENCY then
            self:ScanAllMarkers()
            lastScanTime = currentTime
        end
    end)
end

-- Start more frequent scanning during combat
function InterruptTeams:StartCombatScanning()
    if self.combatTimer then
        return  -- Already running
    end

    -- Scan every 0.5 seconds during combat
    self.combatTimer = C_Timer.NewTicker(0.5, function()
        self:ScanAllMarkers()
    end)
end

-- Stop frequent combat scanning
function InterruptTeams:StopCombatScanning()
    if self.combatTimer then
        self.combatTimer:Cancel()
        self.combatTimer = nil
    end
end

-- Check if a player's interrupt is available
function InterruptTeams:IsPlayerInterruptAvailable(playerName)
    if not lib then
        return true  -- Assume available if LibOpenRaid not loaded
    end

    -- Get interrupt spell for this player
    local interruptSpellID = self:GetPlayerInterruptSpell(playerName)
    if not interruptSpellID or type(interruptSpellID) ~= "number" then
        return false  -- No interrupt spell for this class or invalid spell ID
    end

    -- Find the unit for this player
    local unit = self:FindUnitByName(playerName)
    if not unit then
        return true  -- Assume available if we can't find the unit
    end

    -- Validate unit exists and has valid data
    if not UnitExists(unit) then
        return true  -- Assume available if unit doesn't exist
    end

    -- Check cooldown status using LibOpenRaid with error protection
    local success, isReady, normalizedPercent, timeLeft, charges = pcall(lib.GetCooldownStatusFromUnitSpellID, unit, interruptSpellID)

    if not success then
        -- LibOpenRaid call failed, assume spell is available
        return true
    end

    -- Return true if the spell is ready (not on cooldown)
    return isReady == true
end

-- Find the unit for a player name
function InterruptTeams:FindUnitByName(playerName)
    -- Check if it's the player
    if playerName == UnitName("player") then
        return "player"
    elseif IsInGroup() then
        -- Check group members
        for i = 1, GetNumGroupMembers() do
            local groupUnit
            if IsInRaid() then
                groupUnit = "raid" .. i
            else
                if i == 1 then
                    groupUnit = "player"
                else
                    groupUnit = "party" .. (i - 1)
                end
            end

            if UnitExists(groupUnit) and UnitName(groupUnit) == playerName then
                return groupUnit
            end
        end
    end

    return nil
end

-- Get the interrupt spell ID for a player based on their class
function InterruptTeams:GetPlayerInterruptSpell(playerName)
    local unit = self:FindUnitByName(playerName)
    if not unit then
        return nil
    end

    -- Get class from unit
    local _, class = UnitClass(unit)
    if not class then
        return nil
    end

    -- Get interrupt spells from config
    if not addon.Config or not addon.Config.db or not addon.Config.db.interruptSpells then
        return nil
    end

    return addon.Config.db.interruptSpells[class]
end

-- Initialize interrupt usage tracking
function InterruptTeams:InitializeUsageTracking()
    for markerIndex = 1, 8 do
        if not interruptUsageTimes[markerIndex] then
            interruptUsageTimes[markerIndex] = {}
        end
    end

    -- Store previous cooldown states to detect when spells go on cooldown
    self.previousCooldownStates = {}
end

-- Register LibOpenRaid callbacks
function InterruptTeams:RegisterLibOpenRaidCallbacks()
    if not lib then return end

    local callbacks = {
        CooldownUpdate = function(...)
            self:OnCooldownUpdate(...)
        end
    }

    lib.RegisterCallback(callbacks, "CooldownUpdate", "CooldownUpdate")
end

-- Handle LibOpenRaid cooldown updates to detect interrupt usage
function InterruptTeams:OnCooldownUpdate(...)
    -- Check all group members for interrupt cooldown changes
    for i = 1, GetNumGroupMembers() do
        local unit
        if IsInRaid() then
            unit = "raid" .. i
        else
            if i == 1 then
                unit = "player"
            else
                unit = "party" .. (i - 1)
            end
        end

        local playerName = UnitName(unit)
        if playerName and UnitExists(unit) then
            self:CheckPlayerInterruptCooldown(playerName, unit)
        end
    end
end

-- Check if a player's interrupt just went on cooldown (indicating they used it)
function InterruptTeams:CheckPlayerInterruptCooldown(playerName, unit)
    local interruptSpellID = self:GetPlayerInterruptSpell(playerName)
    if not interruptSpellID then return end

    -- Get current cooldown state
    local success, isReady, normalizedPercent, timeLeft, charges = pcall(lib.GetCooldownStatusFromUnitSpellID, unit, interruptSpellID)
    if not success then return end

    -- Get previous state
    local previousState = self.previousCooldownStates[playerName]

    -- If spell was ready before and is now on cooldown, they used it
    if previousState == true and isReady == false then
        self:OnPlayerUsedInterrupt(playerName, GetTime())
    end

    -- If spell was on cooldown and is now ready, check if we need to reset rotation
    if previousState == false and isReady == true then
        -- Add 2 second buffer before checking reset
        C_Timer.After(2, function()
            self:CheckRotationReset(playerName)
        end)
    end

    -- Store current state for next check
    self.previousCooldownStates[playerName] = isReady
end

-- Check if rotation should reset when a player's interrupt becomes available
function InterruptTeams:CheckRotationReset(playerName)
    local teams = addon.Config.db.interruptTeams
    if not teams then return end

    for markerIndex = 1, 8 do
        local team = teams[markerIndex]
        if team and #team > 0 then
            -- Check if this player is the original first priority in this team
            if team[1] == playerName then
                -- Check if they should be interrupting next (no higher priority conflicts)
                if not self:IsPlayerFirstInOtherTeam(playerName, markerIndex) then
                    -- Check if their interrupt is available
                    if self:IsPlayerInterruptAvailable(playerName) then
                        -- Reset this team's rotation - clear usage times for this team
                        -- Reset rotation silently
                        interruptUsageTimes[markerIndex] = {}
                        -- Refresh display to show reset rotation
                        self:RefreshDisplay()
                    end
                end
            end
        end
    end
end

-- Called when a player uses their interrupt
function InterruptTeams:OnPlayerUsedInterrupt(playerName, timestamp)
    -- Find which teams this player is in and update usage times
    if not addon.Config or not addon.Config.db then
        return
    end

    local teams = addon.Config.db.interruptTeams
    if not teams then return end

    for markerIndex = 1, 8 do
        local team = teams[markerIndex]
        if team then
            for i, teamPlayerName in ipairs(team) do
                if teamPlayerName == playerName then
                    interruptUsageTimes[markerIndex][playerName] = timestamp
                    -- Player used interrupt
                    -- Refresh display to show new rotation order
                    self:RefreshDisplay()
                    break
                end
            end
        end
    end
end

-- Get the team with rotated order based on interrupt usage
function InterruptTeams:GetRotatedTeam(markerIndex)
    local originalTeam = self:GetTeamForMarker(markerIndex)
    if not originalTeam or #originalTeam == 0 then
        return {}
    end

    -- Create a copy of the team with usage timestamps
    local teamWithTimes = {}
    for i, playerName in ipairs(originalTeam) do
        local lastUsed = interruptUsageTimes[markerIndex][playerName] or 0
        table.insert(teamWithTimes, {
            name = playerName,
            lastUsed = lastUsed,
            originalOrder = i
        })
    end

    -- Sort by: last used time (oldest first), then by original order
    -- Players who never used interrupt (lastUsed = 0) come first
    -- Players who used interrupt more recently come last
    table.sort(teamWithTimes, function(a, b)
        -- If both never used, sort by original order
        if a.lastUsed == 0 and b.lastUsed == 0 then
            return a.originalOrder < b.originalOrder
        end
        -- If one never used and one did, never-used comes first
        if a.lastUsed == 0 then return true end
        if b.lastUsed == 0 then return false end
        -- If both have used, older usage comes first (recent usage goes to back)
        return a.lastUsed < b.lastUsed
    end)

    -- Debug output removed to reduce spam

    -- Extract just the names in the new order
    local rotatedTeam = {}
    for i, playerData in ipairs(teamWithTimes) do
        table.insert(rotatedTeam, playerData.name)
    end

    return rotatedTeam
end

-- Get interrupt rotation info for all teams
function InterruptTeams:GetInterruptRotationInfo()
    if not self:IsEnabled() then
        return {}
    end

    local rotationInfo = {}

    for markerIndex = 1, 8 do
        local team = self:GetTeamForMarker(markerIndex)
        -- Only show teams when their marker is actually detected
        if team and #team > 0 and self:IsMarkerActive(markerIndex) then
            local markerName = RAID_TARGET_MARKERS[markerIndex]
            local rotatedTeam = self:GetRotatedTeam(markerIndex)
            local nextInterrupter = self:GetNextInterrupter(markerIndex)

            rotationInfo[markerIndex] = {
                markerName = markerName,
                team = team,
                rotatedTeam = rotatedTeam,
                nextInterrupter = nextInterrupter,
                isPlayerNext = (nextInterrupter == UnitName("player"))
            }
        end
    end

    return rotationInfo
end

-- Force refresh of interrupt rotation display
function InterruptTeams:RefreshDisplay()
    self:FireEvent("INTERRUPT_TEAMS_UPDATED")
end

-- Add a player to a team
function InterruptTeams:AddPlayerToTeam(markerIndex, playerName)
    -- Validate input parameters
    if type(markerIndex) ~= "number" or markerIndex < 1 or markerIndex > 8 then
        print("ERROR: Invalid markerIndex:", markerIndex)
        return false
    end

    if type(playerName) ~= "string" or playerName == "" then
        print("ERROR: Invalid playerName:", playerName)
        return false
    end

    if not addon.Config or not addon.Config.db then
        return false
    end
    local teams = addon.Config.db.interruptTeams
    if not teams then
        addon.Config.db.interruptTeams = {}
        teams = addon.Config.db.interruptTeams
    end

    if not teams[markerIndex] then
        teams[markerIndex] = {}
    end

    -- Ensure teams[markerIndex] is an array
    if type(teams[markerIndex]) ~= "table" then
        teams[markerIndex] = {}
    end

    -- Check if player is already in the team
    for _, name in ipairs(teams[markerIndex]) do
        if name == playerName then
            return false  -- Already in team
        end
    end

    table.insert(teams[markerIndex], playerName)
    addon.Config:FireEvent("CONFIG_CHANGED")

    -- Fire display update event
    self:RefreshDisplay()

    -- Also refresh the config tab if it's currently active and showing interrupt teams
    if addon.UI and addon.UI.activeConfigTab == "interruptteams" and addon.InterruptTeamsTabModule then
        addon.InterruptTeamsTabModule.refreshTab()
    end

    return true
end

-- Remove a player from a team
function InterruptTeams:RemovePlayerFromTeam(markerIndex, playerName)
    if not addon.Config or not addon.Config.db then
        return false
    end

    local teams = addon.Config.db.interruptTeams
    if not teams[markerIndex] then
        return false
    end

    for i, name in ipairs(teams[markerIndex]) do
        if name == playerName then
            table.remove(teams[markerIndex], i)
            addon.Config:FireEvent("CONFIG_CHANGED")

            -- Fire display update event
            self:RefreshDisplay()

            -- Also refresh the config tab if it's currently active and showing interrupt teams
            if addon.UI and addon.UI.activeConfigTab == "interruptteams" and addon.InterruptTeamsTabModule then
                addon.InterruptTeamsTabModule.refreshTab()
            end

            return true
        end
    end

    return false
end

-- Handle config changes
function InterruptTeams:OnConfigChanged()
    -- Refresh any cached data when config changes
    self:RefreshPlayerList()

    -- Update display when config changes
    self:RefreshDisplay()
end

-- Get all available group members for team assignment
function InterruptTeams:GetAvailableGroupMembers()
    local members = {}

    if not IsInGroup() then
        -- Solo play - just return player
        local playerName = UnitName("player")
        if playerName then
            table.insert(members, playerName)
        end
        return members
    end

    -- Get group members
    for i = 1, GetNumGroupMembers() do
        local unit
        if IsInRaid() then
            unit = "raid" .. i
        else
            -- In party: i=1 is player, i=2 is party1, i=3 is party2, etc.
            if i == 1 then
                unit = "player"
            else
                unit = "party" .. (i - 1)
            end
        end

        local name = UnitName(unit)
        if name then
            -- Include all group members (they might switch specs/talents)
            table.insert(members, name)
        end
    end

    return members
end

-- Debug function to print current team assignments
function InterruptTeams:PrintTeams()
    if not addon.Config or not addon.Config.db then
        print("CCR: No config available")
        return
    end

    local teams = addon.Config.db.interruptTeams
    print("CCR: Interrupt Teams:")

    for markerIndex = 1, 8 do
        local markerName = RAID_TARGET_MARKERS[markerIndex]
        local team = teams[markerIndex] or {}

        if #team > 0 then
            local playerList = table.concat(team, ", ")
            print(string.format("  %s (%d): %s", markerName, markerIndex, playerList))
        else
            print(string.format("  %s (%d): No team assigned", markerName, markerIndex))
        end
    end
end