local addonName, addon = ...

-- Load Ace3 libraries for configuration
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0") 
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

addon.Config = {}

-- Event system for decoupled communication
addon.Config.eventListeners = {}

-- Register event listener
function addon.Config:RegisterEventListener(event, callback)
    if not self.eventListeners[event] then
        self.eventListeners[event] = {}
    end
    table.insert(self.eventListeners[event], callback)
end

-- Fire event to all listeners
function addon.Config:FireEvent(event, ...)
    if self.eventListeners[event] then
        for _, callback in ipairs(self.eventListeners[event]) do
            callback(...)
        end
    end
end

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
        
        -- Single source of truth for spells (per profile)
        spells = {}, -- Working copy of spell data: { [spellID] = { name, ccType, priority, active, source } }
        
        -- NPCs
        customNPCs = {},
        inactiveNPCs = {},
        
        -- Display settings
        maxIcons = 2,
        iconSize = 64,
        iconSize1 = 64,
        iconSize2 = 32,
        iconSize3 = 32,
        iconSize4 = 32,
        iconSize5 = 32,
        spacing = 3,
        growDirection = "RIGHT",
        
        -- Font settings
        spellNameFont = "Friz Quadrata TT",
        spellNameFontSize = 12,
        spellNameMaxLength = 20,
        playerNameFont = "Friz Quadrata TT", 
        playerNameFontSize = 12,
        playerNameMaxLength = 15,
        cooldownFont = "Friz Quadrata TT",
        cooldownFontSize = 16,
        cooldownFontSizePercent = 25,
        
        -- Display options
        showSpellName = true,
        showPlayerName = true,
        showCooldownText = true,
        desaturateOnCooldown = true,
        desaturateWhenNoTrackedNPCs = false,
        showTooltips = false,
        highlightNext = true,
        glowOnlyInCombat = false,
        cooldownDecimalThreshold = 3,
        
        -- Colors (profile-specific)
        nextSpellGlow = {0.91, 1.0, 0.37, 1.0},
        cooldownTextColor = {0.91, 1.0, 0.37, 1.0},
        spellNameColor = {1.0, 1.0, 1.0, 1.0},
        
        -- Unavailable queue settings
        showUnavailableQueue = true,
        maxUnavailableIcons = 3,
        unavailableIconSize = 24,
        unavailableSpacing = 2,
        unavailableQueueOffset = 5,
        
        -- Unavailable queue positioning
        unavailableQueuePositioning = "relative", -- "relative" or "independent"
        unavailableQueueX = 0,
        unavailableQueueY = -30,
        unavailableQueueAnchorPoint = "TOP",
        unavailableQueueRelativePoint = "BOTTOM",
        
        -- Glow settings
        glowType = "Proc", -- Pixel, ACShine, Proc
        glowColor = {1, 1, 1, 1}, -- RGBA color for glow
        glowFrequency = 0.25, -- Animation frequency/speed
        
        -- Pixel Glow settings
        glowLines = 8, -- Number of lines for Pixel glow
        glowLength = 10, -- Length of lines for Pixel glow
        glowThickness = 2, -- Thickness of lines for Pixel glow
        glowXOffset = 0, -- X offset for Pixel glow
        glowYOffset = 0, -- Y offset for Pixel glow
        glowBorder = false, -- Add border to Pixel glow
        
        -- AutoCast Glow settings
        glowParticleGroups = 4, -- Number of particle groups (N parameter)
        glowACFrequency = 0.125, -- AutoCast specific frequency (separate from general frequency)
        glowScale = 1.0, -- Scale of particles
        glowACXOffset = 0, -- X offset for AutoCast glow
        glowACYOffset = 0, -- Y offset for AutoCast glow
        
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
        
        -- Sound options
        enableSounds = false,
        nextSpellSound = "Interface\\AddOns\\CCRotation\\Sounds\\next.ogg",
        enableTurnNotification = false, -- Play TTS when it's player's turn next
        turnNotificationText = "Next", -- Text to speak when it's player's turn
        turnNotificationVolume = 100, -- Volume for turn notification (0 to 100)
        
        -- Anchor settings
        anchorLocked = false,
        
        -- Core addon settings
        enabled = true,
        showInSolo = false,
        onlyInDungeons = false,
        
        -- Party sync data
        partySyncLastActiveProfile = nil,
        
        -- Minimap icon settings
        minimap = {
            minimapPos = 220,
            radius = 80,
        },
        
        -- Icon zoom multiplier
        iconZoom = 1.0,
        

    },
    global = {
        debugMode = false
    }
}

function addon.Config:Initialize()
    -- Initialize AceDB with profile support
    self.database = AceDB:New("CCRotationDB", defaults, true)
    
    -- Reference to current profile data and global data
    self.db = self.database.profile
    self.global = self.database.global
    
    -- Ensure character has its own profile
    self:EnsureCharacterProfile()
    
    -- Initialize spells table from database if empty
    self:InitializeSpells()

    -- Set up profile change callback
    self.database.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.database.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.database.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    -- Set up AceDBOptions for profile management
    self.profileOptions = AceDBOptions:GetOptionsTable(self.database)
    
    -- Register profile options with AceConfig
    AceConfig:RegisterOptionsTable("CCRotationHelper_Profiles", self.profileOptions)
end

-- Ensure current character has its own profile instead of using Default
function addon.Config:EnsureCharacterProfile()
    local characterName = UnitName("player") .. " - " .. GetRealmName()
    
    if self.database:GetCurrentProfile() == "Default" then
        -- Create and switch to character-specific profile
        self.database:SetProfile(characterName)
        
        -- Update references after profile change
        self.db = self.database.profile
        
        self:DebugPrint("Created profile for " .. characterName)
    end
    
    -- Set default sync profile to current character's profile if not already set
    if not self.db.partySyncLastActiveProfile then
        self.db.partySyncLastActiveProfile = self.database:GetCurrentProfile()
        self:DebugPrint("Set default sync profile to " .. self.db.partySyncLastActiveProfile)
    end
