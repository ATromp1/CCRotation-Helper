-- DebugFrame.lua - Generic debug system for CC Rotation Helper
local addonName, addon = ...

addon.DebugFrame = {}

-- Debug categories for organized logging
local DEBUG_CATEGORIES = {
    -- Party Sync categories
    INIT = "INIT",           -- Initialization and setup
    GROUP = "GROUP",         -- Group join/leave/composition changes  
    LEADER = "LEADER",       -- Leadership changes
    SYNC = "SYNC",          -- Party sync activation/deactivation
    COMM = "COMM",          -- Communication (ping/pong/messages)
    PROFILE = "PROFILE",    -- Profile switching and data
    STATE = "STATE",        -- State validation and recovery
    ORCHESTRATOR = "ORCHESTRATOR", -- State machine and orchestration
    
    -- Other debug categories
    ICON = "ICON",          -- Icon rendering and pooling
    NPC = "NPC",            -- NPC detection and database
    SPELL = "SPELL",        -- Spell tracking and cooldowns
    UI = "UI",              -- UI components and events
    DEBUG = "DEBUG",        -- General debug commands
    ERROR = "ERROR"         -- Errors and inconsistencies
}

-- Enable specific debug categories (set to true to enable debugging for that category)
local DEBUG_ENABLED = {
    -- Party sync debugging (currently active)
    INIT = true,
    GROUP = true,
    LEADER = true,
    SYNC = true,
    COMM = true,
    PROFILE = true,
    STATE = true,
    ORCHESTRATOR = true,
    
    -- Other debugging (disabled by default)
    ICON = false,
    NPC = false,
    SPELL = false,
    UI = false,
    DEBUG = true,       -- Debug commands
    ERROR = true        -- Always show errors
}

-- Debug frame storage
local debugFrames = {}
local debugLines = {}
local maxDebugLines = 50

