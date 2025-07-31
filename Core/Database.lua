local addonName, addon = ...

-- Database of NPC effectiveness and spell configurations
addon.Database = {}

-- CC Type lookup (backwards compatibility for old numeric values)
addon.Database.ccTypeLookup = {
    [1] = "stun",
    [2] = "disorient",
    [3] = "fear",
    [4] = "knock",
    [5] = "incapacitate",
    -- Direct string mappings (preferred)
    ["stun"] = "stun",
    ["disorient"] = "disorient",
    ["fear"] = "fear",
    ["knock"] = "knock",
    ["incapacitate"] = "incapacitate",
}

-- CC Type display names
addon.Database.ccTypeDisplayNames = {
    ["stun"] = "Stun",
    ["disorient"] = "Disorient",
    ["fear"] = "Fear",
    ["knock"] = "Knock",
    ["incapacitate"] = "Incapacitate",
}

-- CC Type order for UI consistency
addon.Database.ccTypeOrder = { "stun", "disorient", "fear", "knock", "incapacitate" }

-- Dungeon name mappings
addon.Database.dungeonNames = {
    ["ROOK"] = "The Rookery",
    ["WORK"] = "Operation: Mechagon - Workshop",
    ["TOP"] = "Theater of Pain",
    ["ML"] = "Motherlode",
    ["FL"] = "Fungal Folly",
    ["DFC"] = "Darkflame Cleft",
    ["CBM"] = "Cinderbrew Meadery",
    ["PRIO"] = "Priory of the Sacred Flame"
}

-- Function to extract dungeon info from NPC name
function addon.Database:ExtractDungeonInfo(npcName)
    local abbreviation, mobName = npcName:match("^([A-Z]+)%s*-%s*(.+)$")
    if abbreviation and self.dungeonNames[abbreviation] then
        return abbreviation, self.dungeonNames[abbreviation], mobName
    end
    return nil, "Other", npcName
end

