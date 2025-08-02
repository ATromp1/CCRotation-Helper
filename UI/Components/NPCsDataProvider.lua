-- NPCsDataProvider.lua - Data abstraction layer for NPC components
-- Provides clean interface between components and data layer

local addonName, addon = ...

local NPCsDataProvider = {}

-- Get current dungeon information
function NPCsDataProvider:getCurrentDungeonInfo()
    return addon.Database:GetCurrentDungeonInfo()
end

-- Get all NPCs grouped by dungeon
function NPCsDataProvider:getNPCsByDungeon(filterToDungeon)
    local dungeonGroups = {}
    
    -- Process database NPCs
    for npcID, data in pairs(addon.Database.defaultNPCs) do
        local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(data.name)
        
        -- Apply filter if active
        if not filterToDungeon or dungeonName == filterToDungeon then
            if not dungeonGroups[dungeonName] then
                dungeonGroups[dungeonName] = {
                    abbreviation = abbrev,
                    npcs = {}
                }
            end
            
            dungeonGroups[dungeonName].npcs[npcID] = {
                name = data.name,
                mobName = mobName,
                cc = data.cc,
                source = "database"
            }
        end
    end
    
    -- Override with custom NPCs
    for npcID, data in pairs(addon.Config.db.customNPCs) do
        local abbrev, dungeonName, mobName = addon.Database:ExtractDungeonInfo(data.name)
        -- Also check explicit dungeon field for custom NPCs
        local actualDungeon = data.dungeon or dungeonName
        
        -- Apply filter if active
        if not filterToDungeon or actualDungeon == filterToDungeon or dungeonName == filterToDungeon then
            local groupName = actualDungeon or dungeonName
            if not dungeonGroups[groupName] then
                dungeonGroups[groupName] = {
                    abbreviation = abbrev,
                    npcs = {}
                }
            end
            
            dungeonGroups[groupName].npcs[npcID] = {
                name = data.name,
                mobName = mobName,
                cc = data.cc,
                source = "custom",
                dungeon = data.dungeon
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
    for abbrev, fullName in pairs(addon.Database.dungeonNames) do
        dungeonList[fullName] = fullName
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

-- Extract dungeon info from name
function NPCsDataProvider:extractDungeonInfo(name)
    return addon.Database:ExtractDungeonInfo(name)
end

-- Update NPC name
function NPCsDataProvider:updateNPCName(npcID, npcData, newMobName, dungeonName, dungeonAbbrev)
    local newFullName
    if dungeonAbbrev then
        newFullName = dungeonAbbrev .. " - " .. newMobName
    else
        newFullName = newMobName
    end
    
    if npcData.source == "custom" then
        addon.Config.db.customNPCs[npcID].name = newFullName
    else
        -- Create custom entry to override database NPC
        addon.Config.db.customNPCs[npcID] = {
            name = newFullName,
            cc = npcData.cc,
            dungeon = dungeonName
        }
    end
end

-- Update NPC dungeon
function NPCsDataProvider:updateNPCDungeon(npcID, npcData, newDungeon)
    local oldName = npcData.mobName or npcData.name
    local newAbbrev = nil
    for abbrev, fullName in pairs(addon.Database.dungeonNames) do
        if fullName == newDungeon then
            newAbbrev = abbrev
            break
        end
    end
    
    local newFullName
    if newAbbrev then
        newFullName = newAbbrev .. " - " .. oldName
    else
        newFullName = oldName
    end
    
    addon.Config.db.customNPCs[npcID].name = newFullName
    addon.Config.db.customNPCs[npcID].dungeon = newDungeon
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
end

-- Reset NPC to database defaults
function NPCsDataProvider:resetNPC(npcID)
    addon.Config.db.customNPCs[npcID] = nil
end

-- Delete custom NPC
function NPCsDataProvider:deleteCustomNPC(npcID)
    addon.Config.db.customNPCs[npcID] = nil
end

-- Add custom NPC
function NPCsDataProvider:addCustomNPC(npcID, npcName, selectedDungeon, ccEffectiveness)
    -- Construct full name based on dungeon
    local fullName = npcName
    if selectedDungeon ~= "Other" then
        local abbrev = nil
        for abbreviation, fullDungeonName in pairs(addon.Database.dungeonNames) do
            if fullDungeonName == selectedDungeon then
                abbrev = abbreviation
                break
            end
        end
        if abbrev then
            fullName = abbrev .. " - " .. npcName
        end
    end
    
    -- Add to custom NPCs
    addon.Config.db.customNPCs[npcID] = {
        name = fullName,
        cc = {ccEffectiveness[1], ccEffectiveness[2], ccEffectiveness[3], ccEffectiveness[4], ccEffectiveness[5]},
        dungeon = selectedDungeon
    }
    
    return fullName
end

-- Register in addon namespace
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.NPCs = NPCsDataProvider

return NPCsDataProvider