local addonName, addon = ...

local DataManager = {}

-- =============================================================================
-- Configuration Management
-- =============================================================================

DataManager.config = {}

-- Get configuration value
function DataManager.config:get(key)
    local value = addon.Config:Get(key)
    if key == "cooldownFontSizePercent" and value == nil then
        return 25
    end
    return value
end

-- Set configuration value
function DataManager.config:set(key, value)
    addon.Config:Set(key, value)
end

-- Rebuild queue (for settings that affect rotation logic)
function DataManager.config:rebuildQueue()
    if addon.CCRotation and addon.CCRotation.RebuildQueue then
        addon.CCRotation:RebuildQueue()
    end
end

-- =============================================================================
-- Player Management (from PlayersDataProvider)
-- =============================================================================

DataManager.players = {}

-- Get priority players list
function DataManager.players:getPriorityPlayers()
    return addon.Config.db.priorityPlayers or {}
end

-- Get priority players as sorted array
function DataManager.players:getPriorityPlayersArray()
    local players = {}
    for name in pairs(self:getPriorityPlayers()) do
        table.insert(players, name)
    end
    table.sort(players)
    return players
end

-- Add priority player
function DataManager.players:addPriorityPlayer(playerName)
    if not playerName or playerName:trim() == "" then
        return false
    end
    
    addon.Config:AddPriorityPlayer(playerName)
    return true
end

-- Remove priority player
function DataManager.players:removePriorityPlayer(playerName)
    if not playerName or playerName:trim() == "" then
        return false
    end
    
    addon.Config:RemovePriorityPlayer(playerName)
    return true
end

-- Check if player is priority
function DataManager.players:isPlayerPriority(playerName)
    return addon.Config.db.priorityPlayers[playerName] ~= nil
end

-- =============================================================================
-- Spell Management (from SpellsDataProvider)
-- =============================================================================

DataManager.spells = {}

-- Get effective spell data (synced data takes priority over profile data)
function DataManager.spells:getEffectiveSpellData()
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
function DataManager.spells:getCCTypes()
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
function DataManager.spells:getActiveSpells()
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
function DataManager.spells:getDisabledSpells()
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
function DataManager.spells:addCustomSpell(spellID, spellName, ccType, priority)
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
function DataManager.spells:updateSpell(spellID, field, value)
    if addon.Config.db.spells[spellID] then
        addon.Config.db.spells[spellID][field] = value
    end
    
    self:onConfigChanged()
end

-- Change spell ID (complex operation that moves data from old ID to new ID)
function DataManager.spells:changeSpellID(oldSpellID, newSpellID)
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
function DataManager.spells:disableSpell(spellID)
    -- Set spell as inactive in unified table
    if addon.Config.db.spells[spellID] then
        addon.Config.db.spells[spellID].active = false
    end
    
    -- Renumber remaining active spells
    self:renumberSpellPriorities()
    
    self:onConfigChanged()
end

-- Enable spell
function DataManager.spells:enableSpell(spellID)
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
function DataManager.spells:deleteCustomSpell(spellID)
    if not spellID or not addon.Config.db.spells[spellID] then
        return false
    end
    
    addon.Config.db.spells[spellID] = nil
    self:onConfigChanged()
    return true
end

-- Move spell priority (up or down)
function DataManager.spells:moveSpellPriority(spellID, direction)
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
function DataManager.spells:renumberSpellPriorities()
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

function DataManager.spells:onConfigChanged()
    -- Update rotation system
    self:updateRotationSystem()
    
    -- Fire event for config changes
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "spells")
end

-- Update rotation system after data changes
function DataManager.spells:updateRotationSystem()
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

-- =============================================================================
-- NPC Management (from NPCsDataProvider)
-- =============================================================================

DataManager.npcs = {}

-- Get all NPCs grouped by dungeon
function DataManager.npcs:getNPCsByDungeon(filterToDungeon)
    local dungeonGroups = {}
    
    -- Process database NPCs
    for npcID, data in pairs(addon.Database.defaultNPCs) do
        local dungeonName = data.dungeon or "Other"
        
        -- Apply filter if active
        if not filterToDungeon or dungeonName == filterToDungeon then
            if not dungeonGroups[dungeonName] then
                dungeonGroups[dungeonName] = {
                    npcs = {}
                }
            end
            
            dungeonGroups[dungeonName].npcs[npcID] = {
                name = data.name,
                cc = data.cc,
                source = "database",
                dungeon = data.dungeon,
                enabled = not addon.Config.db.inactiveNPCs[npcID]
            }
        end
    end
    
    -- Override with custom NPCs
    for npcID, data in pairs(addon.Config.db.customNPCs) do
        local dungeonName = data.dungeon or "Other"
        
        -- Apply filter if active
        if not filterToDungeon or dungeonName == filterToDungeon then
            if not dungeonGroups[dungeonName] then
                dungeonGroups[dungeonName] = {
                    npcs = {}
                }
            end
            
            dungeonGroups[dungeonName].npcs[npcID] = {
                name = data.name,
                cc = data.cc,
                source = "custom",
                dungeon = data.dungeon,
                enabled = not addon.Config.db.inactiveNPCs[npcID]
            }
        end
    end
    
    -- Sort dungeons by name
    local sortedDungeons = {}
    for dungeonName, dungeonData in pairs(dungeonGroups) do
        table.insert(sortedDungeons, {name = dungeonName, data = dungeonData})
    end
    table.sort(sortedDungeons, function(a, b) return a.name < b.name end)
    
    return sortedDungeons
