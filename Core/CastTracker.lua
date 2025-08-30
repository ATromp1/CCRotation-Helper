local addonName, addon = ...

addon.CastTracker = {}
local CastTracker = addon.CastTracker

function CastTracker:Initialize()
    self.activeDangerousCasts = {}
    self.nameplateUnits = {}
    
    -- Register for events
    self:RegisterEvents()
    
    -- Start monitoring nameplates
    self:UpdateNameplateUnits()
    
    -- Count dangerous casts
    local count = 0
    for _ in pairs(addon.Database.dangerousCasts) do
        count = count + 1
    end
end

function CastTracker:RegisterEvents()
    local frame = CreateFrame("Frame")
    self.eventFrame = frame
    
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        CastTracker:OnEvent(event, ...)
    end)
end

function CastTracker:OnEvent(event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        self:OnNameplateAdded(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        self:OnNameplateRemoved(unit)
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:OnPlayerEnteringWorld()
    end
end

function CastTracker:OnNameplateAdded(unit)
    if UnitIsEnemy("player", unit) then
        local unitName = UnitName(unit) or "Unknown"
        self.nameplateUnits[unit] = true
        self:RegisterCastEventsForUnit(unit)
    end
end

function CastTracker:OnNameplateRemoved(unit)
    if self.nameplateUnits[unit] then
        self.nameplateUnits[unit] = nil
        
        -- Clean up any active casts from this unit
        for castId, castInfo in pairs(self.activeDangerousCasts) do
            if castInfo.unit == unit then
                self.activeDangerousCasts[castId] = nil
                self:FireCastEvent("DANGEROUS_CAST_STOPPED", castInfo)
            end
        end
    end
end

function CastTracker:OnPlayerEnteringWorld()
    -- Clear all tracking when entering new area
    wipe(self.activeDangerousCasts)
    wipe(self.nameplateUnits)
    
    -- Re-scan nameplates after a brief delay
    C_Timer.After(1, function()
        self:UpdateNameplateUnits()
    end)
end

function CastTracker:RegisterCastEventsForUnit(unit)
    if not self.castFrame then
        self.castFrame = CreateFrame("Frame")
        self.castFrame:SetScript("OnEvent", function(frame, event, ...)
            CastTracker:OnCastEvent(event, ...)
        end)
        
        -- Register for all unit events once
        self.castFrame:RegisterEvent("UNIT_SPELLCAST_START")
        self.castFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
        self.castFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        self.castFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self.castFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    end
end

function CastTracker:OnCastEvent(event, unit, ...)
    if not self.nameplateUnits[unit] then
        return
    end
    
    if event == "UNIT_SPELLCAST_START" then
        self:OnCastStart(unit, ...)
    elseif event == "UNIT_SPELLCAST_STOP" or 
           event == "UNIT_SPELLCAST_INTERRUPTED" or
           event == "UNIT_SPELLCAST_SUCCEEDED" or
           event == "UNIT_SPELLCAST_FAILED" then
        self:OnCastEnd(unit, event, ...)
    end
end

function CastTracker:OnCastStart(unit, castGUID, spellID)
    -- Check if this is a dangerous cast
    if not addon.Database:IsDangerousCast(spellID) then
        return
    end
    
    local dangerousCast = addon.Database:GetDangerousCast(spellID)
    
    -- Get cast information
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    if not name then
        return
    end
    
    local castInfo = {
        unit = unit,
        spellID = spellID,
        castID = castID or castGUID,
        name = dangerousCast.name,
        startTime = startTimeMS / 1000,
        endTime = endTimeMS / 1000,
        ccTypes = dangerousCast.ccTypes,
        notInterruptible = notInterruptible
    }
    
    -- Store the active cast
    local castKey = unit .. ":" .. (castID or castGUID or spellID)
    self.activeDangerousCasts[castKey] = castInfo

    -- Fire event to notify other systems
    self:FireCastEvent("DANGEROUS_CAST_STARTED", castInfo)
end

function CastTracker:OnCastEnd(unit, event, castGUID, spellID)
    -- Find and remove the cast from active casts
    local castKey = unit .. ":" .. (castGUID or spellID)
    local castInfo = nil
    
    -- Search for matching cast (try different key formats)
    for key, info in pairs(self.activeDangerousCasts) do
        if key:find("^" .. unit .. ":") and (info.spellID == spellID or key:find(castGUID or "")) then
            castInfo = info
            self.activeDangerousCasts[key] = nil
            break
        end
    end
    
    if castInfo then
        castInfo.endEvent = event
        self:FireCastEvent("DANGEROUS_CAST_STOPPED", castInfo)
    end
end

function CastTracker:UpdateNameplateUnits()
    -- Clear existing nameplates
    wipe(self.nameplateUnits)
    
    -- Scan current nameplates
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if plate.UnitFrame and plate.UnitFrame.unit then
            local unit = plate.UnitFrame.unit
            if UnitIsEnemy("player", unit) then
                self.nameplateUnits[unit] = true
                self:RegisterCastEventsForUnit(unit)
            end
        end
    end
end

function CastTracker:FireCastEvent(event, castInfo)
    if addon.CCRotation and addon.CCRotation.FireEvent then
        addon.CCRotation:FireEvent(event, castInfo)
    end
end

function CastTracker:GetActiveDangerousCasts()
    return self.activeDangerousCasts
end

function CastTracker:HasActiveDangerousCasts()
    return next(self.activeDangerousCasts) ~= nil
end

function CastTracker:GetDangerousCastsForCCType(ccType)
    local matchingCasts = {}
    
    for key, castInfo in pairs(self.activeDangerousCasts) do
        if castInfo.ccTypes then
            for _, validType in ipairs(castInfo.ccTypes) do
                if validType == ccType then
                    table.insert(matchingCasts, castInfo)
                    break
                end
            end
        end
    end
    
    return matchingCasts
end