-- NPCsDataProvider.lua - Data abstraction layer for NPC components
-- Provides clean interface between components and data layer

local addonName, addon = ...

local NPCsDataProvider = {}

-- Get current dungeon information
function NPCsDataProvider:getCurrentDungeonInfo()
    local dungeonName, instanceType = addon.Database:GetCurrentDungeonInfo()
    local isKnownDungeon = addon.Database:IsInKnownDungeon()
    return dungeonName, instanceType, isKnownDungeon
end

-- Get all NPCs grouped by dungeon
function NPCsDataProvider:getNPCsByDungeon(filterToDungeon)
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
function NPCsDataProvider:getDungeonList()
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

-- Get target NPC info
function NPCsDataProvider:getTargetNPCInfo()
    return addon.Database:GetTargetNPCInfo()
end

-- Search NPCs by name
function NPCsDataProvider:searchNPCsByName(searchTerm)
    return addon.Database:SearchNPCsByName(searchTerm)
end

-- Check if NPC exists
function NPCsDataProvider:npcExists(npcID)
    return addon.Database:NPCExists(npcID)
end

-- Extract dungeon info from name (legacy method - now returns basic info)
function NPCsDataProvider:extractDungeonInfo(name)
    return nil, "Other", name
end

-- Update NPC name
function NPCsDataProvider:updateNPCName(npcID, npcData, newMobName, dungeonName)
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
function NPCsDataProvider:updateNPCDungeon(npcID, npcData, newDungeon)
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
function NPCsDataProvider:updateNPCCC(npcID, npcData, ccIndex, value, dungeonName)
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
function NPCsDataProvider:resetNPC(npcID)
    addon.Config.db.customNPCs[npcID] = nil
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
end

-- Delete custom NPC
function NPCsDataProvider:deleteCustomNPC(npcID)
    addon.Config.db.customNPCs[npcID] = nil
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "customNPCs", npcID)
end

-- Add custom NPC
function NPCsDataProvider:addCustomNPC(npcID, npcName, selectedDungeon, ccEffectiveness)
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
function NPCsDataProvider:setNPCEnabled(npcID, enabled)
    if enabled then
        addon.Config.db.inactiveNPCs[npcID] = nil
    else
        addon.Config.db.inactiveNPCs[npcID] = true
    end
    
    addon.Config:FireEvent("PROFILE_DATA_CHANGED", "inactiveNPCs", npcID)
end

-- Check if NPC is enabled
function NPCsDataProvider:isNPCEnabled(npcID)
    return not addon.Config.db.inactiveNPCs[npcID]
end

-- Get NPC effectiveness (filtered by enabled state)
function NPCsDataProvider:getNPCEffectiveness(npcID)
    -- Return nil for disabled NPCs (exclude from rotation)
    if addon.Config.db.inactiveNPCs[npcID] then
        return nil
    end
    
    -- Delegate to Config for the actual effectiveness logic
    return addon.Config:GetNPCEffectiveness(npcID)
end

-- Register in addon namespace
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.NPCs = NPCsDataProvider

return NPCsDataProvider