end

-- Get dungeon list for dropdowns
function DataManager.npcs:getDungeonList()
    local dungeonList = {["Other"] = "Other"}
    
    -- Get dungeon names from existing NPCs
    for npcID, data in pairs(addon.Database.defaultNPCs) do
        if data.dungeon then
            dungeonList[data.dungeon] = data.dungeon
        end
    end
    
    -- Add custom dungeon names
    for npcID, data in pairs(addon.Config.db.customNPCs) do
        if data.dungeon then
            dungeonList[data.dungeon] = data.dungeon
        end
    end
    
    return dungeonList
end

-- Update NPC name
function DataManager.npcs:updateNPCName(npcID, npcData, newMobName, dungeonName)
    if npcData.source == "custom" then
        addon.Config.db.customNPCs[npcID].name = newMobName
        addon.Config.db.customNPCs[npcID].dungeon = dungeonName
    else
        -- Create custom entry to override database NPC
        addon.Config.db.customNPCs[npcID] = {
            name = newMobName,
            cc = npcData.cc,
            dungeon = dungeonName
        }
    end

    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
end

-- Update NPC dungeon
function DataManager.npcs:updateNPCDungeon(npcID, npcData, newDungeon)
    if not addon.Config.db.customNPCs[npcID] then
        -- Create custom entry to override database NPC
        addon.Config.db.customNPCs[npcID] = {
            name = npcData.name,
            cc = npcData.cc,
            dungeon = newDungeon
        }
    else
        addon.Config.db.customNPCs[npcID].dungeon = newDungeon
    end
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
end

-- Update NPC CC effectiveness
function DataManager.npcs:updateNPCCC(npcID, npcData, ccIndex, value, dungeonName)
    local newCC = {}
    for j = 1, 5 do
        if j == ccIndex then
            newCC[j] = value
        else
            newCC[j] = npcData.cc[j]
        end
    end
    
    if npcData.source == "custom" then
        addon.Config.db.customNPCs[npcID].cc = newCC
    else
        -- Create custom entry to override database NPC
        addon.Config.db.customNPCs[npcID] = {
            name = npcData.name,
            cc = newCC,
            dungeon = dungeonName
        }
    end
    
    -- Update local data for consistency
    npcData.cc = newCC

    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
end

-- Reset NPC to database defaults
function DataManager.npcs:resetNPC(npcID)
    addon.Config.db.customNPCs[npcID] = nil
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
end

-- Delete custom NPC
function DataManager.npcs:deleteCustomNPC(npcID)
    addon.Config.db.customNPCs[npcID] = nil
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
end

-- Add custom NPC
function DataManager.npcs:addCustomNPC(npcID, npcName, selectedDungeon, ccEffectiveness)
    -- Add to custom NPCs
    addon.Config.db.customNPCs[npcID] = {
        name = npcName,
        cc = {ccEffectiveness[1], ccEffectiveness[2], ccEffectiveness[3], ccEffectiveness[4], ccEffectiveness[5]},
        dungeon = selectedDungeon
    }

    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
    
    return npcName
end

-- Enable/disable NPC
function DataManager.npcs:setNPCEnabled(npcID, enabled)
    if enabled then
        addon.Config.db.inactiveNPCs[npcID] = nil
    else
        addon.Config.db.inactiveNPCs[npcID] = true
    end
    
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "inactiveNPCs", npcID)
end

-- Check if NPC is enabled
function DataManager.npcs:isNPCEnabled(npcID)
    return not addon.Config.db.inactiveNPCs[npcID]
end


-- =============================================================================
-- Profile Management (from ProfilesDataProvider)
-- =============================================================================

DataManager.profiles = {}

-- Get current profile information
function DataManager.profiles:getCurrentProfileInfo()
    return {
        name = addon.Config:GetCurrentProfileName(),
        isLocked = addon.Config:IsProfileSelectionLocked()
    }
end


-- Check if profile sync is available
function DataManager.profiles:isProfileSyncAvailable()
    return addon.PartySync ~= nil
end

-- =============================================================================
-- Registration and Initialization
-- =============================================================================

-- Register in addon namespace (maintain backward compatibility)
if not addon.Components then
    addon.Components = {}
end
addon.Components.DataManager = DataManager

-- Also register individual providers for backward compatibility
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.Config = DataManager.config
addon.DataProviders.Players = DataManager.players
addon.DataProviders.Spells = DataManager.spells
addon.DataProviders.NPCs = DataManager.npcs
addon.DataProviders.Profiles = DataManager.profiles

return DataManager