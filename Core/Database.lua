local addonName, addon = ...

-- Database of dangerous casts and spell configurations
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

-- Casts that should be stopped with CC abilities
addon.Database.dangerousCasts = {
    -- Ara-Kara, City of Echoes
    [438622] = { name = "Impale", npcName = "Trilling Attendant", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [438476] = { name = "Web Wrap", npcName = "Bloodstained Webmage", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [438787] = { name = "Burrow Charge", npcName = "Sentry Stagshell", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },

    -- TESTING IN ROOKERY
    [430109] = { name = "Lightning Bolt", npcName = "Cursed Thunderer", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },

    -- The Dawnbreaker
    [431309] = { name = "Dark Orb", npcName = "Nightfall Shadowmage", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [430735] = { name = "Shadow Bolt", npcName = "Nightfall Darkcaster", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [426883] = { name = "Animate Shadow", npcName = "Nightfall Commander", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },

    -- Priory of the Sacred Flame
    [427583] = { name = "Consecration", npcName = "Devout Priest", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [448515] = { name = "Fireball", npcName = "Fanatical Conjuror", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [427001] = { name = "Holy Radiance", npcName = "Arathi Priest", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },

    -- Operation Floodgate
    [462373] = { name = "Survey", npcName = "Venture Co. Surveyor", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [463428] = { name = "Explosive Shot", npcName = "Mechadrone Sniper", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    [463457] = { name = "Repair Protocol", npcName = "Loaderbot", ccTypes = {"stun"} },
}

-- Default spell configurations - unified format
addon.Database.defaultSpells = {
    -- Demon Hunter
    [179057] = { name = "Chaos nova", ccType = "stun", priority = 1, active = true, source = "database" },
    [207684] = { name = "Misery", ccType = "fear", priority = 16, active = true, source = "database" },
    [202138] = { name = "Chains", ccType = "knock", priority = 17, active = true, source = "database" },

    -- Death Knight
    [207167] = { name = "Sleet", ccType = "disorient", priority = 8, active = true, source = "database" },

    -- Druid
    [99] = { name = "Roar", ccType = "incapacitate", priority = 14, active = true, source = "database" },
    [132469] = { name = "Typhoon", ccType = "knock", priority = 15, active = true, source = "database" },

    -- Evoker
    [368970] = { name = "Tail swipe", ccType = "knock", priority = 5, active = true, source = "database" },
    [357214] = { name = "Wing buffet", ccType = "knock", priority = 24, active = true, source = "database" },

    -- Hunter
    [462031] = { name = "Explosive trap", ccType = "knock", priority = 22, active = true, source = "database" },
    [186387] = { name = "Bursting shot", ccType = "knock", priority = 23, active = true, source = "database" },

    -- Mage
    [157980] = { name = "Supernova", ccType = "knock", priority = 9, active = true, source = "database" },
    [449700] = { name = "Gravity lapse", ccType = "knock", priority = 10, active = true, source = "database" },
    [31661] = { name = "DB", ccType = "disorient", priority = 11, active = true, source = "database" },
    [157981] = { name = "Blastwave", ccType = "knock", priority = 12, active = true, source = "database" },

    -- Monk
    [119381] = { name = "Sweep", ccType = "stun", priority = 4, active = true, source = "database" },
    [116844] = { name = "Ring of peace", ccType = "knock", priority = 18, active = true, source = "database" },

    -- Paladin
    [115750] = { name = "Blinding light", ccType = "disorient", priority = 13, active = true, source = "database" },

    -- Priest
    [8122] = { name = "Fear", ccType = "fear", priority = 7, active = true, source = "database" },

    -- Rogue
    [2094] = { name = "Blind", ccType = "disorient", priority = 21, active = true, source = "database" },

    -- Shaman
    [51490] = { name = "Thunderstorm", ccType = "knock", priority = 2, active = true, source = "database" },
    [192058] = { name = "Incap", ccType = "stun", priority = 3, active = true, source = "database" },

    -- Warlock
    [30283] = { name = "Shadowfury", ccType = "stun", priority = 20, active = true, source = "database" },

    -- Warrior
    [46968] = { name = "Shockwave", ccType = "stun", priority = 6, active = true, source = "database" },
    [5246] = { name = "Fear", ccType = "fear", priority = 19, active = true, source = "database" },
}

-- Check if a spell is a dangerous cast
function addon.Database:IsDangerousCast(spellID)
    return self.dangerousCasts[spellID] ~= nil
end

-- Get dangerous cast info
function addon.Database:GetDangerousCast(spellID)
    return self.dangerousCasts[spellID]
end

-- Get NPC info from current target (legacy method for UI compatibility)
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
            exists = false -- No longer tracking NPCs, always false
        }
    end
    
    return nil
end

-- Get current dungeon/instance information
function addon.Database:GetCurrentDungeonInfo()
    local name, instanceType, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()
    
    -- Only consider party dungeons and raids
    if instanceType ~= "party" and instanceType ~= "raid" then
        return nil, instanceType or "none", false
    end
    
    if not name or name == "" then
        return nil, instanceType or "none", false
    end
    
    -- Check if we have dangerous casts for this dungeon (simplified check)
    local hasKnownCasts = false
    for spellID, castData in pairs(self.dangerousCasts) do
        -- For now, consider any dungeon with casts as "known"
        hasKnownCasts = true
        break
    end
    
    -- Return dungeon name, instance type, and whether it has known dangerous casts
    return name, instanceType, hasKnownCasts
end

-- Search for dangerous casts by name (fuzzy matching)
function addon.Database:SearchDangerousCastsByName(searchTerm)
    if not searchTerm or searchTerm == "" then
        return {}
    end
    
    local results = {}
    local searchLower = searchTerm:lower()
    
    -- Search dangerous casts
    for spellID, data in pairs(self.dangerousCasts) do
        local name = data.name:lower()
        if name:find(searchLower, 1, true) then
            table.insert(results, {
                spellID = spellID,
                name = data.name,
                npcName = data.npcName,
                ccTypes = data.ccTypes
            })
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