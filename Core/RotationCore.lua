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
    
    -- Listen for config changes that affect enabled state
    addon.Config:RegisterEventListener("CONFIG_UPDATED", function(key, value, oldValue)
        if key == "enabled" or key == "onlyInDungeons" or key == "showInSolo" then
            self:HandleActiveStateChange()
        end
    end)
    
    -- Check initial state and enable/disable accordingly
    self:HandleActiveStateChange()
    
    -- Schedule delayed queue rebuild to ensure LibOpenRaid has data (only if enabled)
    if self.enabled then
        C_Timer.After(1, function()
            self:RebuildQueue()
        end)
    end
end

-- Handle changes in settings that affect whether the addon should be active
function CCRotation:HandleActiveStateChange()
    local shouldBeActive = self:ShouldBeActive()
    
    if shouldBeActive and not self.enabled then
        self:Enable()
        -- Delayed rebuild after enabling
        C_Timer.After(0.1, function()
            self:RebuildQueue()
        end)
    elseif not shouldBeActive and self.enabled then
        self:Disable()
    end
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
        -- Handle active state change first (location may affect onlyInDungeons setting)
        self:HandleActiveStateChange()
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
    
    -- Check if player has the talent/spell
    if UnitIsUnit(unit, "player") then
        -- For local player, use IsSpellKnown directly
        if not IsSpellKnown(spellID) then
            return false
        end
    else
        -- For other group members, check using cooldowns
        -- This is more reliable than trying to access talent data
        local allUnitsCooldown = lib.GetAllUnitsCooldown and lib.GetAllUnitsCooldown()
        if allUnitsCooldown then
            local unitCooldowns = allUnitsCooldown[UnitName(unit)]
            if unitCooldowns and not unitCooldowns[spellID] then
                -- If the unit has cooldown data but this ability isn't there,
                -- the ability is probably not available (talent not selected)
                return false
            end
        end
    end
    
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
    -- Don't rebuild queue if addon is disabled
    if not self.enabled then
        return
    end
    
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

