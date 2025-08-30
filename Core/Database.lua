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
    "Ara-Kara, City of Echoes", {
        [434793] = { name = "Resonant Barrage", npcName = "Trilling Attendant", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [448248] = { name = "Revolting Volley", npcName = "Bloodstained Webmage", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [432967] = { name = "Alarm Shrill", npcName = "Sentry Stagshell", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    },

    "Eco-dome Al'dani", {
        [1229474] = { name = "Gorge", npcName = "Overgorged Mite", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [1229510] = { name = "Arcing Zap", npcName = "Wastelander Farstalker", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [1222815] = { name = "Arcane Bolt", npcName = "Wastelander Ritualist", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    },

    "Halls of Atonement", {
        [326450] = { name = "Loyal Beasts", npcName = "Depraved Houndmaster", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [326661] = { name = "Wicked Bolt", npcName = "Depraved Obliterator", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [325701] = { name = "Siphon life", npcName = "Depraved Collector", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    },

    "The Dawnbreaker", {
        [431303] = { name = "Night bolt", npcName = "Nightfall Shadowmage", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [431333] = { name = "Tormenting Beam", npcName = "Nightfall Darkcaster", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [452099] = { name = "Congealed Darkness", npcName = "Animated Shadow", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    },

    "Priory of the Sacred Flame", {
        [427342] = { name = "Defend", npcName = "Arathi Footman", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [427357] = { name = "Holy Smite", npcName = "Devout Priest", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [427356] = { name = "Greater Heal", npcName = "Devout Priest", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [427469] = { name = "Fireball", npcName = "Fanatical Conjuror", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [427496] = { name = "Fireball", npcName = "Risen Mage", ccTypes = {"stun", "disorient", "knock", "incapacitate"} },
        [444743] = { name = "Fireball Volley", npcName = "Risen Mage", ccTypes = {"stun", "disorient", "knock", "incapacitate"} },
    },

    "Operation: Floodgate", {
        [462771] = { name = "Surveying Beam", npcName = "Venture Co. Surveyor", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [465127] = { name = "Wind up", npcName = "Loaderbot", ccTypes = {"stun"} },
        [468631] = { name = "Harpoon", npcName = "Venture Co. Diver", ccTypes = {"stun"} },
        [471736] = { name = "Jettison Kelp", npcName = "Disturbed Kelp", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [471733] = { name = "Restorative Algae", npcName = "Disturbed Kelp", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [461796] = { name = "Reload", npcName = "Darkfuse Demolitionist", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
        [465595] = { name = "Lightning Bolt", npcName = "Venture Co. Electrician", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    },

    "Tazavesh: Streets of Wonder", {
        [354297] = { name = "Hyperlight Bolt", npcName = "Support Officer", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    },

    -- For testing
    "The Rookery", {
        [430109] = { name = "Lightning Bolt", npcName = "Cursed Thunderer", ccTypes = {"stun", "disorient", "fear", "knock", "incapacitate"} },
    }
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
    [449700] = { name = "Gravity lapse", ccType = "stun", priority = 10, active = true, source = "database" },
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

-- Initialize flattened lookup table for efficient access
function addon.Database:InitializeDangerousCastsLookup()
    if not self.dangerousCastsLookup then
        self.dangerousCastsLookup = {}
        
        -- Flatten the dungeon-grouped structure into a simple lookup table
        local i = 1
        while i <= #self.dangerousCasts do
            local entry = self.dangerousCasts[i]
            
            -- Skip dungeon names (strings)
            if type(entry) == "string" then
                -- Check if the next entry is the spell table for this dungeon
                if i + 1 <= #self.dangerousCasts and type(self.dangerousCasts[i + 1]) == "table" then
                    local spellTable = self.dangerousCasts[i + 1]
                    for spellID, castData in pairs(spellTable) do
                        if type(spellID) == "number" and type(castData) == "table" then
                            self.dangerousCastsLookup[spellID] = castData
                        end
                    end
                    i = i + 2 -- Skip both dungeon name and spell table
                else
                    i = i + 1 -- Just skip dungeon name if no spell table follows
                end
            else
                i = i + 1 -- Skip any other entries
            end
        end
    end
end

-- Check if a spell is a dangerous cast
function addon.Database:IsDangerousCast(spellID)
    self:InitializeDangerousCastsLookup()
    return self.dangerousCastsLookup[spellID] ~= nil
end

-- Get dangerous cast info
function addon.Database:GetDangerousCast(spellID)
    self:InitializeDangerousCastsLookup()
    return self.dangerousCastsLookup[spellID]
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
    
    self:InitializeDangerousCastsLookup()
    
    local results = {}
    local searchLower = searchTerm:lower()
    
    -- Search through flattened lookup table
    for spellID, data in pairs(self.dangerousCastsLookup) do
        if data.name then
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