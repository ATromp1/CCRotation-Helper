-- SpellsDataProvider.lua - Data abstraction layer for spell components
-- Provides clean interface between components and data layer

local addonName, addon = ...

local SpellsDataProvider = {}

-- Get CC type list for dropdowns
function SpellsDataProvider:getCCTypeList()
    local ccTypeList = {}
    for _, ccType in ipairs(addon.Database.ccTypeOrder) do
        ccTypeList[ccType] = addon.Database.ccTypeDisplayNames[ccType]
    end
    return ccTypeList
end

-- Get all active spells
function SpellsDataProvider:getActiveSpells()
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
    
    return allSpells
end

-- Get disabled spells
function SpellsDataProvider:getDisabledSpells()
    return addon.Config.db.inactiveSpells
end

-- Add custom spell
function SpellsDataProvider:addCustomSpell(spellID, spellName, ccType, priority)
    addon.Config.db.customSpells[spellID] = {
        name = spellName,
        ccType = ccType,
        priority = priority
    }
    
    -- Update rotation system
    self:updateRotationSystem()
end

-- Update spell data
function SpellsDataProvider:updateSpell(spellID, spellData, field, value)
    if spellData.source == "custom" then
        addon.Config.db.customSpells[spellID][field] = value
    else
        -- Create custom entry to override database spell
        addon.Config.db.customSpells[spellID] = {
            name = spellData.name,
            ccType = spellData.ccType,
            priority = spellData.priority,
            [field] = value
        }
    end
    
    self:updateRotationSystem()
end

-- Disable spell
function SpellsDataProvider:disableSpell(spellID, spellData)
    addon.Config.db.inactiveSpells[spellID] = {
        name = spellData.name,
        ccType = spellData.ccType,
        priority = spellData.priority,
        source = spellData.source
    }
    
    -- Renumber remaining active spells
    self:renumberSpellPriorities()
    
    self:updateRotationSystem()
end

-- Enable spell
function SpellsDataProvider:enableSpell(spellID)
    addon.Config.db.inactiveSpells[spellID] = nil
    
    -- Renumber all active spells
    self:renumberSpellPriorities()
    
    self:updateRotationSystem()
end

-- Delete custom spell
function SpellsDataProvider:deleteCustomSpell(spellID)
    addon.Config.db.inactiveSpells[spellID] = nil
    addon.Config.db.customSpells[spellID] = nil
    
    self:updateRotationSystem()
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

-- Move spell priority up or down
function SpellsDataProvider:moveSpellPriority(spellID, spellData, direction, sortedSpells, currentIndex)
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
    self:updateRotationSystem()
end

-- Update rotation system after data changes
function SpellsDataProvider:updateRotationSystem()
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

-- Register in addon namespace
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.Spells = SpellsDataProvider

return SpellsDataProvider