local addonName, addon = ...

-- Main addon object
addon.CCRotation = {}
local CCRotation = addon.CCRotation

-- LibOpenRaid reference
local lib = LibStub("LibOpenRaid-1.0", true)

-- Use unified event system instead of local one
function CCRotation:RegisterEventListener(event, callback)
    addon.EventSystem:RegisterEventListener(event, callback)
end

function CCRotation:FireEvent(event, ...)
    addon.EventSystem:FireEvent(event, ...)
end

-- Initialize core variables
function CCRotation:Initialize()
    -- Get tracked spells from config
    self.trackedCooldowns = addon.Config:GetTrackedSpells()
    
    -- Initialize tracking variables
    self.cooldownQueue = {}
    self.spellCooldowns = {}  -- Individual spell tracking
    self.GUIDToUnit = {}
    self.wasPlayerNext = false  -- Track player turn state for notifications
    self.lastAnnouncedSpell = nil  -- Track last announced spell to prevent spam
    self.lastAnnouncementTime = 0  -- Track when we last made an announcement
    
    -- Initialize GUID mapping
    self:RefreshGUIDToUnit()
    
    -- Initialize CastTracker
    if addon.CastTracker then
        addon.CastTracker:Initialize()
    end
    
    -- Register LibOpenRaid callbacks if library is available
    if lib then
        self:RegisterLibOpenRaidCallbacks()
    end
    
    -- Register for events
    self:RegisterEvents()
    
    -- Register for cast tracker events
    self:RegisterEventListener("DANGEROUS_CAST_STARTED", function(castInfo)
        self:OnDangerousCastStarted(castInfo)
    end)
    
    self:RegisterEventListener("DANGEROUS_CAST_STOPPED", function(castInfo)
        self:OnDangerousCastStopped(castInfo)
    end)
    
    -- Schedule delayed queue rebuild to ensure LibOpenRaid has data
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

-- Register LibOpenRaid callbacks
function CCRotation:RegisterLibOpenRaidCallbacks()
    if not lib then return end
    
    local callbacks = {
        CooldownUpdate = function(...)
            self:OnCooldownUpdate(...)
        end,
        TalentUpdate = function(...)
            self:OnTalentUpdate(...)
        end,
    }
    
    lib.RegisterCallback(callbacks, "CooldownUpdate", "CooldownUpdate")
    lib.RegisterCallback(callbacks, "TalentUpdate", "TalentUpdate")
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

-- Handle LibOpenRaid cooldown updates
function CCRotation:OnCooldownUpdate(...)
    -- Only rebuild queue, it will handle UI updates if needed
    self:RebuildQueue()
end

-- Handle LibOpenRaid talent updates
function CCRotation:OnTalentUpdate(...)
    -- Refresh our tracked cooldowns list
    self.trackedCooldowns = addon.Config:GetTrackedSpells()
    
    -- Clear cached cooldown data and rebuild queue
    self.spellCooldowns = {}
    self:RebuildQueue()
end

-- Extract NPC ID from a unit GUID
function CCRotation:GetNPCIDFromGUID(guid)
    if not guid then return end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

