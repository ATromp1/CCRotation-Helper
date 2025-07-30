local addonName, addon = ...

-- Load Ace3 libraries for configuration
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0") 
local AceDB = LibStub("AceDB-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

addon.Config = {}

-- Font utility function using LibSharedMedia
function addon.Config:SetFontProperties(fontString, fontName, fontSize, flags)
    if LSM then
        local fontPath = LSM:Fetch("font", fontName)
        if fontPath then
            fontString:SetFont(fontPath, fontSize, flags or "OUTLINE")
        else
            -- Fallback to default WoW font
            fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize, flags or "OUTLINE")
        end
    else
        -- Fallback if LSM not available
        fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize, flags or "OUTLINE")
    end
end

-- Default configuration
local defaults = {
    profile = {
        enabled = true,
        showInSolo = false,
        maxIcons = 2,
        iconSize = 64,
        iconSize1 = 64,
        iconSize2 = 32,
        iconSize3 = 32,
        iconSize4 = 32,
        iconSize5 = 32,
        spacing = 3,
        growDirection = "RIGHT",
        
        -- Unavailable queue settings
        showUnavailableQueue = true,
        maxUnavailableIcons = 3,
        unavailableIconSize = 24,
        unavailableSpacing = 2,
        unavailableQueueOffset = 5,
        
        -- Position
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER", 
        xOffset = 354,
        yOffset = 134,
        
        -- Display options
        showSpellName = true,
        showPlayerName = true,
        showCooldownText = true,
        showTooltips = true,
        highlightNext = false,
        cooldownDecimalThreshold = 3,
        
        -- Individual icon text display (defaults: only main icon shows text)
        showSpellName1 = true,
        showSpellName2 = false,
        showSpellName3 = false,
        showSpellName4 = false,
        showSpellName5 = false,
        showPlayerName1 = true,
        showPlayerName2 = false,
        showPlayerName3 = false,
        showPlayerName4 = false,
        showPlayerName5 = false,
        
        -- Fonts (LibSharedMedia names)
        spellNameFont = "Friz Quadrata TT",
        spellNameFontSize = 12,
        spellNameMaxLength = 20,
        playerNameFont = "Friz Quadrata TT", 
        playerNameFontSize = 12,
        playerNameMaxLength = 15,
        cooldownFont = "Friz Quadrata TT",
        cooldownFontSize = 16,
        cooldownFontSizePercent = 25,
        
        -- Colors
        nextSpellGlow = {0.91, 1.0, 0.37, 1.0},
        cooldownTextColor = {0.91, 1.0, 0.37, 1.0},
        spellNameColor = {1.0, 1.0, 1.0, 1.0},
        
        -- Priority players
        priorityPlayers = {
            ["Fúro"] = true,
        },
        
        -- Custom NPCs and spells (empty by default, uses database)
        customNPCs = {},
        customSpells = {},
        inactiveSpells = {}, -- Spells that are disabled but not deleted
        
        -- Sound options
        enableSounds = false,
        nextSpellSound = "Interface\\AddOns\\CCRotation\\Sounds\\next.ogg",
        
        -- Anchor settings
        anchorLocked = true,
    }
}

function addon.Config:Initialize()
    -- Initialize saved variables
    if not CCRotationDB then
        CCRotationDB = {}
    end
    
    -- Merge defaults with saved data
    self:MergeDefaults(CCRotationDB, defaults)
    
    -- Reference to current profile
    self.db = CCRotationDB.profile
end

function addon.Config:MergeDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                self:MergeDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            self:MergeDefaults(target[key], value)
        end
    end
end

function addon.Config:Get(key)
    return self.db[key]
end

function addon.Config:Set(key, value)
    self.db[key] = value
end

function addon.Config:GetNPCEffectiveness(npcID)
    -- Check custom NPCs first
    if self.db.customNPCs[npcID] then
        local customNPC = self.db.customNPCs[npcID]
        -- Convert array format to map format for consistency
        return {
            stun = customNPC.cc[1],
            disorient = customNPC.cc[2],
            fear = customNPC.cc[3],
            knock = customNPC.cc[4],
            incapacitate = customNPC.cc[5],
        }
    end
    
    -- Fall back to database
    local dbNPCs = addon.Database:BuildNPCEffectiveness()
    return dbNPCs[npcID]
end

function addon.Config:GetSpellInfo(spellID)
    -- Check custom spells first
    if self.db.customSpells[spellID] then
        return self.db.customSpells[spellID]
    end
    
    -- Fall back to database
    return addon.Database.defaultSpells[spellID]
end

function addon.Config:GetTrackedSpells()
    local spells = {}
    
    -- Add database spells (if not inactive)
    for spellID, data in pairs(addon.Database.defaultSpells) do
        if not self.db.inactiveSpells[spellID] then
            spells[spellID] = {
                priority = data.priority,
                type = addon.Database.ccTypeLookup[data.ccType]
            }
        end
    end
    
    -- Override with custom spells (if not inactive)
    for spellID, data in pairs(self.db.customSpells) do
        if not self.db.inactiveSpells[spellID] then
            spells[spellID] = {
                priority = data.priority,
                type = addon.Database.ccTypeLookup[data.ccType]
            }
        end
    end
    
    return spells
end

function addon.Config:IsPriorityPlayer(playerName)
    return self.db.priorityPlayers[playerName] == true
end

function addon.Config:AddPriorityPlayer(playerName)
    self.db.priorityPlayers[playerName] = true
end

function addon.Config:RemovePriorityPlayer(playerName)
    self.db.priorityPlayers[playerName] = nil
end