function CCRotation:HasValidCCableNPC(ccType)
    -- Build a set of all active enemy NPC names with nameplates
    local activeNPCNames = {}
    local plates = C_NamePlate.GetNamePlates()
    for _, plate in ipairs(plates) do
        local unit = plate.UnitFrame and plate.UnitFrame.unit
        if unit and UnitAffectingCombat(unit) and UnitIsEnemy("player", unit) then
            local npcName = UnitName(unit)
            if npcName then
                activeNPCNames[npcName] = true
            end
        end
    end

    -- For each dangerousCasts entry, check if any active NPC accepts the ccType
    if addon.Database.dangerousCasts then
        for i = 1, #addon.Database.dangerousCasts do
            local entry = addon.Database.dangerousCasts[i]
            if type(entry) == "table" then
                for _, castData in pairs(entry) do
                    if type(castData) == "table" and castData.npcName and castData.ccTypes and activeNPCNames[castData.npcName] then
                        for _, npcCC in ipairs(castData.ccTypes) do
                            if npcCC == ccType then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
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
    
    -- Convert spell cooldowns to queue format, filter by valid CC if enabled
    self.cooldownQueue = {}
    local ccChecked = {}
    local enableCCPackFilter = addon.Config:Get("enableCCPackFilter")
    for key, spellData in pairs(self.spellCooldowns) do
        local info = self.trackedCooldowns[spellData.spellID]
        local ccType = info and info.type
        if enableCCPackFilter then
            if ccType and not ccChecked[ccType] then
                local hasTarget = self:HasValidCCableNPC(ccType)
                ccChecked[ccType] = true
            end
            if not ccType or self:HasValidCCableNPC(ccType) then
                table.insert(self.cooldownQueue, spellData)
            end
        else
            table.insert(self.cooldownQueue, spellData)
        end
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
                local triggerCount = addon.Config:Get("dangerousCastTriggerCount") or 1
                
                if #matchingCasts >= triggerCount then
                    cd.dangerousCasts = matchingCasts
                else
                    -- Clear dangerous cast data when cast count is below trigger threshold
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
    
    -- === STEP 3: Add Status and Sort ===
    
    local now = GetTime()
    
    -- Add status information to all cooldown data
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
        end
    end
    
    -- Sort queue with dead/out-of-range players at the end
    local function sortQueue(a, b)
        local unitA, unitB = self.GUIDToUnit[a.GUID], self.GUIDToUnit[b.GUID]
        if not (unitA and unitB) then return false end
        
        local nameA, nameB = UnitName(unitA), UnitName(unitB)
        local isPriorityA = addon.Config:IsPriorityPlayer(nameA)
        local isPriorityB = addon.Config:IsPriorityPlayer(nameB)
        
        local readyA = a.charges > 0 or a.expirationTime <= now
        local readyB = b.charges > 0 or b.expirationTime <= now
        
        local availableA = not a.isDead and a.inRange and readyA
        local availableB = not b.isDead and b.inRange and readyB
        
        -- 1. Available players first, then unavailable players
        if availableA ~= availableB then return availableA end
        
        -- 2. Among players who are in range and alive, prioritize ready spells
        if (not a.isDead and a.inRange) and (not b.isDead and b.inRange) and readyA ~= readyB then
            return readyA
        end
        
        -- 3. Among available ready spells, prioritize priority players
        if availableA and availableB and (isPriorityA ~= isPriorityB) then
            return isPriorityA
        end
        
        -- 4. Finally, fallback on configured priority (or soonest available cooldown)
        if readyA then
            return a.priority < b.priority
        else
            return a.expirationTime < b.expirationTime
        end
    end
    
    table.sort(self.cooldownQueue, sortQueue)
    
    -- === STEP 4: Check Changes and Fire Events ===
    
    self:FireEvent("QUEUE_UPDATED", self.cooldownQueue)

    -- === STEP 5: Handle Side Effects ===
    
    self:CheckPugAnnouncement()
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
    
    -- Don't check turn status if addon shouldn't be active
    if not self:ShouldBeActive() then
        self.wasPlayerNext = false
        return
    end
    
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
            local isPug = addon.PartySync:IsPlayerPug(playerName)
            local isSelf = UnitIsUnit(unit, "player")
            
            -- Never announce for yourself or players with the addon
            if isPug and not isSelf then
                -- Check if spell is ready (has charges or cooldown is up)
                local now = GetTime()
                local isReady = firstInQueue.charges > 0 or firstInQueue.expirationTime <= now
                
                if isReady then
                    -- Ensure we have a valid spell ID
                    if not firstInQueue.spellID then
                        if addon.Debug then
                            addon.Debug:Print("Error: No spellID in queue entry")
                        end
                        return
                    end
                    
                    -- Get spell name using the spell ID
                    local spellInfo = C_Spell.GetSpellInfo(firstInQueue.spellID)
                    local spellName = spellInfo and spellInfo.name
                    
                    -- Fallback if GetSpellInfo fails
                    if not spellName or spellName == "" then
                        spellName = "Ability #" .. tostring(firstInQueue.spellID)
                    end
                    
                    local announceKey = playerName .. ":" .. spellName
                    
                    -- Throttle announcements: minimum 2 seconds between announcements
                    -- and don't repeat the same player+spell combo
                    if self.lastAnnouncedSpell ~= announceKey and (now - self.lastAnnouncementTime) >= 2 then
                        self.lastAnnouncedSpell = announceKey
                        self.lastAnnouncementTime = now
                        
                        local channel = config:Get("pugAnnouncerChannel") or "SAY"
                        
                        -- Ensure we have all needed parts to create a message
                        if playerName and spellName then
                            local message = playerName .. ": " .. spellName .. " next"
                            
                            -- Send the announcement
                            SendChatMessage(message, channel)
                        end
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

-- Enable the addon system
function CCRotation:Enable()
    if self.enabled then
        return -- Already enabled
    end
    
    self.enabled = true
    
    -- Register for events
    self:RegisterEvents()
    
    -- Start the update timer
    self:StartUpdateTimer()
    
    addon.Config:DebugPrint("CCRotation enabled")
end

-- Disable the addon system
function CCRotation:Disable()
    if not self.enabled then
        return -- Already disabled
    end
    
    self.enabled = false
    
    -- Unregister events
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end
    
    -- Stop all timers
    self:StopUpdateTimer()
    
    if self.queueTicker then
        self.queueTicker:Cancel()
        self.queueTicker = nil
    end
    
    if self.nonCombatTicker then
        self.nonCombatTicker:Cancel()
        self.nonCombatTicker = nil
    end
    
    if self._rebuildTimer then
        self._rebuildTimer:Cancel()
        self._rebuildTimer = nil
    end
    
    -- Clear queues
    self.cooldownQueue = {}
    
    -- Fire empty queue update to hide UI
    self:FireEvent("QUEUE_UPDATED", {}, {})
    
    addon.Config:DebugPrint("CCRotation disabled")
end

-- Start the update timer
function CCRotation:StartUpdateTimer()
    if self.updateTimer then
        return -- Already running
    end
    
    self.updateTimer = C_Timer.NewTicker(0.1, function()
        self:UpdateRotationQueue()
    end)
end

-- Stop the update timer
function CCRotation:StopUpdateTimer()
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
end

-- Update rotation queue (called by timer)
function CCRotation:UpdateRotationQueue()
    -- Only process updates if addon is enabled
    if not self.enabled then
        return
    end
    
    self:RebuildQueue()
end