-- Update individual spell cooldown data
function CCRotation:UpdateSpellCooldown(unit, spellID, cooldownInfo)
    local info = self.trackedCooldowns[spellID]
    if not (unit and info and cooldownInfo and lib) then return end
    
    local GUID = UnitGUID(unit)
    if not GUID then return end
    
    local _, _, timeLeft, charges, _, _, _, duration = lib.GetCooldownStatusFromCooldownInfo(cooldownInfo)
    local currentTime = GetTime()

    -- Create unique key for this spell/player combination
    local key = GUID .. ":" .. spellID
    
    -- Check if this is actually a significant update to avoid unnecessary refreshes
    local existingData = self.spellCooldowns[key]
    local newExpirationTime = timeLeft + currentTime
    
    -- Only update if this is a new spell or the cooldown changed significantly (more than 0.2 seconds)
    if not existingData or 
       math.abs(existingData.expirationTime - newExpirationTime) > 0.2 or
       (existingData.charges or 0) ~= charges then
        
        self.spellCooldowns[key] = {
            GUID = GUID,
            spellID = spellID,
            priority = info.priority,
            expirationTime = newExpirationTime,
            duration = duration,
            charges = charges,
            lastUpdate = currentTime
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
    
    -- Schedule a new rebuild after a short delay
    self._rebuildTimer = C_Timer.After(0.1, function()
        self._rebuildTimer = nil
        self:DoRebuildQueue()
    end)
end

-- Consolidated queue rebuild implementation
function CCRotation:DoRebuildQueue()
    -- === STEP 1: Gather Data ===
    
    -- Store old GUID mapping to detect group changes
    local oldGUIDToUnit = {}
    for guid, unit in pairs(self.GUIDToUnit) do
        oldGUIDToUnit[guid] = unit
    end
    
    -- Refresh GUID→unit mapping
    self:RefreshGUIDToUnit()
    
    -- Check if group composition changed
    local groupChanged = false
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
    
    -- Update cooldown data
    local hasChanges = false
    
    -- Update individual spell cooldowns without affecting others
    local allUnits = lib.GetAllUnitsCooldown()
    if allUnits then
        for unit, cds in pairs(allUnits) do
            for spellID, info in pairs(cds) do
                if self.trackedCooldowns[spellID] then
                    if self:UpdateSpellCooldown(unit, spellID, info) then
                        hasChanges = true
                    end
                end
            end
        end
    end

    -- Clean up stale data if group changed
    if groupChanged then
        self:CleanupStaleSpellCooldowns()
    end
    
    -- Only proceed if there were changes
    if not (hasChanges or groupChanged) then
        return
    end
    
    -- === STEP 2: Transform Data ===
    
    -- Convert spell cooldowns to queue format
    self.cooldownQueue = {}
    for key, spellData in pairs(self.spellCooldowns) do
        table.insert(self.cooldownQueue, spellData)
    end
    
    -- Mark abilities as effective and add cast information for glow logic
    for _, cd in ipairs(self.cooldownQueue) do
        cd.isEffective = true -- All abilities are always effective in normal rotation
        
        -- Add dangerous cast information only if feature is enabled
        if addon.Config:Get("showDangerousCasts") then
            local info = self.trackedCooldowns[cd.spellID]
            local ccType = info and info.type
            
            if ccType and addon.CastTracker then
                local matchingCasts = addon.CastTracker:GetDangerousCastsForCCType(ccType)
                if #matchingCasts > 0 then
                    cd.dangerousCasts = matchingCasts
                else
                    -- Clear stale dangerous cast data when no active casts
                    cd.dangerousCasts = nil
                end
            else
                -- Clear dangerous cast data if no CC type or CastTracker
                cd.dangerousCasts = nil
            end
        else
            -- Clear dangerous cast data if feature is disabled
            cd.dangerousCasts = nil
        end
    end
    
    -- === STEP 3: Sort and Separate ===
    
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
    
    -- Sort both queues using shared sorting logic
    local function sortQueue(a, b)
        local unitA, unitB = self.GUIDToUnit[a.GUID], self.GUIDToUnit[b.GUID]
        if not (unitA and unitB) then return false end
        
        local nameA, nameB = UnitName(unitA), UnitName(unitB)
        local isPriorityA = addon.Config:IsPriorityPlayer(nameA)
        local isPriorityB = addon.Config:IsPriorityPlayer(nameB)
        
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
    end
    
    table.sort(availableQueue, sortQueue)
    table.sort(unavailableQueue, sortQueue)
    
    -- Update the main queue and store unavailable queue
    self.cooldownQueue = availableQueue
    self.unavailableQueue = unavailableQueue
    
    -- === STEP 4: Check Changes and Fire Events ===
    
    self:FireEvent("QUEUE_UPDATED", self.cooldownQueue, self.unavailableQueue)

    -- Check if secondary queue should be shown (first ability on cooldown)
    local shouldShowSecondary = self:ShouldShowSecondaryQueue()
    self:FireEvent("SECONDARY_QUEUE_STATE_CHANGED", shouldShowSecondary)

    -- === STEP 5: Handle Side Effects ===
    
--     self:CheckPugAnnouncement()
    self:CheckPlayerTurnStatus()
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

-- Check if player is next in queue and fire notification event
function CCRotation:CheckPlayerTurnStatus()
    local config = addon.Config
    if not config:Get("enableTurnNotification") then
        self.wasPlayerNext = false
        return
    end
    
    
    -- Always check player turn status in normal rotation (no dangerous cast requirement)
    
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
    
    -- Always check pug announcements in normal rotation (no dangerous cast requirement)
    
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
                    local spellName = firstInQueue.name
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
    -- Cancel non-combat timer if running
    if self.nonCombatTicker then
        self.nonCombatTicker:Cancel()
        self.nonCombatTicker = nil
    end
    
    -- Start periodic queue rebuilding every second
    if self.queueTicker then self.queueTicker:Cancel() end
    self.queueTicker = C_Timer.NewTicker(1, function()
        -- Rebuild queue (will only update UI if queue actually changed)
        self:RebuildQueue()
    end)
end

-- Combat end handler
function CCRotation:OnCombatEnd()
    -- Stop combat timers
    if self.queueTicker then
        self.queueTicker:Cancel()
        self.queueTicker = nil
    end
    
    -- Start non-combat periodic queue rebuild every 3 seconds
    if self.nonCombatTicker then self.nonCombatTicker:Cancel() end
    self.nonCombatTicker = C_Timer.NewTicker(3, function()
        self:RebuildQueue()
    end)
end

-- Handle dangerous cast events
function CCRotation:OnDangerousCastStarted(castInfo)
    -- Only process dangerous cast events if feature is enabled
    if addon.Config:Get("showDangerousCasts") then
        -- Immediately rebuild queue when dangerous cast starts
        self:RebuildQueue()
    end
end

function CCRotation:OnDangerousCastStopped(castInfo)
    -- Only process dangerous cast events if feature is enabled
    if addon.Config:Get("showDangerousCasts") then
        -- Immediately rebuild queue when dangerous cast stops
        self:RebuildQueue()
    end
end

-- Get the current queue for display
function CCRotation:GetQueue()
    return self.cooldownQueue
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
