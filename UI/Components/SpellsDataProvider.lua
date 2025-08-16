local addonName, addon = ...

local SpellsDataProvider = {}

-- Get effective spell data (synced data takes priority over profile data)
function SpellsDataProvider:getEffectiveSpellData()
    -- If we're in party sync mode, use synced data
    if addon.PartySync and addon.PartySync:IsInPartySync() then
        local syncedSpells = addon.PartySync:GetDisplaySpells()
        if syncedSpells then
            addon.Config:DebugPrint("Using SYNCED spell data from party leader")
            return syncedSpells
        end
    end
    
    -- Otherwise use local profile data
    addon.Config:DebugPrint("Using LOCAL profile spell data")
    return addon.Config.db.spells or {}
end

-- Get valid CC types for dropdown
function SpellsDataProvider:getCCTypes()
    local ccTypeList = {}
    for type, displayName in pairs(addon.Config.ccTypeMapping) do
        table.insert(ccTypeList, displayName)
    end
    table.sort(ccTypeList)
    
    -- Add "- All -" option at the beginning for filtering
    table.insert(ccTypeList, 1, "- All -")
    
    return ccTypeList
end

-- Get all active spells
function SpellsDataProvider:getActiveSpells()
    local allSpells = {}
    local effectiveSpells = self:getEffectiveSpellData()
    
    -- Get only active spells from effective data
    for spellID, spell in pairs(effectiveSpells) do
        if spell.active then
            allSpells[spellID] = {
                name = spell.name,
                ccType = spell.ccType,
                priority = spell.priority,
                source = spell.source
            }
        end
    end
    
    return allSpells
end

-- Get disabled spells
function SpellsDataProvider:getDisabledSpells()
    local disabledSpells = {}
    local effectiveSpells = self:getEffectiveSpellData()
    
    -- Get only inactive spells from effective data
    for spellID, spell in pairs(effectiveSpells) do
        if not spell.active then
            disabledSpells[spellID] = spell
        end
    end
    
    return disabledSpells
end

-- Add custom spell
function SpellsDataProvider:addCustomSpell(spellID, spellName, ccType, priority)
    addon.Config.db.spells[spellID] = {
        name = spellName,
        ccType = ccType,
        priority = priority,
        active = true,
        source = "custom"
    }
    
    -- Update rotation system
    self:onConfigChanged()
end

-- Update spell data
function SpellsDataProvider:updateSpell(spellID, spellData, field, value)
    if addon.Config.db.spells[spellID] then
        addon.Config.db.spells[spellID][field] = value
    end
    
    self:onConfigChanged()
end

-- Change spell ID (complex operation that moves data from old ID to new ID)
function SpellsDataProvider:changeSpellID(oldSpellID, newSpellID, spellData)
    if not addon.Config.db.spells[oldSpellID] then
        return false, "Original spell not found"
    end
    
    if addon.Config.db.spells[newSpellID] then
        return false, "New spell ID already exists"
    end
    
    -- Copy data from old spell ID to new spell ID
    addon.Config.db.spells[newSpellID] = addon.Config.db.spells[oldSpellID]
    
    -- Remove old spell ID entry
    addon.Config.db.spells[oldSpellID] = nil
    
    self:onConfigChanged()
    return true
end

-- Disable spell
function SpellsDataProvider:disableSpell(spellID, spellData)
    -- Set spell as inactive in unified table
    if addon.Config.db.spells[spellID] then
        addon.Config.db.spells[spellID].active = false
    end
    
    -- Renumber remaining active spells
    self:renumberSpellPriorities()
    
    self:onConfigChanged()
end

-- Enable spell
function SpellsDataProvider:enableSpell(spellID)
    -- Find the highest current priority among active spells
    local highestPriority = 0
    for _, spell in pairs(addon.Config.db.spells) do
        if spell.active and spell.priority > highestPriority then
            highestPriority = spell.priority
        end
    end
    
    -- Set spell as active with new priority
    if addon.Config.db.spells[spellID] then
        addon.Config.db.spells[spellID].active = true
        addon.Config.db.spells[spellID].priority = highestPriority + 1
    end
    
    self:onConfigChanged()
end

-- Delete custom spell
function SpellsDataProvider:deleteCustomSpell(spellID)
    addon.Config.db.spells[spellID] = nil
    
    self:onConfigChanged()
end

-- Move spell priority (up or down)
function SpellsDataProvider:moveSpellPriority(spellID, spellData, direction, sortedSpells, index)
    -- Extract the actual direction parameter (3rd parameter)
    local directionStr = tostring(direction)
    
    if not addon.Config.db.spells[spellID] or not addon.Config.db.spells[spellID].active then
        return
    end
    
    -- Get all active spells sorted by priority
    local activeSpells = {}
    for id, spell in pairs(addon.Config.db.spells) do
        if spell.active then
            table.insert(activeSpells, {spellID = id, priority = spell.priority, name = spell.name})
        end
    end
    
    table.sort(activeSpells, function(a, b)
        return a.priority < b.priority
    end)
    
    -- Find current position in sorted list
    local currentIndex = nil
    for i, spell in ipairs(activeSpells) do
        if spell.spellID == spellID then
            currentIndex = i
            break
        end
    end
    
    if not currentIndex then
        return
    end
    
    -- Calculate new position  
    local moveOffset = (directionStr == "up" and -1 or 1)
    local newIndex = currentIndex + moveOffset
    
    -- Check bounds
    if newIndex < 1 or newIndex > #activeSpells then
        return -- Can't move beyond bounds
    end
    
    -- Swap positions in the array
    local temp = activeSpells[currentIndex]
    activeSpells[currentIndex] = activeSpells[newIndex]
    activeSpells[newIndex] = temp
    
    -- Reassign priorities based on new order
    for i, spell in ipairs(activeSpells) do
        addon.Config.db.spells[spell.spellID].priority = i
    end
    
    self:onConfigChanged()
end

-- Renumber spell priorities to eliminate gaps
function SpellsDataProvider:renumberSpellPriorities()
    -- Get all active spells
    local allSpells = self:getActiveSpells()
    
    -- Sort spells by current priority
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    
    table.sort(sortedSpells, function(a, b)
        return a.data.priority < b.data.priority
    end)
    
    -- Reassign priorities starting from 1
    for i, spell in ipairs(sortedSpells) do
        local newPriority = i
        
        -- Update the priority in unified table
        if addon.Config.db.spells[spell.spellID] then
            addon.Config.db.spells[spell.spellID].priority = newPriority
        end
    end
    
    -- Immediately update tracked cooldowns cache and rebuild queue
    self:onConfigChanged()
end

function SpellsDataProvider:onConfigChanged()
    -- Update rotation system
    self:updateRotationSystem()
    
    -- Fire event for config changes
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "spells")
end

-- Update rotation system after data changes
function SpellsDataProvider:updateRotationSystem()
    if addon.CCRotation then
        -- Update the tracked cooldowns cache with new priorities
        addon.CCRotation.trackedCooldowns = addon.Config:GetTrackedSpells()

        -- Clear existing queues and spell cooldowns to force a fresh rebuild
        addon.CCRotation.cooldownQueue = {}
        addon.CCRotation.unavailableQueue = {}
        addon.CCRotation.spellCooldowns = {}
        
        -- Force immediate synchronous rebuild instead of debounced rebuild
        if addon.CCRotation.DoRebuildQueue then
            addon.CCRotation:DoRebuildQueue()
        elseif addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
    end
end

-- Create namespace if it doesn't exist
if not addon.DataProviders then
    addon.DataProviders = {}
end

addon.DataProviders.Spells = SpellsDataProvider