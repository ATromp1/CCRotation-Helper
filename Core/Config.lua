local addonName, addon = ...

-- Load Ace3 libraries for configuration
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0") 
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
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
        -- Priority players (profile-specific)
        priorityPlayers = {
            ["Fúro"] = true,
        },
        
        -- Custom NPCs and spells (profile-specific)
        customNPCs = {},
        customSpells = {},
        inactiveSpells = {}, -- Spells that are disabled but not deleted
    },
    global = {
        -- Core addon settings
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
        
        -- Sound options
        enableSounds = false,
        nextSpellSound = "Interface\\AddOns\\CCRotation\\Sounds\\next.ogg",
        
        -- Anchor settings
        anchorLocked = false,
        
        -- Minimap icon settings
        minimap = {
            minimapPos = 220,
            radius = 80,
        },
        
        -- Icon zoom multiplier (texture zoom within container, like WeakAuras)
        iconZoom = 1.0,
        
        -- Debug mode
        debugMode = true,
    }
}

function addon.Config:Initialize()
    -- Initialize AceDB with profile support
    self.database = AceDB:New("CCRotationDB", defaults, true)
    
    -- Reference to current profile data and global data
    self.db = self.database.profile
    self.global = self.database.global
    
    -- Set up profile change callback
    self.database.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.database.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.database.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    
    -- Set up AceDBOptions for profile management
    self.profileOptions = AceDBOptions:GetOptionsTable(self.database)
    
    -- Register profile options with AceConfig
    AceConfig:RegisterOptionsTable("CCRotationHelper_Profiles", self.profileOptions)
end


-- Called when profile changes (switch, copy, reset)
function addon.Config:OnProfileChanged()
    local newProfile = self.database:GetCurrentProfile()
    print("|cff00ff00CC Rotation Helper:|r Profile changed to:", newProfile)
    
    -- Update reference to current profile
    self.db = self.database.profile

    -- Notify rotation system to update tracked spells
    if addon.CCRotation then
        self:DebugPrint("Updating tracked spells and rebuilding queue...")
        addon.CCRotation.trackedCooldowns = self:GetTrackedSpells()
        if addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
            self:DebugPrint("Queue rebuilt successfully")
        else
            print("|cffff0000CC Rotation Helper:|r Warning: RebuildQueue function not found")
        end
    else
        print("|cffff0000CC Rotation Helper:|r Warning: CCRotation not initialized")
    end
    
    -- Notify UI to refresh
    if addon.UI then
        addon.UI:UpdateFromConfig()
        self:DebugPrint("UI refreshed")
    end
    
    -- If we're the party leader, broadcast the profile change
    if addon.ProfileSync and UnitIsGroupLeader("player") and IsInGroup() then
        -- Delay broadcast slightly to allow profile switch to complete
        C_Timer.After(0.5, function()
            addon.ProfileSync:BroadcastProfileAsLeader()
        end)
    end
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
    -- Check profile settings first, then global settings
    if self.db[key] ~= nil then
        return self.db[key]
    end
    return self.global[key]
end

function addon.Config:Set(key, value)
    -- Determine if this is a profile-specific or global setting
    if self:IsProfileSetting(key) then
        self.db[key] = value
    else
        self.global[key] = value
    end
end

