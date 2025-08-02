-- PlayersDataProvider.lua - Data abstraction layer for player components
-- Provides clean interface between components and data layer

local addonName, addon = ...

local PlayersDataProvider = {}

-- Get priority players list
function PlayersDataProvider:getPriorityPlayers()
    return addon.Config.db.priorityPlayers or {}
end

-- Get priority players as sorted array
function PlayersDataProvider:getPriorityPlayersArray()
    local players = {}
    for name in pairs(self:getPriorityPlayers()) do
        table.insert(players, name)
    end
    table.sort(players)
    return players
end

-- Add priority player
function PlayersDataProvider:addPriorityPlayer(playerName)
    if not playerName or playerName:trim() == "" then
        return false
    end
    
    addon.Config:AddPriorityPlayer(playerName)
    return true
end

-- Remove priority player
function PlayersDataProvider:removePriorityPlayer(playerName)
    if not playerName or playerName:trim() == "" then
        return false
    end
    
    addon.Config:RemovePriorityPlayer(playerName)
    return true
end

-- Check if player is priority
function PlayersDataProvider:isPlayerPriority(playerName)
    return addon.Config.db.priorityPlayers[playerName] ~= nil
end

-- Register in addon namespace
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.Players = PlayersDataProvider

return PlayersDataProvider