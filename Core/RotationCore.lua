local addonName, addon = ...

-- Main addon object
addon.CCRotation = {}
local CCRotation = addon.CCRotation

-- LibOpenRaid reference
local lib = LibStub("LibOpenRaid-1.0", true)

-- Initialize core variables
function CCRotation:Initialize()
    -- Build NPC effectiveness map from database
    self.npcEffectiveness = addon.Database:BuildNPCEffectiveness()
    
    -- Get tracked spells from config
    self.trackedCooldowns = addon.Config:GetTrackedSpells()
    
    -- Initialize tracking variables
    self.cooldownQueue = {}
    self.GUIDToUnit = {}
    self.activeNPCs = {}
    
    -- Initialize GUID mapping
    self:RefreshGUIDToUnit()
    
    -- Register LibOpenRaid callbacks if library is available
    if lib then
        self:RegisterLibOpenRaidCallbacks()
    end
    
    -- Register for events
    self:RegisterEvents()
    
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
    }
    
    lib.RegisterCallback(callbacks, "CooldownUpdate", "CooldownUpdate")
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
    
    frame:SetScript("OnEvent", function(self, event, ...)
        CCRotation:OnEvent(event, ...)
    end)
end

-- Event handler
function CCRotation:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "CHALLENGE_MODE_START" then
        self:RebuildQueue()
    elseif event == "GROUP_ROSTER_UPDATE" then
        self:RefreshGUIDToUnit()
        self:RebuildQueue()
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:OnCombatEnd()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        self:OnNameplateAdded(unit)
    end
end

-- Handle LibOpenRaid cooldown updates
function CCRotation:OnCooldownUpdate(...)
    self:RebuildQueue()
end

-- Extract NPC ID from a unit GUID
function CCRotation:GetNPCIDFromGUID(guid)
    if not guid then return end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

-- Update or add an entry in the queue
function CCRotation:UpdateEntry(unit, spellID, cooldownInfo)
    local info = self.trackedCooldowns[spellID]
    if not (unit and info and cooldownInfo and lib) then return end
    
    local GUID = UnitGUID(unit)
    if not GUID then return end
    
    local _, _, timeLeft, charges, _, _, _, duration = lib.GetCooldownStatusFromCooldownInfo(cooldownInfo)
    local currentTime = GetTime()
    
    -- Check if entry already exists and update it
    for _, cooldownData in ipairs(self.cooldownQueue) do
        if cooldownData.GUID == GUID and cooldownData.spellID == spellID then
            cooldownData.expirationTime = timeLeft + currentTime
            cooldownData.duration = duration
            cooldownData.charges = charges
            return true
        end
    end
    
    -- Add new entry
    table.insert(self.cooldownQueue, {
        GUID = GUID,
        spellID = spellID,
        priority = info.priority,
        expirationTime = timeLeft + currentTime,
        duration = duration,
        charges = charges
    })
    
    return true
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

-- Actual queue rebuild implementation
function CCRotation:DoRebuildQueue()
    -- Refresh GUID→unit mapping
    self:RefreshGUIDToUnit()
    
    -- Rebuild the queue
    self.cooldownQueue = {}
    
    if lib then
        local allUnits = lib.GetAllUnitsCooldown()
        if allUnits then
            for unit, cds in pairs(allUnits) do
                for spellID, info in pairs(cds) do
                    if self.trackedCooldowns[spellID] then
                        self:UpdateEntry(unit, spellID, info)
                    end
                end
            end
        end
    end
    
    -- Filter by active NPCs if we have any
    if next(self.activeNPCs) then
        local filtered = {}
        for _, cd in ipairs(self.cooldownQueue) do
            local info = self.trackedCooldowns[cd.spellID]
            local ccType = info and info.type
            
            if not ccType then
                -- Uncategorized spells always show
                filtered[#filtered+1] = cd
            else
                -- Only keep if ANY active NPC accepts this CC type
                for npcID in pairs(self.activeNPCs) do
                    local effectiveness = addon.Config:GetNPCEffectiveness(npcID)
                    if effectiveness and effectiveness[ccType] then
                        filtered[#filtered+1] = cd
                        break
                    end
                end
            end
        end
        self.cooldownQueue = filtered
    end
    
    -- Sort and separate queues
    self:SortAndSeparateQueues()
    
    -- Notify UI to update
    if addon.UI then
        addon.UI:UpdateDisplay(self.cooldownQueue, self.unavailableQueue)
    end
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
            cooldownData.inRange = UnitInRange(unit)
            
            if cooldownData.isDead or not cooldownData.inRange then
                table.insert(unavailableQueue, cooldownData)
            else
                table.insert(availableQueue, cooldownData)
            end
        end
    end
    
    -- Sort available queue
    table.sort(availableQueue, function(a, b)
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
    end)
    
    -- Sort unavailable queue by what their priority WOULD be if available
    table.sort(unavailableQueue, function(a, b)
        local unitA, unitB = self.GUIDToUnit[a.GUID], self.GUIDToUnit[b.GUID]
        if not (unitA and unitB) then return false end
        
        local nameA, nameB = UnitName(unitA), UnitName(unitB)
        local isPriorityA = addon.Config:IsPriorityPlayer(nameA)
        local isPriorityB = addon.Config:IsPriorityPlayer(nameB)
        
        local readyA = a.charges > 0 or a.expirationTime <= now
        local readyB = b.charges > 0 or b.expirationTime <= now
        
        -- Same sorting as available queue to show proper priority
        if readyA ~= readyB then return readyA end
        if readyA and readyB and (isPriorityA ~= isPriorityB) then
            return isPriorityA
        end
        if readyA then
            return a.priority < b.priority
        else
            return a.expirationTime < b.expirationTime
        end
    end)
    
    -- Update the main queue and store unavailable queue
    self.cooldownQueue = availableQueue
    self.unavailableQueue = unavailableQueue
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
    
    -- Start periodic scanning
    if self.scanTicker then self.scanTicker:Cancel() end
    self.scanTicker = C_Timer.NewTicker(1, function()
        self:ScanNameplates()
    end)
end

-- Combat end handler
function CCRotation:OnCombatEnd()
    -- Stop timers
    if self.scanTicker then
        self.scanTicker:Cancel()
        self.scanTicker = nil
    end
    if self.quickScan then
        self.quickScan:Cancel()
        self.quickScan = nil
    end
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
    
    -- If we found new NPCs, rebuild queue
    if next(self.activeNPCs) then
        self:RebuildQueue()
    end
end

-- Get the current queue for display
function CCRotation:GetQueue()
    return self.cooldownQueue
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
    
    return true
end