-- Create debug frame
local function CreateDebugFrame(frameName, title)
    if debugFrames[frameName] then return debugFrames[frameName] end
    
    local frame = CreateFrame("Frame", "CCRotationHelper" .. frameName .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(700, 450)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("TOOLTIP")  -- High strata so debug frames stay on top
    frame:SetFrameLevel(100)         -- High level within the strata
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Set title
    frame.TitleText:SetText(title or "Debug Frame")
    
    -- Debug text area
    frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
    frame.text:SetWidth(660)
    frame.text:SetHeight(370)
    frame.text:SetJustifyH("LEFT")
    frame.text:SetJustifyV("TOP")
    frame.text:SetText("Debug Ready...\nUse /ccr debug commands to populate this frame.")
    
    frame:Hide() -- Start hidden
    
    debugFrames[frameName] = frame
    debugLines[frameName] = {}
    
    return frame
end

-- Update debug frame text
local function UpdateDebugFrame(frameName)
    local frame = debugFrames[frameName]
    if not frame or not frame:IsShown() then return end
    
    local lines = debugLines[frameName] or {}
    local text = table.concat(lines, "\n")
    frame.text:SetText(text)
end

-- Add debug line to specific frame
local function AddDebugLine(frameName, category, message)
    if not debugLines[frameName] then
        debugLines[frameName] = {}
    end
    
    local timestamp = date("%H:%M:%S")
    local categoryColor = "00ff00" -- Default green
    
    -- Category-specific colors
    if category == "ERROR" then categoryColor = "ff4444"
    elseif category == "GROUP" then categoryColor = "4488ff"
    elseif category == "LEADER" then categoryColor = "ffaa00"
    elseif category == "SYNC" then categoryColor = "88ff88"
    elseif category == "COMM" then categoryColor = "ff88ff"
    end
    
    local line = string.format("|cffaaaaaa%s|r |cff%s[%s]|r %s", 
        timestamp,
        categoryColor,
        category,
        message
    )
    
    table.insert(debugLines[frameName], line)
    
    -- Keep only recent lines
    if #debugLines[frameName] > maxDebugLines then
        table.remove(debugLines[frameName], 1)
    end
    
    UpdateDebugFrame(frameName)
end

-- Main debug print function
function addon.DebugFrame:Print(frameName, category, ...)
    if not DEBUG_ENABLED[category] then return end
    
    local args = {...}
    local message = ""
    for i, arg in ipairs(args) do
        if i > 1 then message = message .. " " end
        message = message .. tostring(arg)
    end
    
    AddDebugLine(frameName, category, message)
end

-- Convenience functions for party sync debugging
function addon.DebugFrame:PartySync(category, ...)
    self:Print("PartySync", category, ...)
end

-- Specific category functions for party sync
function addon.DebugFrame:Init(...) self:PartySync(DEBUG_CATEGORIES.INIT, ...) end
function addon.DebugFrame:Group(...) self:PartySync(DEBUG_CATEGORIES.GROUP, ...) end
function addon.DebugFrame:Leader(...) self:PartySync(DEBUG_CATEGORIES.LEADER, ...) end
function addon.DebugFrame:Sync(...) self:PartySync(DEBUG_CATEGORIES.SYNC, ...) end
function addon.DebugFrame:Comm(...) self:PartySync(DEBUG_CATEGORIES.COMM, ...) end
function addon.DebugFrame:Profile(...) self:PartySync(DEBUG_CATEGORIES.PROFILE, ...) end
function addon.DebugFrame:State(...) self:PartySync(DEBUG_CATEGORIES.STATE, ...) end
function addon.DebugFrame:Error(...) self:PartySync(DEBUG_CATEGORIES.ERROR, ...) end

-- Generic functions for other debugging
function addon.DebugFrame:Icon(...) self:Print("General", DEBUG_CATEGORIES.ICON, ...) end
function addon.DebugFrame:NPC(...) self:Print("General", DEBUG_CATEGORIES.NPC, ...) end
function addon.DebugFrame:Spell(...) self:Print("General", DEBUG_CATEGORIES.SPELL, ...) end
function addon.DebugFrame:UI(...) self:Print("General", DEBUG_CATEGORIES.UI, ...) end

-- Frame management functions
function addon.DebugFrame:ShowFrame(frameName, title)
    frameName = frameName or "PartySync"
    title = title or "Party Sync Debug"
    
    local frame = CreateDebugFrame(frameName, title)
    frame:Show()
    print("|cff00ff00CC Rotation Helper|r: " .. title .. " frame shown")
    
    -- Add a test message
    self:Print(frameName, "INIT", "Debug frame opened - ready for debugging")
end

function addon.DebugFrame:HideFrame(frameName)
    frameName = frameName or "PartySync"
    local frame = debugFrames[frameName]
    if frame then
        frame:Hide()
        print("|cff00ff00CC Rotation Helper|r: Debug frame hidden")
    end
end

function addon.DebugFrame:ToggleFrame(frameName, title)
    frameName = frameName or "PartySync"
    title = title or "Party Sync Debug"
    
    local frame = debugFrames[frameName]
    if frame and frame:IsShown() then
        self:HideFrame(frameName)
    else
        self:ShowFrame(frameName, title)
    end
end

-- Configuration functions
function addon.DebugFrame:EnableCategory(category)
    if DEBUG_CATEGORIES[category] then
        DEBUG_ENABLED[category] = true
    end
end

function addon.DebugFrame:DisableCategory(category)
    if DEBUG_CATEGORIES[category] then
        DEBUG_ENABLED[category] = false
    end
end

function addon.DebugFrame:IsEnabled(category)
    return DEBUG_ENABLED[category] == true
end

-- Clear debug lines for a frame
function addon.DebugFrame:ClearFrame(frameName)
    frameName = frameName or "PartySync"
    if debugLines[frameName] then
        debugLines[frameName] = {}
        UpdateDebugFrame(frameName)
    end
end

-- Export categories for external use
addon.DebugFrame.Categories = DEBUG_CATEGORIES