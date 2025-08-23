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
addon.Database.ccTypeOrder = {"stun", "disorient", "fear", "knock", "incapacitate"}

-- Spell ID mappings for alternative cast IDs
-- Maps cast spell IDs to their base tracking IDs
-- The cooldown will be taken from the cast spell's database entry
-- Format: [castSpellID] = baseSpellID
addon.Database.spellIDMappings = {
    -- Druid - Typhoon (cast ID maps to base ID)
    [61391] = 132469,   -- Typhoon cast → Typhoon base
    
    -- Mage - Gravity Lapse (cast as 449700, track as 157980, use 449700's cooldown)
    --[449700] = 157980,  -- Gravity Lapse cast → Supernova base (40s cooldown from 449700 entry)
}

-- Default NPC configurations for Season 1 Mythic+
addon.Database.defaultNPCs = {
    -- Ara-Kara, City of Echoes
    [216293] = { name = "Trilling Attendant", dungeon = "Ara-Kara, City of Echoes", cc = {true, true, true, true, true} },
    [223253] = { name = "Bloodstained Webmage", dungeon = "Ara-Kara, City of Echoes", cc = {true, true, true, true, true} },
    [216340] = { name = "Sentry Stagshell", dungeon = "Ara-Kara, City of Echoes", cc = {true, true, true, true, true} },

    -- The Dawnbreaker
    [213892] = { name = "Nightfall Shadowmage", dungeon = "The Dawnbreaker", cc = {true, true, true, true, true} },
    [213893] = { name = "Nightfall Darkcaster", dungeon = "The Dawnbreaker", cc = {true, true, true, true, true} },
    [224616] = { name = "Animated Shadow", dungeon = "The Dawnbreaker", cc = {true, true, true, true, true} },

    -- Priory of the Sacred Flame
    [206705] = { name = "Arathi Footman", dungeon = "Priory of the Sacred Flame", cc = {true, true, true, true, true} },
    [206697] = { name = "Devout Priest", dungeon = "Priory of the Sacred Flame", cc = {true, true, true, true, true} },
    [206698] = { name = "Fanatical Conjuror", dungeon = "Priory of the Sacred Flame", cc = {true, true, true, true, true} },
    [206699] = { name = "War Lynx", dungeon = "Priory of the Sacred Flame", cc = {true, true, true, true, false} },
    [207943] = { name = "Arathi neophyte", dungeon = "Priory of the Sacred Flame", cc = {true, true, true, true, true} },
    [221760] = { name = "Risen Mage", dungeon = "Priory of the Sacred Flame", cc = {true, true, false, true, true} },

    -- Operation Floodgate
    [229686] = { name = "Venture Co. Surveyor", dungeon = "Operation Floodgate", cc = {true, true, true, true, true} },
    [229252] = { name = "Darkfuse Hyena", dungeon = "Operation Floodgate", cc = {true, true, true, true, false} },
    [231014] = { name = "Loaderbot", dungeon = "Operation Floodgate", cc = {true, false, false, false, false} },
    [229069] = { name = "Mechadrone Sniper", dungeon = "Operation Floodgate", cc = {true, true, false, true, false} },
    [231496] = { name = "Venture Co. Diver", dungeon = "Operation Floodgate", cc = {true, true, true, true, true} },
    [229212] = { name = "Darkfuse Demolitionist", dungeon = "Operation Floodgate", cc = {true, true, true, true, true} },
    [231223] = { name = "Disturbed Kelp", dungeon = "Operation Floodgate", cc = {true, true, true, true, true} },
    [231312] = { name = "Venture Co. Electrician", dungeon = "Operation Floodgate", cc = {true, true, true, true, true} },

    -- Eco-Dome Al'dani
    [234883] = { name = "Voracious Gorger", dungeon = "Eco-Dome Al'dani", cc = {true, true, true, true, true} },
    [242209] = { name = "Overgorged Mite", dungeon = "Eco-Dome Al'dani", cc = {true, true, true, true, true} },
    [234962] = { name = "Wastelander Farstalker", dungeon = "Eco-Dome Al'dani", cc = {true, true, true, true, true} },
    [234957] = { name = "Wastelander Ritualist", dungeon = "Eco-Dome Al'dani", cc = {true, true, true, true, true} },

    -- Halls of Atonement
    [164562] = { name = "Depraved Houndmaster", dungeon = "Halls of Atonement", cc = {true, true, true, true, true} },
    [165414] = { name = "Depraved Obliterator", dungeon = "Halls of Atonement", cc = {true, true, true, true, true} },
    [165529] = { name = "Depraved Collector", dungeon = "Halls of Atonement", cc = {true, true, true, true, true} },

    -- Tazavesh Streets
    [177817] = { name = "Support Officer", dungeon = "Tazavesh Streets", cc = {true, true, true, true, true} },
    [179840] = { name = "Market Peacekeeper", dungeon = "Tazavesh Streets", cc = {true, true, true, true, true} },
    [179841] = { name = "Veteran Sparkcaster", dungeon = "Tazavesh Streets", cc = {true, true, true, true, true} },
    [176395] = { name = "Overloaded Mailemental", dungeon = "Tazavesh Streets", cc = {true, true, true, true, true} },
    [176396] = { name = "Defective Sorter", dungeon = "Tazavesh Streets", cc = {true, true, true, true, true} },

    -- Tazavesh Gambit
    [178139] = { name = "Murkbrine Shellcrusher", dungeon = "Tazavesh Gambit", cc = {true, true, true, true, true} },
    [178142] = { name = "Murkbrine Fishmancer", dungeon = "Tazavesh Gambit", cc = {true, true, true, true, true} },
    [176551] = { name = "Vault Purifier", dungeon = "Tazavesh Gambit", cc = {true, true, true, true, true} },
    [179388] = { name = "Hourglass Tidesage", dungeon = "Tazavesh Gambit", cc = {true, true, true, true, true} },
    [180015] = { name = "Burly Deckhand", dungeon = "Tazavesh Gambit", cc = {true, true, true, true, true} },
    [180431] = { name = "Focused Ritualist", dungeon = "Tazavesh Gambit", cc = {true, true, true, true, true} },
}

-- Resolve spell ID using mappings (returns base spell ID for tracking)
function addon.Database:ResolveSpellID(castSpellID)
    return self.spellIDMappings[castSpellID] or castSpellID
end

-- Get spell data for combat log processing
-- Returns: baseSpellData (for validation), baseSpellID (for tracking), castSpellCooldown (for duration)
function addon.Database:GetSpellData(castSpellID)
    local baseSpellID = self:ResolveSpellID(castSpellID)
    local baseSpellData = self.defaultSpells[baseSpellID]
    local castSpellData = self.defaultSpells[castSpellID]
    
    -- Use the cast spell's cooldown if available (e.g., Gravity Lapse = 40s), otherwise use base spell's cooldown
    local castSpellCooldown = castSpellData and castSpellData.baseCooldown or (baseSpellData and baseSpellData.baseCooldown)
    
    return baseSpellData, baseSpellID, castSpellCooldown
end

-- Default spell configurations - unified format
addon.Database.defaultSpells = {
    -- Demon Hunter
    [179057] = { name = "Chaos nova", ccType = "stun", priority = 1, active = true, source = "database", class = "DEMONHUNTER", baseCooldown = 45 },
    [207684] = { name = "Misery", ccType = "fear", priority = 16, active = true, source = "database", class = "DEMONHUNTER", baseCooldown = 120 },
    [202138] = { name = "Chains", ccType = "knock", priority = 17, active = true, source = "database", class = "DEMONHUNTER", baseCooldown = 60 },

    -- Death Knight
    [207167] = { name = "Sleet", ccType = "disorient", priority = 8, active = true, source = "database", class = "DEATHKNIGHT", baseCooldown = 60 },

    -- Druid
    [99] = { name = "Roar", ccType = "incapacitate", priority = 10, active = true, source = "database", class = "DRUID", baseCooldown = 30 },
    [132469] = { name = "Typhoon", ccType = "knock", priority = 15, active = true, source = "database", class = "DRUID", baseCooldown = 30 },
    [61391] = { name = "Typhoon", ccType = "knock", priority = 15, active = true, source = "database", class = "DRUID", baseCooldown = 30 }, -- Alternative ID

    -- Evoker
    [368970] = { name = "Tail swipe", ccType = "knock", priority = 5, active = true, source = "database", class = "EVOKER", baseCooldown = 180 },
    [357214] = { name = "Wing buffet", ccType = "knock", priority = 24, active = true, source = "database", class = "EVOKER", baseCooldown = 180 },

    -- Hunter
    [462031] = { name = "Explosive trap", ccType = "knock", priority = 22, active = true, source = "database", class = "HUNTER", baseCooldown = 60 },
    [186387] = { name = "Bursting shot", ccType = "knock", priority = 23, active = true, source = "database", class = "HUNTER", baseCooldown = 30 },

    -- Mage
    [157980] = { name = "Supernova", ccType = "knock", priority = 9, active = true, source = "database", class = "MAGE", baseCooldown = 45, talent = 157980 },
    [449700] = { name = "Gravity lapse", ccType = "knock", priority = 10, active = true, source = "database", class = "MAGE", baseCooldown = 40, talent = 458513 },
    [31661] = { name = "DB", ccType = "disorient", priority = 11, active = true, source = "database", class = "MAGE", baseCooldown = 45, talent = 31661 },
    [157981] = { name = "Blastwave", ccType = "knock", priority = 12, active = true, source = "database", class = "MAGE", baseCooldown = 30 },

    -- Monk
    [119381] = { name = "Sweep", ccType = "stun", priority = 4, active = true, source = "database", class = "MONK", baseCooldown = 60 },
    [116844] = { name = "Ring of peace", ccType = "knock", priority = 18, active = true, source = "database", class = "MONK", baseCooldown = 45 },

    -- Paladin
    [115750] = { name = "Blinding light", ccType = "disorient", priority = 13, active = true, source = "database", class = "PALADIN", baseCooldown = 90 },

    -- Priest
    [8122] = { name = "Fear", ccType = "fear", priority = 7, active = true, source = "database", class = "PRIEST", baseCooldown = 45 },

    -- Rogue
    [2094] = { name = "Blind", ccType = "disorient", priority = 21, active = true, source = "database", class = "ROGUE", baseCooldown = 60 },

    -- Shaman
    [51490] = { name = "Thunderstorm", ccType = "knock", priority = 2, active = true, source = "database", class = "SHAMAN", baseCooldown = 30 },
    [192058] = { name = "Incap", ccType = "stun", priority = 3, active = true, source = "database", class = "SHAMAN", baseCooldown = 60 },

    -- Warlock
    [30283] = { name = "Shadowfury", ccType = "stun", priority = 20, active = true, source = "database", class = "WARLOCK", baseCooldown = 60 },

    -- Warrior
    [46968] = { name = "Shockwave", ccType = "stun", priority = 6, active = true, source = "database", class = "WARRIOR", baseCooldown = 40 },
    [5246] = { name = "Fear", ccType = "fear", priority = 19, active = true, source = "database", class = "WARRIOR", baseCooldown = 90, talent = 5246 }, -- Intimidating Shout talent
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
        return nil, instanceType
    end
    
    if not name or name == "" then
        return nil, instanceType
    end
    
    -- Return dungeon name and instance type
    return name, instanceType
end

-- Get NPCs that belong to the current dungeon
function addon.Database:GetCurrentDungeonNPCs()
    local dungeonName, instanceType = self:GetCurrentDungeonInfo()
    if not dungeonName then
        return {}
    end
    
    local dungeonNPCs = {}
    
    -- Get database NPCs for this dungeon
    for npcID, data in pairs(self.defaultNPCs) do
        if data.dungeon == dungeonName then
            dungeonNPCs[npcID] = {
                id = npcID,
                name = data.name,
                cc = data.cc,
                source = "database",
                dungeon = data.dungeon
            }
        end
    end
    
    -- Get custom NPCs for this dungeon
    if addon.Config and addon.Config.db then
        for npcID, data in pairs(addon.Config.db.customNPCs) do
            if data.dungeon == dungeonName then
                dungeonNPCs[npcID] = {
                    id = npcID,
                    name = data.name,
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
    local dungeonName, instanceType = self:GetCurrentDungeonInfo()
    if not dungeonName then
        return false
    end
    
    -- Check if we have any NPCs for this dungeon
    for npcID, data in pairs(self.defaultNPCs) do
        if data.dungeon == dungeonName then
            return true
        end
    end
    
    -- Check custom NPCs too
    if addon.Config and addon.Config.db then
        for npcID, data in pairs(addon.Config.db.customNPCs) do
            if data.dungeon == dungeonName then
                return true
            end
        end
    end
    
    return false
end
