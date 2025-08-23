local addonName, addon = ...

-- Main addon object
addon.CCRotation = {}
local CCRotation = addon.CCRotation

local cooldownTracker = nil

-- Event system for decoupled communication
CCRotation.eventListeners = {}

-- Register event listener
function CCRotation:RegisterEventListener(event, callback)
    if not self.eventListeners[event] then
        self.eventListeners[event] = {}
    end
    table.insert(self.eventListeners[event], callback)
end

-- Fire event to all listeners
function CCRotation:FireEvent(event, ...)
    if self.eventListeners[event] then
        for _, callback in ipairs(self.eventListeners[event]) do
            callback(...)
        end
    end
end

-- Initialize core variables
function CCRotation:Initialize()
    -- Build NPC effectiveness map from database
    self.npcEffectiveness = addon.Database:BuildNPCEffectiveness()
    
    -- Get tracked spells from config
    self.trackedCooldowns = addon.Config:GetTrackedSpells()
    if self:CountKeys(self.trackedCooldowns) > 0 then
        local count = 0
        for spellID, info in pairs(self.trackedCooldowns) do
            print("  -", spellID, info.name)
            count = count + 1
            if count >= 3 then break end
        end
    end
    
    -- Initialize tracking variables
    self.cooldownQueue = {}
    self.spellCooldowns = {}  -- Individual spell tracking
    self.GUIDToUnit = {}
    self.activeNPCs = {}
    self.wasPlayerNext = false  -- Track player turn state for notifications
    self.lastAnnouncedSpell = nil  -- Track last announced spell to prevent spam
    self.lastAnnouncementTime = 0  -- Track when we last made an announcement
    
    -- Initialize GUID mapping
    self:RefreshGUIDToUnit()
    
    cooldownTracker = addon.CooldownTracker
    cooldownTracker:Initialize()
    self:RegisterCooldownCallbacks()
    
    -- Register for events
    self:RegisterEvents()
    
    -- Schedule delayed queue rebuild to ensure cooldown data is available
    C_Timer.After(1, function()
        self:RebuildQueue()
    end)
end

-- Function to rebuild GUID mapping
function CCRotation:RefreshGUIDToUnit()
    self.GUIDToUnit = {}
    
    -- Always include yourself
    local myGUID = UnitGUID("player")
    if myGUID then
        self.GUIDToUnit[myGUID] = "player"
    end
    
    -- Then map everyone in your group/raid
    if IsInGroup() then
        local numGroupMembers = GetNumGroupMembers()
        local prefix = IsInRaid() and "raid" or "party"
        
        for i = 1, numGroupMembers do
            local unit = prefix .. i
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    self.GUIDToUnit[guid] = unit
                end
            end
        end
    end
end

-- Register callbacks
function CCRotation:RegisterCooldownCallbacks()
    cooldownTracker:RegisterEventListener("COOLDOWN_STARTED", function(...)
        self:OnCooldownUpdate(...)
    end)
    cooldownTracker:RegisterEventListener("GROUP_UPDATED", function(...)
        self:OnGroupUpdate(...)
    end)
    cooldownTracker:RegisterEventListener("PLAYER_INSPECTED", function(...)
        self:OnTalentUpdate(...)
    end)
end

-- Register for WoW events
function CCRotation:RegisterEvents()
    local frame = CreateFrame("Frame")
    self.eventFrame = frame
    
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHALLENGE_MODE_START")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("PLAYER_ALIVE")
    frame:RegisterEvent("PLAYER_UNGHOST")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        CCRotation:OnEvent(event, ...)
    end)
end