-- Default NPC configurations from your WeakAura
addon.Database.defaultNPCs = {
    -- The Rookery
    [207198] = { name = "ROOK - Cursed Thunderer", cc = { true, true, true, true, true } },
    [214439] = { name = "ROOK - Corrupted Oracle", cc = { true, true, true, true, true } },

    -- Operation: Mechagon - Workshop
    [151657] = { name = "WORK - Bomb tonk", cc = { true, false, false, true, false } },
    [236033] = { name = "WORK - Metal gunk", cc = { true, true, true, true, true } },
    [151773] = { name = "WORK - Junkyard Dog", cc = { true, true, false, true, true } },
    [144294] = { name = "WORK - Mechagon tinkerer", cc = { true, true, true, true, true } },
    [144295] = { name = "WORK - Mechagon Mechanic", cc = { true, true, true, true, true } },

    -- Theater of Pain
    [174197] = { name = "TOP - Battlefield Ritualist", cc = { true, true, true, true, true } },
    [174210] = { name = "TOP - Sludge Spewer", cc = { true, true, false, true, true } },
    [169875] = { name = "TOP - Shackled Soul", cc = { true, true, false, true, true } },
    [160495] = { name = "TOP - Maniacal Soulbinder", cc = { true, true, true, true, true } },
    [170882] = { name = "TOP - Bone Magus", cc = { true, true, false, true, true } },
    [164510] = { name = "TOP - Shambling Arbalest", cc = { true, true, false, true, true } },
    [166524] = { name = "TOP - Deathwalker", cc = { true, true, true, true, true } },

    -- Motherlode
    [136470] = { name = "ML - Refreshment Vendor", cc = { true, true, true, true, true } },
    [134232] = { name = "ML - Hired Assassin", cc = { true, true, true, true, true } },
    [130488] = { name = "ML - Mech Jockey", cc = { true, true, true, true, true } },
    [130661] = { name = "ML - Venture Earthshaper", cc = { true, true, true, true, true } },
    [130635] = { name = "ML - Stonefury", cc = { true, true, true, true, true } },
    [129802] = { name = "ML - Earthrager", cc = { true, true, true, true, true } },
    [133432] = { name = "ML - Venture co Alchemist", cc = { true, true, true, true, true } },
    [133482] = { name = "ML - Crawler mine", cc = { true, false, false, true, false } },

    -- Fungal Folly
    [231385] = { name = "FL - Darkfuse Inspector", cc = { true, true, true, true, true } },
    [229069] = { name = "FL - Mechadrone Sniper", cc = { true, false, false, false, true } },
    [229212] = { name = "FL - Darkfuse Demolitionist", cc = { true, true, true, true, true } },
    [229686] = { name = "FL - Venture co Surveyor", cc = { true, true, true, true, true } },
    [231014] = { name = "FL - Loaderbot", cc = { true, false, false, false, false } },
    [231496] = { name = "FL - Venture co diver", cc = { true, true, true, true, true } },
    [231223] = { name = "FL - Disturbed kelp", cc = { true, true, true, true, true } },
    [231312] = { name = "FL - Venture co electrician", cc = { true, true, true, true, true } },

    -- Darkflame Cleft
    [211121] = { name = "DFC - Rank Overseer", cc = { false, false, false, true, false } },
    [210812] = { name = "DFC - Royal Wicklighter", cc = { true, true, true, true, true } },
    [210818] = { name = "DFC - Lowly Moleherd", cc = { true, true, true, true, true } },
    [212383] = { name = "DFC - Kobold taskworker", cc = { true, true, true, true, true } },
    [220815] = { name = "DFC - Blazing Fiend 2", cc = { true, true, true, true, true } },
    [223772] = { name = "DFC - Blazing Fiend", cc = { true, true, true, true, true } },
    [223773] = { name = "DFC - Blazing Fiend 3", cc = { true, true, true, true, true } },
    [211228] = { name = "DFC - Blazing Fiend 4", cc = { true, true, true, true, true } },
    [223774] = { name = "DFC - Blazing Fiend 5", cc = { false, false, false, false, false } },
    [223777] = { name = "DFC - Blazing Fiend 6", cc = { true, true, true, true, true } },
    [223770] = { name = "DFC - Blazing Fiend 7", cc = { false, false, false, false, false } },
    [223775] = { name = "DFC - Blazing Fiend 8", cc = { true, true, true, true, true } },
    [223776] = { name = "DFC - Blazing Fiend 9", cc = { true, true, true, true, true } },
    [213913] = { name = "DFC - Kobold flametender", cc = { true, true, true, true, true } },
    [208456] = { name = "DFC - Shuffling Horror", cc = { true, true, true, true, true } },
    [208457] = { name = "DFC - Skittering Darkness", cc = { true, true, true, true, true } },
    [210148] = { name = "DFC - Menial laborer", cc = { true, true, true, true, true } },
    [213008] = { name = "DFC - Wriggling darkspawn", cc = { true, true, true, true, true } },

    -- Cinderbrew Meadery
    [218671] = { name = "CBM - Venture Pyromaniac", cc = { true, true, true, true, true } },
    [214668] = { name = "CBM - Venture Patron", cc = { true, true, true, true, true } },
    [214673] = { name = "CBM - Flavor Scientist", cc = { true, true, true, true, true } },
    [220060] = { name = "CBM - Taste Tester", cc = { true, true, true, true, true } },
    [210264] = { name = "CBM - Bee wrangler", cc = { true, true, true, true, true } },
    [210265] = { name = "CBM - Worker bee", cc = { true, true, true, true, true } },
    [220141] = { name = "CBM - Royal jelly purveyor", cc = { true, true, true, true, true } },
    [218016] = { name = "CBM - Ravenour Cinderbee", cc = { true, true, true, true, true } },

    -- Priory of the Sacred Flame
    [206705] = { name = "PRIO - Arathi Footman", cc = { true, true, true, true, true } },
    [206697] = { name = "PRIO - Devout Priest", cc = { true, true, true, true, true } },
    [206698] = { name = "PRIO - Fanatical Conjuror", cc = { true, true, true, true, true } },
    [206699] = { name = "PRIO - War Lynx", cc = { true, true, true, true, false } },
    [207943] = { name = "PRIO - Arathi neophyte", cc = { true, true, true, true, true } },
    [221760] = { name = "PRIO - Risen Mage", cc = { true, true, false, true, true } },
}

