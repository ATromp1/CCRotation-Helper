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
    if addon.UI.RenumberSpellPriorities then
        addon.UI:RenumberSpellPriorities()
    end
    
    self:updateRotationSystem()
end

-- Enable spell
function SpellsDataProvider:enableSpell(spellID)
    addon.Config.db.inactiveSpells[spellID] = nil
    
    -- Renumber all active spells
    if addon.UI.RenumberSpellPriorities then
        addon.UI:RenumberSpellPriorities()
    end
    
    self:updateRotationSystem()
end

-- Delete custom spell
function SpellsDataProvider:deleteCustomSpell(spellID)
    addon.Config.db.inactiveSpells[spellID] = nil
    addon.Config.db.customSpells[spellID] = nil
    
    self:updateRotationSystem()
end

-- Move spell priority
function SpellsDataProvider:moveSpellPriority(spellID, spellData, direction, sortedSpells, currentIndex)
    if addon.UI.MoveSpellPriority then
        addon.UI:MoveSpellPriority(spellID, spellData, direction, sortedSpells, currentIndex)
    end
end

-- Update rotation system after data changes
function SpellsDataProvider:updateRotationSystem()
    if addon.CCRotation then
        addon.CCRotation.trackedCooldowns = addon.Config:GetTrackedSpells()
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