-- Helper function to determine if a setting belongs to profile or global
function addon.Config:IsProfileSetting(key)
    local profileSettings = {
        "priorityPlayers",
        "customNPCs", 
        "customSpells",
        "inactiveSpells"
    }
    
    for _, setting in ipairs(profileSettings) do
        if key == setting then
            return true
        end
    end
    return false
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
                type = self:NormalizeCCType(data.ccType)
            }
        end
    end
    
    -- Override with custom spells (if not inactive)
    for spellID, data in pairs(self.db.customSpells) do
        if not self.db.inactiveSpells[spellID] then
            spells[spellID] = {
                priority = data.priority,
                type = self:NormalizeCCType(data.ccType)
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

-- Normalize CC type to string format (handle both old numeric and new string values)
function addon.Config:NormalizeCCType(ccType)
    if type(ccType) == "number" then
        -- Convert old numeric format to string using lookup
        return addon.Database.ccTypeLookup[ccType]
    elseif type(ccType) == "string" then
        -- Already string format, validate it exists
        return addon.Database.ccTypeLookup[ccType] and ccType or ccType
    end
    return nil
end

-- Profile Management Functions (using AceDB directly)
function addon.Config:GetCurrentProfileName()
    return self.database:GetCurrentProfile()
end

function addon.Config:GetProfileNames()
    local profiles = {}
    -- AceDB's GetProfiles returns a numerically indexed array, not a key-value table
    local profileArray, count = self.database:GetProfiles(profiles)
    table.sort(profiles)
    return profiles
end

function addon.Config:ProfileExists(profileName)
    for _, value in pairs(self.database:GetProfiles()) do
        if value == profileName then
            return true
        end
    end
    return false
end

function addon.Config:CreateProfile(profileName)
    if not profileName or profileName == "" then
        return false, "Profile name cannot be empty"
    end
    
    local profiles = self.database:GetProfiles()
    if profiles[profileName] then
        return false, "Profile already exists"
    end
    
    -- Create new profile (AceDB handles the creation)
    self.database:SetProfile(profileName)
    return true, "Profile created successfully"
end

function addon.Config:CopyProfile(sourceProfile, newProfileName)
    if not sourceProfile or not newProfileName or sourceProfile == "" or newProfileName == "" then
        return false, "Invalid profile names"
    end
    
    local profiles = self.database:GetProfiles()
    if not profiles[sourceProfile] then
        return false, "Source profile does not exist"
    end
    
    if profiles[newProfileName] then
        return false, "Target profile already exists"
    end
    
    -- Use AceDB's copy functionality
    self.database:CopyProfile(sourceProfile, newProfileName)
    return true, "Profile copied successfully"
end

function addon.Config:DeleteProfile(profileName)
    if not profileName or profileName == "" then
        return false, "Profile name cannot be empty"
    end
    
    if profileName == "Default" then
        return false, "Cannot delete Default profile"
    end
    
    if not self:ProfileExists(profileName) then
        return false, "Profile does not exist"
    end

    if self:GetCurrentProfileName() == profileName then
        return false, "Cannot delete the currently selected profile"
    end
    
    -- Use AceDB's delete functionality
    self.database:DeleteProfile(profileName)
    return true, "Profile deleted successfully"
end

function addon.Config:SwitchProfile(profileName)
    if not profileName or profileName == "" then
        return false, "Profile name cannot be empty"
    end
    
    -- Use AceDB's profile switching (this will trigger OnProfileChanged callback)
    -- AceDB will create the profile if it doesn't exist
    self.database:SetProfile(profileName)
    return true, "Switched to profile: " .. profileName
end

function addon.Config:ResetProfile()
    -- Reset current profile to defaults
    self.database:ResetProfile()
    return true, "Profile reset to defaults"
end

-- Profile Sync Functions
function addon.Config:SyncProfileToParty(profileName)
    if not addon.ProfileSync then
        return false, "Profile sync not initialized"
    end
    
    return addon.ProfileSync:ShareProfile(profileName or self:GetCurrentProfileName())
end

function addon.Config:RequestProfileFromPlayer(playerName, profileName)
    if not addon.ProfileSync then
        return false, "Profile sync not initialized"
    end
    
    return addon.ProfileSync:RequestProfile(playerName, profileName)
end

function addon.Config:RequestProfileListFromPlayer(playerName)
    if not addon.ProfileSync then
        return false, "Profile sync not initialized"
    end
    
    return addon.ProfileSync:RequestProfileList(playerName)
end

function addon.Config:GetPartyMembers()
    if not addon.ProfileSync then
        return {}
    end
    
    return addon.ProfileSync:GetPartyMembers()
end

-- Debug utility function
function addon.Config:DebugPrint(...)
    if self:Get("debugMode") then
        print("|cff00ff00CC Rotation Helper [DEBUG]:|r", ...)
    end
end