-- Default spell configurations
addon.Database.defaultSpells = {
    -- Demon Hunter
    [179057] = { name = "DH - Chaos nova", ccType = "stun", priority = 1 },
    [207684] = { name = "DH - Sigil of misery", ccType = "fear", priority = 16 },
    [202138] = { name = "DH - Sigil of chains", ccType = "knock", priority = 17 },

    -- Death Knight
    [207167] = { name = "DK - blinding sleet", ccType = "disorient", priority = 8 },

    -- Druid
    [99] = { name = "Druid - Incapacitating roar", ccType = "incapacitate", priority = 14 },
    [132469] = { name = "Druid - typhoon", ccType = "knock", priority = 15 },

    -- Evoker
    [368970] = { name = "Evoker - Tail swipe", ccType = "knock", priority = 5 },
    [357214] = { name = "Evoker - Wing buffet", ccType = "knock", priority = 24 },

    -- Hunter
    [462031] = { name = "Hunter - explosive trap", ccType = "knock", priority = 22 },
    [186387] = { name = "Hunter - bursting shot", ccType = "knock", priority = 23 },

    -- Mage
    [157980] = { name = "Mage - Supernova", ccType = "knock", priority = 9 },
    [458513] = { name = "Mage - Gravity lapse", ccType = "knock", priority = 10 },
    [31661] = { name = "Mage - dragon's breath", ccType = "disorient", priority = 11 },
    [157981] = { name = "Mage - blast wave", ccType = "knock", priority = 12 },

    -- Monk
    [119381] = { name = "Monk - Leg sweep", ccType = "stun", priority = 4 },
    [116844] = { name = "Monk - Ring of peace", ccType = "knock", priority = 18 },

    -- Paladin
    [115750] = { name = "Paladin - blinding light", ccType = "disorient", priority = 13 },

    -- Priest
    [8122] = { name = "Priest - Psychic scream", ccType = "fear", priority = 7 },

    -- Rogue
    [2094] = { name = "Rogue - Blind", ccType = "disorient", priority = 21 },

    -- Shaman
    [51490] = { name = "Shaman - Thunderstorm", ccType = "knock", priority = 2 },
    [192058] = { name = "Shaman - Incap totem", ccType = "stun", priority = 3 },

    -- Warlock
    [30283] = { name = "Warlock - Shadowfury", ccType = "stun", priority = 20 },

    -- Warrior
    [46968] = { name = "Warrior - Shockwave", ccType = "stun", priority = 6 },
    [5246] = { name = "Warrior - Intimidating shout", ccType = "fear", priority = 19 },
}

-- Convert CC array to effectiveness map
function addon.Database:BuildNPCEffectiveness()
    local effectiveness = {}

    for npcID, data in pairs(self.defaultNPCs) do
        effectiveness[npcID] = {
            stun = data.cc[1],
            disorient = data.cc[2],
            fear = data.cc[3],
            knock = data.cc[4],
            incapacitate = data.cc[5],
        }
    end

    return effectiveness
end

-- Get NPC info from current target
function addon.Database:GetTargetNPCInfo()
    if not UnitExists("target") or UnitIsPlayer("target") then
        return nil
    end

    local guid = UnitGUID("target")
    if not guid then
        return nil
    end

    local npcID = tonumber(guid:match("-(%d+)-%x+$"))
    local npcName = UnitName("target")

    if npcID and npcName then
        return {
            id = npcID,
            name = npcName,
            exists = self.defaultNPCs[npcID] ~= nil
        }
    end

    return nil
end