-- Event handler
function CCRotation:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "CHALLENGE_MODE_START" then
        self:RebuildQueue()
        -- Fire location change event for UI components
        self:FireEvent("LOCATION_CHANGED")
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Delay operations to avoid taint issues with Blizzard frames
        C_Timer.After(0.1, function()
            self:RefreshGUIDToUnit()
            self:RebuildQueue()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:OnCombatEnd()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        self:OnNameplateAdded(unit)
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        -- Player has been resurrected, immediately rebuild queue to move abilities back to available
        self:RebuildQueue()
    elseif event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE" then
        -- Player changed talents, refresh tracked spells after a brief delay
        C_Timer.After(0.5, function()
            self:OnTalentUpdate()
        end)
    end
end

-- Handle CooldownTracker cooldown updates
function CCRotation:OnCooldownUpdate(...)
    local spellID, srcGUID, expirationTime, duration = ...
    
    addon.DebugSystem.Print("OnCooldownUpdate called - spell " .. spellID .. " expires at " .. expirationTime, "RotationCore")
    
    -- Extra debug for Intimidating Roar
    if spellID == 99 then
        local inCombat = InCombatLockdown() and "IN COMBAT" or "OUT OF COMBAT"
        addon.DebugSystem.Print("*** ROAR COOLDOWN UPDATE - triggering immediate queue rebuild [" .. inCombat .. "] ***", "RotationCore")
    end

    -- Schedule queue rebuild for when this cooldown expires
    self:ScheduleCooldownExpiration(spellID, expirationTime)
    
    -- Rebuild queue immediately to reflect new cooldown state
    self:RebuildQueue()
end

-- Handle group composition updates
function CCRotation:OnGroupUpdate(...)
    -- Refresh GUID mapping and rebuild queue
    self:RefreshGUIDToUnit()
    self:RebuildQueue()
end

-- Handle talent/inspection updates
function CCRotation:OnTalentUpdate(...)
    -- Add delay to allow CooldownTracker to rebuild first
    C_Timer.After(1.0, function()
        -- Clear spell cooldowns to force talent-based filtering
        self:ClearStaleSpellCooldowns()
        
        -- Refresh tracked cooldowns and rebuild queue
        self.trackedCooldowns = addon.Config:GetTrackedSpells()
        self:RebuildQueue()
    end)
end

-- Clear spell cooldowns that are no longer available due to talent changes
function CCRotation:ClearStaleSpellCooldowns()
    local cooldownTracker = addon.CooldownTracker
    if not (cooldownTracker and cooldownTracker.groupInfo) then return end
    
    -- Check each spell cooldown against current talent availability
    for key, spellData in pairs(self.spellCooldowns) do
        local GUID = spellData.GUID
        local spellID = spellData.spellID
        
        local playerInfo = cooldownTracker.groupInfo[GUID]
        if playerInfo and playerInfo.availableSpells then
            -- If player doesn't have this spell available, remove it
            if not playerInfo.availableSpells[spellID] then
                self.spellCooldowns[key] = nil
            end
        end
    end
end

-- Public method for UI to notify of configuration changes
function CCRotation:NotifyConfigChanged()

    -- Cancel any previous config update timer
    if self._configUpdateTimer then
        self._configUpdateTimer:Cancel()
        self._configUpdateTimer = nil
    end
    
    -- Schedule a debounced config update after rapid changes settle
    self._configUpdateTimer = C_Timer.After(0.5, function()
        self._configUpdateTimer = nil
        -- Refresh tracked cooldowns and rebuild queue
        self.trackedCooldowns = addon.Config:GetTrackedSpells()
        self:RebuildQueue()
    end)
end

-- Extract NPC ID from a unit GUID
function CCRotation:GetNPCIDFromGUID(guid)
    if not guid then return end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

-- Helper function to count keys in a table
function CCRotation:CountKeys(tbl)
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Update individual spell cooldown data
function CCRotation:UpdateSpellCooldown(unit, spellID, cooldownInfo)
    if not (unit and spellID and cooldownInfo) then 
        return
    end
    
    -- Get spell info from CooldownTracker's database instead of config
    local spellInfo = addon.Database.defaultSpells[spellID]
    if not spellInfo then
        return
    end
    
    local GUID = UnitGUID(unit)
    if not GUID then return end
    
    -- Check if the player actually has this spell available (talent check)
    local cooldownTracker = addon.CooldownTracker
    if cooldownTracker and cooldownTracker.groupInfo and cooldownTracker.groupInfo[GUID] then
        local playerInfo = cooldownTracker.groupInfo[GUID]
        if playerInfo.availableSpells then
            local hasSpell = playerInfo.availableSpells[spellID]
            addon.DebugSystem.Print(string.format("UpdateSpellCooldown - spell %d talent check: hasSpell=%s", spellID, tostring(hasSpell)), "RotationCore")
            
            if not hasSpell then
                -- Player doesn't have this spell due to talents/spec, remove from queue if it exists
                local key = GUID .. ":" .. spellID
                if self.spellCooldowns[key] then
                    addon.DebugSystem.Print(string.format("UpdateSpellCooldown - removing untalented spell %d from queue", spellID), "RotationCore")
                    self.spellCooldowns[key] = nil
                    return true -- Signal that something changed so queue gets rebuilt
                end
                return false
            end
        end
    end
    
    local _, _, timeLeft, charges, _, _, _, duration = cooldownTracker:GetCooldownStatusFromCooldownInfo(cooldownInfo)
    local currentTime = GetTime()
    
    -- Create unique key for this spell/player combination
    local key = GUID .. ":" .. spellID
    
    -- Check if this is actually a significant update to avoid unnecessary refreshes
    local existingData = self.spellCooldowns[key]
    local newExpirationTime = timeLeft + currentTime
    
    addon.DebugSystem.Print(string.format("UpdateSpellCooldown - spell %d: timeLeft=%.1f newExp=%.1f existingExp=%.1f charges=%d", 
        spellID, timeLeft, newExpirationTime, existingData and existingData.expirationTime or 0, charges), "RotationCore")
    
    -- Check if readiness state changed (from on cooldown to ready or vice versa)
    -- More direct approach: check if timeLeft changed from >0 to 0 or vice versa
    local wasOnCooldown = existingData and (existingData.expirationTime > existingData.lastUpdate)
    local isOnCooldown = (timeLeft > 0)
    local readinessChanged = wasOnCooldown ~= isOnCooldown

    -- Only update if this is a new spell, readiness state changed, cooldown changed significantly (more than 0.2 seconds), or charges changed
    if not existingData or 
       readinessChanged or
       math.abs(existingData.expirationTime - newExpirationTime) > 0.2 or
       (existingData.charges or 0) ~= charges then
        
        self.spellCooldowns[key] = {
            GUID = GUID,
            spellID = spellID,
            priority = spellInfo.priority or 5,
            expirationTime = newExpirationTime,
            duration = duration,
            charges = charges,
            lastUpdate = currentTime,
            -- Preserve isEffective if it was previously set, will be recalculated in RecalculateQueue
            isEffective = existingData and existingData.isEffective
        }
        return true
    end
    
    return false -- No significant change
end

-- Debounced queue rebuild
function CCRotation:RebuildQueue()
    -- Cancel any previous scheduled rebuild
    if self._rebuildTimer then
        self._rebuildTimer:Cancel()
        self._rebuildTimer = nil
    end
    
    -- During combat, rebuild immediately for better responsiveness
    if InCombatLockdown() then
        addon.DebugSystem.Print("In combat - executing immediate queue rebuild", "RotationCore")
        self:DoRebuildQueue()
    else
        addon.DebugSystem.Print("Scheduling queue rebuild in 0.1s", "RotationCore")
        -- Schedule a new rebuild after a short delay
        self._rebuildTimer = C_Timer.After(0.1, function()
            addon.DebugSystem.Print("Executing scheduled queue rebuild", "RotationCore")
            self._rebuildTimer = nil
            self:DoRebuildQueue()
        end)
    end
end

-- Schedule queue rebuild for when specific cooldowns expire
function CCRotation:ScheduleCooldownExpiration(spellID, expirationTime)
    local now = GetTime()
    local delay = expirationTime - now
    
    if delay > 0 then
        C_Timer.After(delay, function()
            self:RebuildQueue()
        end)
    end
end

-- Cancel old periodic updates
function CCRotation:StopPeriodicUpdates()
    if self._periodicTimer then
        self._periodicTimer:Cancel()
        self._periodicTimer = nil
    end
end

-- Actual queue rebuild implementation
function CCRotation:DoRebuildQueue()
    -- Store old GUID mapping to detect group changes
    local oldGUIDToUnit = {}
    for guid, unit in pairs(self.GUIDToUnit) do
        oldGUIDToUnit[guid] = unit
    end
    
    -- Refresh GUID→unit mapping
    self:RefreshGUIDToUnit()
    
    -- Check if group composition changed
    local groupChanged = false
    
    -- Check for added/removed players
    for guid, unit in pairs(self.GUIDToUnit) do
        if not oldGUIDToUnit[guid] then
            groupChanged = true
            break
        end
    end
    
    if not groupChanged then
        for guid, unit in pairs(oldGUIDToUnit) do
            if not self.GUIDToUnit[guid] then
                groupChanged = true
                break
            end
        end
    end
    
    -- Track if any cooldowns actually changed
    local hasChanges = false
    
    -- Update individual spell cooldowns without affecting others
    local allCooldowns = cooldownTracker:GetAllCooldowns()
    if allCooldowns then
        for guid, cds in pairs(allCooldowns) do
            -- Convert GUID back to unit for compatibility
            local unit = self.GUIDToUnit[guid]
            
            if unit then
                for spellID, info in pairs(cds) do
                    if self.trackedCooldowns[spellID] then
                        if self:UpdateSpellCooldown(unit, spellID, info) then
                            hasChanges = true
                        end
                    end
                end
            end
        end
    end
    
    -- Clean up stale cooldown data if group composition changed
    if groupChanged then
        self:CleanupStaleSpellCooldowns()
    end
    
    -- Also clean up untalented spells for all players
    self:CleanupUntalonedSpells()
    
    -- Recalculate if there were cooldown changes OR group composition changed
    if hasChanges or groupChanged then
        self:RecalculateQueue()
    end
end

-- Clean up spell cooldown data for players no longer in group
function CCRotation:CleanupStaleSpellCooldowns()
    for key, spellData in pairs(self.spellCooldowns) do
        local guid = spellData.GUID
        if not self.GUIDToUnit[guid] then
            -- This GUID is no longer in our group, remove its cooldown data
            self.spellCooldowns[key] = nil
        end
    end
end

-- Clean up spells that players no longer have due to talent changes
function CCRotation:CleanupUntalonedSpells()
    local cooldownTracker = addon.CooldownTracker
    if not (cooldownTracker and cooldownTracker.groupInfo) then
        return
    end
    
    for key, spellData in pairs(self.spellCooldowns) do
        local guid = spellData.GUID
        local spellID = spellData.spellID
        
        -- Check if this player still has this spell available
        local playerInfo = cooldownTracker.groupInfo[guid]
        if playerInfo and playerInfo.availableSpells then
            if not playerInfo.availableSpells[spellID] then
                addon.DebugSystem.Print(string.format("CleanupUntalonedSpells - removing spell %d for player %s", spellID, guid), "RotationCore")
                self.spellCooldowns[key] = nil
            end
        end
    end
    
    -- Handle hero talent exclusions (enhanced spells replace base spells)
    self:CleanupHeroTalentConflicts()
end

-- Clean up base spells when enhanced versions are available (hero talents)
function CCRotation:CleanupHeroTalentConflicts()
    local cooldownTracker = addon.CooldownTracker
    if not (cooldownTracker and cooldownTracker.groupInfo) then
        addon.DebugSystem.Print("CleanupHeroTalentConflicts - no cooldownTracker or groupInfo", "RotationCore")
        return
    end
    
    -- Define hero talent exclusions: if enhanced spell is available, remove base spell
    local heroTalentExclusions = {
        [449700] = 157980,  -- If Gravity Lapse (449700) is available, remove Supernova (157980)
    }
    
    addon.DebugSystem.Print("CleanupHeroTalentConflicts - checking hero talent conflicts", "RotationCore")
    
    for enhancedSpellID, baseSpellID in pairs(heroTalentExclusions) do
        addon.DebugSystem.Print(string.format("Checking exclusion: enhanced=%d base=%d", enhancedSpellID, baseSpellID), "RotationCore")
        
        for guid, playerInfo in pairs(cooldownTracker.groupInfo) do
            if playerInfo.availableSpells then
                local hasEnhanced = playerInfo.availableSpells[enhancedSpellID]
                local hasBase = playerInfo.availableSpells[baseSpellID]
                local playerName = playerInfo.name or "Unknown"
                
                addon.DebugSystem.Print(string.format("Player %s: hasEnhanced(%d)=%s hasBase(%d)=%s", 
                    playerName, enhancedSpellID, tostring(hasEnhanced), baseSpellID, tostring(hasBase)), "RotationCore")
                
                -- If player has both enhanced and base spell, remove the base spell
                if hasEnhanced and hasBase then
                    local baseKey = guid .. ":" .. baseSpellID
                    if self.spellCooldowns[baseKey] then
                        addon.DebugSystem.Print(string.format("CleanupHeroTalentConflicts - removing base spell %d for %s, enhanced spell %d available", baseSpellID, playerName, enhancedSpellID), "RotationCore")
                        self.spellCooldowns[baseKey] = nil
                    else
                        addon.DebugSystem.Print(string.format("CleanupHeroTalentConflicts - base spell %d not in spellCooldowns for %s", baseSpellID, playerName), "RotationCore")
                    end
                elseif hasEnhanced then
                    addon.DebugSystem.Print(string.format("Player %s has enhanced spell %d but not base spell %d", playerName, enhancedSpellID, baseSpellID), "RotationCore")
                elseif hasBase then
                    addon.DebugSystem.Print(string.format("Player %s has base spell %d but not enhanced spell %d", playerName, baseSpellID, enhancedSpellID), "RotationCore")
                end
            end
        end
    end
end

-- Recalculate queue order from individual spell cooldowns
function CCRotation:RecalculateQueue()
    self.cooldownQueue = {}
    
    -- Convert spell cooldowns to queue format
    for key, spellData in pairs(self.spellCooldowns) do
        -- Ensure isEffective defaults to true if not set (will be recalculated below)
        if spellData.isEffective == nil then
            spellData.isEffective = true
        end
        table.insert(self.cooldownQueue, spellData)
    end

    -- Determine if we have any known NPCs and handle filtering/effectiveness
    local hasKnownNPCs = false
    local hasUnknownNPCs = false
    
    for npcID in pairs(self.activeNPCs) do
        local effectiveness = addon.Config:GetNPCEffectiveness(npcID)
        if effectiveness then
            hasKnownNPCs = true
        else
            hasUnknownNPCs = true
        end
    end
    
    -- Filter by active NPCs if we have known NPCs (standard behavior)
    if hasKnownNPCs then
        local filtered = {}
        for _, cd in ipairs(self.cooldownQueue) do
            local spellInfo = addon.Database.defaultSpells[cd.spellID]
            local ccType = spellInfo and spellInfo.ccType
            
            if not ccType then
                -- Uncategorized spells always show
                filtered[#filtered+1] = cd
                cd.isEffective = true
            else
                -- Only keep if ANY known NPC accepts this CC type
                local isEffective = false
                for npcID in pairs(self.activeNPCs) do
                    local effectiveness = addon.Config:GetNPCEffectiveness(npcID)
                    if effectiveness and effectiveness[ccType] then
                        isEffective = true
                        break
                    end
                end
                if isEffective then
                    filtered[#filtered+1] = cd
                    cd.isEffective = true
                end
            end
        end
        self.cooldownQueue = filtered
    else
        -- No known NPCs - mark all as ineffective if we have unknown NPCs
        for _, cd in ipairs(self.cooldownQueue) do
            cd.isEffective = not hasUnknownNPCs
        end
    end
    
    -- Sort and separate queues
    self:SortAndSeparateQueues()

    -- Always fire UI update events - cooldown states matter even if queue order is the same
    self:FireEvent("QUEUE_UPDATED", self.cooldownQueue, self.unavailableQueue)
    
    -- Check if secondary queue should be shown (first ability on cooldown)
    local shouldShowSecondary = self:ShouldShowSecondaryQueue()
    self:FireEvent("SECONDARY_QUEUE_STATE_CHANGED", shouldShowSecondary)
    
    -- Still save queue state for potential optimizations elsewhere
    self:SaveCurrentQueue()
end

-- Sort the cooldown queue and separate available from unavailable
function CCRotation:SortAndSeparateQueues()
    local now = GetTime()
    local availableQueue = {}
    local unavailableQueue = {}
    
    -- Add status information and separate into available/unavailable
    for _, cooldownData in ipairs(self.cooldownQueue) do
        local unit = self.GUIDToUnit[cooldownData.GUID]
        if unit then
            cooldownData.isDead = UnitIsDeadOrGhost(unit)
            
            -- Special case: when not in a group, treat yourself as always in range
            if unit == "player" and not IsInGroup() then
                cooldownData.inRange = true
            elseif IsInGroup() and UnitExists(unit) then
                cooldownData.inRange = UnitInRange(unit)
            else
                -- Not in group or unit doesn't exist - treat as out of range
                cooldownData.inRange = false
            end
            
            if cooldownData.isDead or not cooldownData.inRange then
                table.insert(unavailableQueue, cooldownData)
            else
                table.insert(availableQueue, cooldownData)
            end
        end
    end
    
    -- Sort available queue
    local success = pcall(function()
        table.sort(availableQueue, function(a, b)
            local unitA, unitB = self.GUIDToUnit[a.GUID], self.GUIDToUnit[b.GUID]
            if not (unitA and unitB) then return false end
            
            local nameA, nameB = UnitName(unitA), UnitName(unitB)
            local isPriorityA = addon.Config:IsPriorityPlayer(nameA)
            local isPriorityB = addon.Config:IsPriorityPlayer(nameB)
            
            -- Safe readiness calculation - handle potential nil values
            local readyA = (a.charges and a.charges > 0) and (not a.expirationTime or a.expirationTime <= now)
            local readyB = (b.charges and b.charges > 0) and (not b.expirationTime or b.expirationTime <= now)

            -- 1. Ready spells first
            if readyA ~= readyB then 
                return readyA
            end
            
            -- 2. Among ready spells, prioritize priority players
            if readyA and readyB and (isPriorityA ~= isPriorityB) then
                return isPriorityA
            end
            
            -- 3. Finally, fallback on configured priority (or soonest available cooldown)
            if readyA then
                return (a.priority or 0) < (b.priority or 0)
            else
                return (a.expirationTime or 0) < (b.expirationTime or 0)
            end
        end)
    end)
    
    if not success then
        return -- Exit early if sorting fails
    end
    
    -- Sort unavailable queue by what their priority WOULD be if available
    local success2 = pcall(function()
        table.sort(unavailableQueue, function(a, b)
            local unitA, unitB = self.GUIDToUnit[a.GUID], self.GUIDToUnit[b.GUID]
            if not (unitA and unitB) then return false end
            
            local nameA, nameB = UnitName(unitA), UnitName(unitB)
            local isPriorityA = addon.Config:IsPriorityPlayer(nameA)
            local isPriorityB = addon.Config:IsPriorityPlayer(nameB)
            
            -- Safe readiness calculation - handle potential nil values  
            local readyA = (a.charges and a.charges > 0) or (not a.expirationTime or a.expirationTime <= now)
            local readyB = (b.charges and b.charges > 0) or (not b.expirationTime or b.expirationTime <= now)
            
            -- Same sorting as available queue to show proper priority
            if readyA ~= readyB then return readyA end
            if readyA and readyB and (isPriorityA ~= isPriorityB) then
                return isPriorityA
            end
            if readyA then
                return (a.priority or 0) < (b.priority or 0)
            else
                return (a.expirationTime or 0) < (b.expirationTime or 0)
            end
        end)
    end)
    
    if not success2 then
        return -- Exit early if sorting fails
    end
    
    -- Update the main queue and store unavailable queue
    self.cooldownQueue = availableQueue
    self.unavailableQueue = unavailableQueue
    
    -- Check for pug announcements
    self:CheckPugAnnouncement()
    
    -- Check if player is next in queue and fire event for sound notification
    self:CheckPlayerTurnStatus()
    
end

-- Check if player is next in queue and fire notification event
function CCRotation:CheckPlayerTurnStatus()
    local config = addon.Config
    if not config:Get("enableTurnNotification") then
        self.wasPlayerNext = false
        return
    end
    
    
    -- Check if there are any active enabled NPCs
    local hasActiveEnabledNPCs = self:HasActiveEnabledNPCs()
    if not hasActiveEnabledNPCs then
        self.wasPlayerNext = false
        return
    end
    
    local isPlayerNext = false
    
    -- Check if player is first in available queue
    if #self.cooldownQueue > 0 then
        local firstInQueue = self.cooldownQueue[1]
        local unit = self.GUIDToUnit[firstInQueue.GUID]
        
        if unit and UnitIsUnit(unit, "player") and firstInQueue.isEffective then
            -- Check combat restrictions if enabled
            if not config:Get("glowOnlyInCombat") or InCombatLockdown() then
                isPlayerNext = true
            end
        end
    end
    
    -- Only fire event if player just became next (wasn't next before)
    if isPlayerNext and not self.wasPlayerNext then
        self:FireEvent("PLAYER_TURN_NEXT", self.cooldownQueue[1])
    end
    
    self.wasPlayerNext = isPlayerNext
end

-- Check if we need to announce the next ability for a pug
function CCRotation:CheckPugAnnouncement()
    local config = addon.Config
    if not config:Get("pugAnnouncerEnabled") then
        return
    end
    
    -- Only leaders can announce
    if not UnitIsGroupLeader("player") then
        return
    end
    
    -- Only announce in combat (when we need CC)
    if not InCombatLockdown() then
        self.lastAnnouncedSpell = nil
        return
    end
    
    -- Check if there are any active enabled NPCs
    local hasActiveEnabledNPCs = self:HasActiveEnabledNPCs()
    if not hasActiveEnabledNPCs then
        self.lastAnnouncedSpell = nil
        return
    end
    
    -- Check if first person in queue is a pug and their spell is ready
    if #self.cooldownQueue > 0 then
        local firstInQueue = self.cooldownQueue[1]
        local unit = self.GUIDToUnit[firstInQueue.GUID]
        
        if unit and firstInQueue.isEffective then
            local playerName = UnitName(unit)
            
            -- Check if this player is a pug
            if addon.PartySync:IsPlayerPug(playerName) then
                -- Check if spell is ready (has charges or cooldown is up)
                local now = GetTime()
                local isReady = firstInQueue.charges > 0 or firstInQueue.expirationTime <= now
                
                if isReady then
                    -- Get spell name from database since it's not stored in queue data
                    local spellInfo = addon.Database.defaultSpells[firstInQueue.spellID]
                    local spellName = spellInfo and spellInfo.name or ("Spell " .. tostring(firstInQueue.spellID))
                    local announceKey = playerName .. ":" .. spellName
                    
                    -- Throttle announcements: minimum 5 seconds between announcements
                    -- and don't repeat the same player+spell combo
                    if self.lastAnnouncedSpell ~= announceKey and (now - self.lastAnnouncementTime) >= 5 then
                        self.lastAnnouncedSpell = announceKey
                        self.lastAnnouncementTime = now
                        
                        local channel = config:Get("pugAnnouncerChannel") or "SAY"
                        local message = spellName .. " next"
                        
                        -- Send the announcement
                        SendChatMessage(message, channel)
                    end
                end
            else
                -- First person isn't a pug, clear announcement tracking
                self.lastAnnouncedSpell = nil
            end
        end
    else
        -- No one in queue, clear announcement tracking
        self.lastAnnouncedSpell = nil
    end
end

-- Combat start handler
function CCRotation:OnCombatStart()
    -- Reset active NPCs
    wipe(self.activeNPCs)
    
    -- Start scanning for nameplates
    self:ScanNameplates()
    
    -- Schedule quick scan
    self.quickScan = C_Timer.After(0.3, function()
        self:ScanNameplates()
    end)
    
    -- Cancel non-combat timer if running
    if self.nonCombatTicker then
        self.nonCombatTicker:Cancel()
        self.nonCombatTicker = nil
    end
    
    -- Start periodic scanning every second
    if self.scanTicker then self.scanTicker:Cancel() end
    self.scanTicker = C_Timer.NewTicker(1, function()
        self:ScanNameplates()
        -- Rebuild queue (will only update UI if queue actually changed)
        self:RebuildQueue()
    end)
end

-- Combat end handler
function CCRotation:OnCombatEnd()
    -- Stop combat timers
    if self.scanTicker then
        self.scanTicker:Cancel()
        self.scanTicker = nil
    end
    if self.quickScan then
        self.quickScan:Cancel()
        self.quickScan = nil
    end
    
    -- Clear active NPCs when combat ends
    wipe(self.activeNPCs)
    
    -- Start non-combat periodic queue rebuild every 3 seconds
    if self.nonCombatTicker then self.nonCombatTicker:Cancel() end
    self.nonCombatTicker = C_Timer.NewTicker(3, function()
        self:RebuildQueue()
    end)
end

-- Nameplate added handler
function CCRotation:OnNameplateAdded(unit)
    if UnitAffectingCombat(unit) and UnitIsEnemy("player", unit) then
        local guid = UnitGUID(unit)
        local npcID = self:GetNPCIDFromGUID(guid)
        if npcID then
            self.activeNPCs[npcID] = true
            -- Trigger queue rebuild
            self:RebuildQueue()
        end
    end
end

-- Scan for active nameplates
function CCRotation:ScanNameplates()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.UnitFrame.unit
        if UnitAffectingCombat(unit) and UnitIsEnemy("player", unit) then
            local guid = UnitGUID(unit)
            local npcID = self:GetNPCIDFromGUID(guid)
            if npcID then
                self.activeNPCs[npcID] = true
            end
        end
    end
end

-- Get the current queue for display
function CCRotation:GetQueue()
    return self.cooldownQueue
end

-- Check if there are any active enabled NPCs
function CCRotation:HasActiveEnabledNPCs()
    if not self.activeNPCs then
        return false
    end
    
    for npcID in pairs(self.activeNPCs) do
        local effectiveness
        local usingDataProvider = false
        
        -- Check disabled state first
        if addon.Config.db.inactiveNPCs[npcID] then
            effectiveness = nil
        else
            effectiveness = addon.Config:GetNPCEffectiveness(npcID)
        end
        
        
        if effectiveness then
            return true
        end
    end
    
    return false
end

-- Check if the queue has actually changed since last update
function CCRotation:HasQueueChanged()
    if not self.lastQueue then
        self.lastQueue = {}
        return true
    end
    
    -- Quick length check
    if #self.cooldownQueue ~= #self.lastQueue then
        self:SaveCurrentQueue()
        return true
    end
    
    -- Check if any items changed (with improved comparison)
    local now = GetTime()
    local hasSignificantChange = false
    
    for i, cd in ipairs(self.cooldownQueue) do
        local last = self.lastQueue[i]
        if not last then
            hasSignificantChange = true
            break
        end
        
        -- Check for GUID or spell changes (always significant)
        if cd.GUID ~= last.GUID or cd.spellID ~= last.spellID then
            hasSignificantChange = true
            break
        end
        
        -- Check cooldown time changes (only if > 1 second difference)
        if math.abs(cd.expirationTime - last.expirationTime) > 1.0 then
            hasSignificantChange = true
            break
        end
        
        -- Check if ability state changed (ready -> not ready or vice versa)
        local wasReady = (last.charges or 0) > 0 or last.expirationTime <= (last.checkTime or now)
        local isReady = (cd.charges or 0) > 0 or cd.expirationTime <= now
        
        
        if wasReady ~= isReady then
            hasSignificantChange = true
            break
        end
    end
    
    if hasSignificantChange then
        self:SaveCurrentQueue()
        return true
    end
    
    return false
end

-- Save current queue state for comparison
function CCRotation:SaveCurrentQueue()
    local now = GetTime()
    self.lastQueue = {}
    for i, cd in ipairs(self.cooldownQueue) do
        self.lastQueue[i] = {
            GUID = cd.GUID,
            spellID = cd.spellID,
            expirationTime = cd.expirationTime,
            charges = cd.charges,
            checkTime = now
        }
    end
end

-- Check if secondary queue should be shown (first ability on cooldown)
function CCRotation:ShouldShowSecondaryQueue()
    if not self.cooldownQueue or #self.cooldownQueue == 0 then
        return false
    end
    
    local now = GetTime()
    local firstAbility = self.cooldownQueue[1]
    if firstAbility then
        local charges = firstAbility.charges or 0
        local isReady = charges > 0 or (firstAbility.expirationTime and firstAbility.expirationTime <= now)
        
        if addon.Config:Get("debugMode") then
            local spellInfo = C_Spell.GetSpellInfo(firstAbility.spellID)
            local spellName = spellInfo and spellInfo.name or "Unknown"
        end
        
        return not isReady -- Show secondary if first ability is NOT ready
    end
    
    return false
end

-- Check if addon should be active
function CCRotation:ShouldBeActive()
    local config = addon.Config
    
    if not config:Get("enabled") then
        return false
    end
    
    if not config:Get("showInSolo") and not IsInGroup() then
        return false
    end
    
    -- Check if "Only enable in dungeons" is enabled
    if config:Get("onlyInDungeons") then
        local inInstance, instanceType = IsInInstance()
        if not inInstance or instanceType ~= "party" then
            return false
        end
    end
    
    return true
end