end

-- Called when profile changes (switch, copy, reset)
function addon.Config:OnProfileChanged()
    local newProfile = self.database:GetCurrentProfile()
    
    -- Update reference to current profile
    self.db = self.database.profile
    

    -- Notify rotation system to update tracked spells
    if addon.CCRotation then
        self:DebugPrint("Updating tracked spells and rebuilding queue...")
        addon.CCRotation.trackedCooldowns = self:GetTrackedSpells()
        if addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
            self:DebugPrint("Queue rebuilt successfully")
        end
    end
    
    -- Fire event for UI to refresh (UI will listen for this event)
    self:FireEvent("PROFILE_CHANGED")
    self:DebugPrint("Profile change event fired")
    
    -- If we're the party leader and in party sync mode, broadcast the profile change
    if addon.PartySync and UnitIsGroupLeader("player") and IsInGroup() and addon.PartySync:IsInPartySync() then
        -- Delay broadcast slightly to allow profile switch to complete
        C_Timer.After(0.5, function()
            addon.PartySync:BroadcastProfile()
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
    -- Use same logic as Set() to determine where to read from
    if self:IsProfileSetting(key) then
        return self.db[key]
    else
        return self.global[key]
    end
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
    -- All settings are now profile-specific
    -- Each character has completely independent configuration
    return true
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
    -- Check unified spells table first
    if self.db.spells and self.db.spells[spellID] then
        return self.db.spells[spellID]
    end
    
    -- Fall back to database
    return addon.Database.defaultSpells[spellID]
end

-- Initialize profile spells table from database if empty
function addon.Config:InitializeSpells()
    -- Ensure spells table exists
    if not self.db.spells then
        self.db.spells = {}
    end
    
    -- Check if spells table is already populated
    local spellCount = 0
    for _ in pairs(self.db.spells) do
        spellCount = spellCount + 1
        break
    end
    
    if spellCount == 0 then
        -- Check if database exists
        if not addon.Database or not addon.Database.defaultSpells then
            return
        end
        
        -- Copy all database spells to profile
        for spellID, spell in pairs(addon.Database.defaultSpells) do
            self.db.spells[spellID] = {
                name = spell.name,
                ccType = spell.ccType,
                priority = spell.priority,
                active = spell.active,
                source = spell.source
            }
        end
        
        local count = 0
        for _ in pairs(self.db.spells) do count = count + 1 end
    end
end

function addon.Config:GetTrackedSpells()
    local spells = {}
    
    -- Get only active spells from profile
    for spellID, spell in pairs(self.db.spells) do
        if spell.active then
            spells[spellID] = {
                priority = spell.priority,
                type = self:NormalizeCCType(spell.ccType)
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
    self:FireEvent("PROFILE_DATA_CHANGED", "priorityPlayers", playerName)
end

function addon.Config:RemovePriorityPlayer(playerName)
    self.db.priorityPlayers[playerName] = nil
    self:FireEvent("PROFILE_DATA_CHANGED", "priorityPlayers", playerName)
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
    
    local filteredProfiles = {}
    
    for _, profileName in ipairs(profiles) do
        table.insert(filteredProfiles, profileName)
    end
    
    table.sort(filteredProfiles)
    return filteredProfiles
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
    
    -- Check if profile switching is locked (during party sync as non-leader)
    if addon.PartySync and addon.PartySync:IsProfileSelectionLocked() then
        return false, "Profile switching is locked during party sync"
    end
    
    -- Use AceDB's profile switching (this will trigger OnProfileChanged callback)
    -- AceDB will create the profile if it doesn't exist
    self.database:SetProfile(profileName)
    
    -- Track this as a user choice for future restoration
    if addon.PartySync and addon.PartySync.TrackUserProfileChoice then
        addon.PartySync:TrackUserProfileChoice(profileName)
    end
    
    return true, "Switched to profile: " .. profileName
end

function addon.Config:ResetProfile()
    -- Reset current profile to defaults
    self.database:ResetProfile()
    return true, "Profile reset to defaults"
end



function addon.Config:GetPartyMembers()
    return {}
end

-- Check if profile selection is currently locked (during party sync)
function addon.Config:IsProfileSelectionLocked()
    -- Profile selection is locked when we're receiving synced data from a party leader
    if addon.PartySync then
        return addon.PartySync:IsProfileSelectionLocked()
    end
    return false
end

-- Get party sync information for UI display
function addon.Config:GetPartySyncStatus()
    if not addon.PartySync then
        return { isActive = false }
    end
    
    local isActive = addon.PartySync:IsActive()
    local leaderName = nil
    
    if isActive then
        if addon.PartySync:IsGroupLeader() then
            leaderName = UnitName("player")
        else
            -- Find the group leader name
            for i = 1, GetNumGroupMembers() do
                local unit = IsInRaid() and "raid" .. i or "party" .. i
                if UnitIsGroupLeader(unit) then
                    leaderName = UnitName(unit)
                    break
                end
            end
            -- If still not found, check if player 1 is the leader (solo case)
            if not leaderName and UnitIsGroupLeader("player") then
                leaderName = UnitName("player")
            end
        end
    end
    
    return {
        isActive = isActive,
        status = addon.PartySync:GetStatus(),
        leaderName = leaderName
    }
end

-- Debug utility function
function addon.Config:DebugPrint(...)
    if self:Get("debugMode") then
        print("|cff00ff00CC Rotation Helper [DEBUG]:|r", ...)
    end
end