-- Search for NPCs by name (fuzzy matching)
function addon.Database:SearchNPCsByName(searchTerm)
    if not searchTerm or searchTerm == "" then
        return {}
    end

    local results = {}
    local searchLower = searchTerm:lower()

    -- Search database NPCs
    for npcID, data in pairs(self.defaultNPCs) do
        local name = data.name:lower()
        if name:find(searchLower, 1, true) then
            table.insert(results, {
                id = npcID,
                name = data.name,
                source = "database"
            })
        end
    end

    -- Search custom NPCs if Config is available
    if addon.Config and addon.Config.db then
        for npcID, data in pairs(addon.Config.db.customNPCs) do
            local name = data.name:lower()
            if name:find(searchLower, 1, true) then
                table.insert(results, {
                    id = npcID,
                    name = data.name,
                    source = "custom"
                })
            end
        end
    end

    -- Sort by relevance (exact matches first, then by name)
    table.sort(results, function(a, b)
        local aExact = a.name:lower() == searchLower
        local bExact = b.name:lower() == searchLower
        if aExact ~= bExact then
            return aExact
        end
        return a.name < b.name
    end)

    return results
end

-- Check if NPC exists in database or custom NPCs
function addon.Database:NPCExists(npcID)
    if self.defaultNPCs[npcID] then
        return true, "database"
    end

    if addon.Config and addon.Config.db and addon.Config.db.customNPCs[npcID] then
        return true, "custom"
    end

    return false, nil
end

-- Get NPC info by ID from database or custom
function addon.Database:GetNPCInfo(npcID)
    if self.defaultNPCs[npcID] then
        return {
            id = npcID,
            name = self.defaultNPCs[npcID].name,
            cc = self.defaultNPCs[npcID].cc,
            source = "database"
        }
    end

    if addon.Config and addon.Config.db and addon.Config.db.customNPCs[npcID] then
        local customNPC = addon.Config.db.customNPCs[npcID]
        return {
            id = npcID,
            name = customNPC.name,
            cc = customNPC.cc,
            source = "custom",
            dungeon = customNPC.dungeon
        }
    end

    return nil
end

-- Get current dungeon/instance information
function addon.Database:GetCurrentDungeonInfo()
    local name, instanceType, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()

    -- Only consider party dungeons and raids
    if instanceType ~= "party" and instanceType ~= "raid" then
        return nil, nil, instanceType
    end

    if not name or name == "" then
        return nil, nil, instanceType
    end

    -- Try to match against our known dungeons
    for abbrev, fullName in pairs(self.dungeonNames) do
        if name == fullName then
            return abbrev, fullName, instanceType
        end
    end

    -- Check for partial matches (in case of different naming)
    local nameLower = name:lower()
    for abbrev, fullName in pairs(self.dungeonNames) do
        local fullNameLower = fullName:lower()
        if nameLower:find(fullNameLower, 1, true) or fullNameLower:find(nameLower, 1, true) then
            return abbrev, fullName, instanceType
        end
    end

    -- Return the raw name if not in our database (unknown dungeon)
    return nil, name, instanceType
end

-- Get NPCs that belong to the current dungeon
function addon.Database:GetCurrentDungeonNPCs()
    local abbrev, dungeonName, instanceType = self:GetCurrentDungeonInfo()
    if not dungeonName then
        return {}
    end

    local dungeonNPCs = {}

    -- Get database NPCs for this dungeon
    for npcID, data in pairs(self.defaultNPCs) do
        local npcAbbrev, npcDungeon, mobName = self:ExtractDungeonInfo(data.name)
        if npcDungeon == dungeonName then
            dungeonNPCs[npcID] = {
                id = npcID,
                name = data.name,
                mobName = mobName,
                cc = data.cc,
                source = "database"
            }
        end
    end

    -- Get custom NPCs for this dungeon
    if addon.Config and addon.Config.db then
        for npcID, data in pairs(addon.Config.db.customNPCs) do
            local npcAbbrev, npcDungeon, mobName = self:ExtractDungeonInfo(data.name)
            -- Check both name-based detection and explicit dungeon field
            if npcDungeon == dungeonName or data.dungeon == dungeonName then
                dungeonNPCs[npcID] = {
                    id = npcID,
                    name = data.name,
                    mobName = mobName,
                    cc = data.cc,
                    source = "custom",
                    dungeon = data.dungeon
                }
            end
        end
    end

    return dungeonNPCs
end

-- Check if we're currently in a dungeon that has NPCs in our database
function addon.Database:IsInKnownDungeon()
    local abbrev, dungeonName, instanceType = self:GetCurrentDungeonInfo()
    return dungeonName ~= nil and abbrev ~= nil
end
