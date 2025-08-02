-- NPCsList.lua - NPC-related components
-- This file will contain: DungeonNPCList, NPCSearchForm, AddNPCForm, DungeonFilter components

local addonName, addon = ...

-- Ensure Components namespace exists
if not addon.Components then
    addon.Components = {}
end

-- Components will be registered here during NPCs tab migration:
-- addon.Components.DungeonNPCList = DungeonNPCList
-- addon.Components.NPCSearchForm = NPCSearchForm
-- addon.Components.AddNPCForm = AddNPCForm
-- addon.Components.DungeonFilter = DungeonFilter