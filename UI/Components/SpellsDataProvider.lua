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
    self:onConfigChanged()
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
    
    self:onConfigChanged()
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
    
    self:onConfigChanged()
end

-- Enable spell
function SpellsDataProvider:enableSpell(spellID)
    local disabledSpellData = addon.Config.db.inactiveSpells[spellID]
    addon.Config.db.inactiveSpells[spellID] = nil
    
    -- Find the highest current priority among active spells
    local highestPriority = 0
    local allActiveSpells = self:getActiveSpells()
    for _, spellData in pairs(allActiveSpells) do
        if spellData.priority > highestPriority then
            highestPriority = spellData.priority
        end
    end
    
    -- Assign the enabled spell a priority higher than the current highest
    local newPriority = highestPriority + 1
    
    -- If it's a database spell being re-enabled, create/update custom entry to set priority
    if disabledSpellData and addon.Database.defaultSpells[spellID] then
        -- Database spell - create custom override for priority
        addon.Config.db.customSpells[spellID] = addon.Config.db.customSpells[spellID] or {}
        addon.Config.db.customSpells[spellID].priority = newPriority
        -- Preserve any existing custom name/ccType if they exist
        if not addon.Config.db.customSpells[spellID].name then
            addon.Config.db.customSpells[spellID].name = disabledSpellData.name
        end
        if not addon.Config.db.customSpells[spellID].ccType then
            addon.Config.db.customSpells[spellID].ccType = disabledSpellData.ccType
        end
    elseif disabledSpellData then
        -- Custom spell - update priority in customSpells
        if addon.Config.db.customSpells[spellID] then
            addon.Config.db.customSpells[spellID].priority = newPriority
        end
    end
    
    self:onConfigChanged()
end

-- Delete custom spell
function SpellsDataProvider:deleteCustomSpell(spellID)
    addon.Config.db.inactiveSpells[spellID] = nil
    addon.Config.db.customSpells[spellID] = nil
    
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
    
    -- Create a new priority ordering by reordering the entire list
    local newOrder = {}
    for i, spell in ipairs(sortedSpells) do
        newOrder[i] = spell
    end
    
    -- Swap positions in the array
    newOrder[currentIndex], newOrder[targetIndex] = newOrder[targetIndex], newOrder[currentIndex]
    
    -- Now assign sequential priorities based on the new order
    for i, spell in ipairs(newOrder) do
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
    
    -- Immediately update tracked cooldowns cache and rebuild queue
    self:onConfigChanged()
end

function SpellsDataProvider:onConfigChanged()
    -- Update rotation system
    self:updateRotationSystem()
    
    -- Fire event for config changes (ProfileSync will handle sync automatically)
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
        
        -- Force immediate UI update with the newly rebuilt queues
        if addon.UI and addon.UI.UpdateDisplay then
            addon.UI:UpdateDisplay(addon.CCRotation.cooldownQueue, addon.CCRotation.unavailableQueue)
        end
    end
end

-- Register in addon namespace
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.Spells = SpellsDataProvider

return SpellsDataProvider