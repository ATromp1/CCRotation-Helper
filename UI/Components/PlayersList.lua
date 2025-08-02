-- PlayersList.lua - Player-related components  
-- This file will contain: PriorityPlayersList, AddPlayerForm components

local addonName, addon = ...

-- Ensure Components namespace exists
if not addon.Components then
    addon.Components = {}
end

-- Components will be registered here during Players tab migration:
-- addon.Components.PriorityPlayersList = PriorityPlayersList
-- addon.Components.AddPlayerForm = AddPlayerForm