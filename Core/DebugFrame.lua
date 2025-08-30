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
    SPELL = true,       -- Enable spell debugging
    UI = false,
    DEBUG = true,       -- Debug commands
    ERROR = true        -- Always show errors
}

-- Debug frame storage
local debugFrames = {}
local debugLines = {}
local maxDebugLines = 1000
local activeTab = "INIT" -- Default active tab

-- Create tab button
local function CreateTabButton(parent, category, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(80, 25)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 15 + (index * 85), -30)
    
    -- Button background
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Button text
    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(category)
    
    -- Button behavior
    button:SetScript("OnClick", function()
        activeTab = category
        parent:UpdateTabs()
        parent:UpdateContent()
    end)
    
    button:SetScript("OnEnter", function()
        if activeTab ~= category then
            button.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
        end
    end)
    
    button:SetScript("OnLeave", function()
        if activeTab ~= category then
            button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        end
    end)
    
    button.category = category
    return button
end

-- Create debug frame with tabs
local function CreateDebugFrame(frameName, title)
    if debugFrames[frameName] then return debugFrames[frameName] end
    
    local frame = CreateFrame("Frame", "CCRotationHelper" .. frameName .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(700, 450)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Set title
    frame.TitleText:SetText(title or "Debug Frame")
    
    -- Create Copy button
    local copyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyButton:SetSize(60, 22)
    copyButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -5)
    copyButton:SetText("Copy")
    copyButton:SetScript("OnClick", function()
        local currentFrameName = frameName
        local currentTab = activeTab
        local messages = {}
        
        -- Get all messages for current tab
        if debugLines[currentFrameName] and debugLines[currentFrameName][currentTab] then
            for _, line in ipairs(debugLines[currentFrameName][currentTab]) do
                -- Remove color codes for cleaner copying
                local cleanLine = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                table.insert(messages, cleanLine)
            end
        end
        
        local copyText = table.concat(messages, "\n")
        if copyText and copyText ~= "" then
            -- Create invisible editbox for copying
            if not frame.copyBox then
                frame.copyBox = CreateFrame("EditBox", nil, frame)
                frame.copyBox:SetSize(1, 1)
                frame.copyBox:SetPoint("TOPLEFT", frame, "TOPLEFT", -100, -100)
                frame.copyBox:SetAlpha(0)
                frame.copyBox:SetAutoFocus(false)
                frame.copyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            end
            
            frame.copyBox:SetText(copyText)
            frame.copyBox:HighlightText()
            frame.copyBox:SetFocus()
            print("|cff00ff00CC Rotation Helper|r: Debug text copied to clipboard. Press Ctrl+C to copy, then Escape to close.")
        else
            print("|cff00ff00CC Rotation Helper|r: No debug text to copy.")
        end
    end)
    frame.copyButton = copyButton
    
    -- Create Clear button
    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 22)
    clearButton:SetPoint("TOPRIGHT", copyButton, "TOPLEFT", -5, 0)
    clearButton:SetText("Clear")
    clearButton:SetScript("OnClick", function()
        local currentFrameName = frameName
        local currentTab = activeTab
        
        -- Clear messages for current tab
        if debugLines[currentFrameName] and debugLines[currentFrameName][currentTab] then
            debugLines[currentFrameName][currentTab] = {}
            -- Refresh the frame display
            if frame.text then
                frame.text:SetText("Debug messages cleared for " .. currentTab .. " tab.")
            end
            print("|cff00ff00CC Rotation Helper|r: Cleared " .. currentTab .. " debug messages.")
        else
            print("|cff00ff00CC Rotation Helper|r: No debug messages to clear.")
        end
    end)
    frame.clearButton = clearButton
    
    -- Create tabs
    frame.tabs = {}
    local tabCategories = {"INIT", "GROUP", "LEADER", "SYNC", "COMM", "PROFILE", "SPELL", "ERROR"}
    
    for i, category in ipairs(tabCategories) do
        local tab = CreateTabButton(frame, category, i - 1)
        frame.tabs[category] = tab
    end
    
    -- Create scrollable text area (positioned below tabs)
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -65)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 20)
    frame.scrollFrame = scrollFrame
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 1) -- Height will be dynamic
    scrollFrame:SetScrollChild(content)
    frame.content = content
    
    -- Debug text area inside scroll content
    frame.text = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    frame.text:SetWidth(scrollFrame:GetWidth() - 20)
    frame.text:SetJustifyH("LEFT")
    frame.text:SetJustifyV("TOP")
    frame.text:SetText("Debug Ready...\nUse /ccr debug commands to populate this frame.")
    
    -- Update tab appearances
    function frame:UpdateTabs()
        for category, tab in pairs(self.tabs) do
            if category == activeTab then
                tab.bg:SetColorTexture(0.4, 0.6, 0.8, 0.9) -- Active tab color
                tab.text:SetTextColor(1, 1, 1) -- White text for active
            else
                tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8) -- Inactive tab color
                tab.text:SetTextColor(0.8, 0.8, 0.8) -- Gray text for inactive
            end
        end
    end
    
    -- Update content based on active tab
    function frame:UpdateContent()
        local lines = debugLines[frameName] and debugLines[frameName][activeTab] or {}
        local text = #lines > 0 and table.concat(lines, "\n") or "No " .. activeTab .. " debug messages yet."
        self.text:SetText(text)
        
        -- Simple content height update without expensive calculations
        local lineCount = #lines
        local estimatedHeight = math.max(lineCount * 14, self.scrollFrame:GetHeight()) -- 14 pixels per line estimate
        self.content:SetHeight(estimatedHeight)
    end
    
    frame:Hide() -- Start hidden
    
    debugFrames[frameName] = frame
    if not debugLines[frameName] then
        debugLines[frameName] = {}
    end
    
    return frame
end

-- Update debug frame text (with throttling)
local lastUpdate = {}
local function UpdateDebugFrame(frameName)
    local frame = debugFrames[frameName]
    if not frame or not frame:IsShown() then return end
    
    -- Throttle updates to prevent script timeout
    local now = GetTime()
    if lastUpdate[frameName] and (now - lastUpdate[frameName]) < 0.1 then
        return -- Skip update if less than 100ms since last update
    end
    lastUpdate[frameName] = now
    
    frame:UpdateTabs()
    frame:UpdateContent()
end

-- Add debug line to specific frame and category
local function AddDebugLine(frameName, category, message)
    if not debugLines[frameName] then
        debugLines[frameName] = {}
    end
    if not debugLines[frameName][category] then
        debugLines[frameName][category] = {}
    end
    
    local timestamp = date("%H:%M:%S")
    local categoryColor = "00ff00" -- Default green
    
    -- Category-specific colors
    if category == "ERROR" then categoryColor = "ff4444"
    elseif category == "GROUP" then categoryColor = "4488ff"
    elseif category == "LEADER" then categoryColor = "ffaa00"
    elseif category == "SYNC" then categoryColor = "88ff88"
    elseif category == "COMM" then categoryColor = "ff88ff"
    elseif category == "SPELL" then categoryColor = "ffcc00"
    end
    
    local line = string.format("|cffaaaaaa%s|r |cff%s[%s]|r %s", 
        timestamp,
        categoryColor,
        category,
        message
    )
    
    table.insert(debugLines[frameName][category], line)
    
    -- Keep only recent lines per category
    if #debugLines[frameName][category] > maxDebugLines then
        table.remove(debugLines[frameName][category], 1)
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

-- Clear debug lines for a frame (all categories or specific category)
function addon.DebugFrame:ClearFrame(frameName, category)
    frameName = frameName or "PartySync"
    if debugLines[frameName] then
        if category then
            -- Clear specific category
            if debugLines[frameName][category] then
                debugLines[frameName][category] = {}
            end
        else
            -- Clear all categories
            debugLines[frameName] = {}
        end
        UpdateDebugFrame(frameName)
    end
end

-- Set active tab for a frame
function addon.DebugFrame:SetActiveTab(frameName, category)
    frameName = frameName or "PartySync"
    if DEBUG_CATEGORIES[category] then
        activeTab = category
        UpdateDebugFrame(frameName)
    end
end

-- Readable table serializer for debug output
local function SerializeTable(tbl, indent, visited)
    indent = indent or 0
    visited = visited or {}
    
    if visited[tbl] then
        return "{circular reference}"
    end
    visited[tbl] = true
    
    local indentStr = string.rep("  ", indent)
    local result = "{\n"
    
    for k, v in pairs(tbl) do
        local keyStr = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        
        -- If key looks like a spell ID, add spell name
        if type(k) == "number" and k > 1000 and k < 1000000 then
            local spellInfo = C_Spell.GetSpellInfo(k)
            if spellInfo and spellInfo.name then
                keyStr = "[" .. tostring(k) .. " - " .. spellInfo.name .. "]"
            else
                keyStr = "[" .. tostring(k) .. "]"
            end
        end
        
        result = result .. indentStr .. "  " .. keyStr .. " = "
        
        if type(v) == "table" then
            if indent < 4 then -- Allow deeper nesting now
                result = result .. SerializeTable(v, indent + 1, visited)
            else
                result = result .. "{...}"
            end
        elseif type(v) == "string" then
            result = result .. "\"" .. tostring(v) .. "\""
        else
            result = result .. tostring(v)
        end
        result = result .. ",\n"
    end
    
    visited[tbl] = nil
    return result .. indentStr .. "}"
end

-- Filter table to only show specific spell IDs
local function FilterSpellData(data, spellIDs)
    if type(data) ~= "table" then return data end
    
    local filtered = {}
    
    for unit, unitData in pairs(data) do
        if type(unitData) == "table" then
            local filteredUnit = {}
            for spellID, spellData in pairs(unitData) do
                if type(spellID) == "number" then
                    -- Check if this spell ID is in our filter list
                    for _, filterID in ipairs(spellIDs) do
                        if spellID == filterID then
                            filteredUnit[spellID] = spellData
                            break
                        end
                    end
                else
                    -- Keep non-spell-ID entries
                    filteredUnit[spellID] = spellData
                end
            end
            -- Only include units that have filtered spells
            if next(filteredUnit) then
                filtered[unit] = filteredUnit
            end
        else
            filtered[unit] = unitData
        end
    end
    
    return filtered
end

-- DevTools_Dump wrapper for debug frames
function addon.DebugFrame:Dump(frameName, category, data, label)
    -- Send label header
    if label then
        self:Print(frameName, category, "=== " .. label .. " ===")
    end
    
    -- Serialize and print the data line by line for readability
    if type(data) == "table" then
        local serialized = SerializeTable(data)
        -- Split into lines and send each line
        for line in serialized:gmatch("[^\r\n]+") do
            if line:match("%S") then -- Only send lines with non-whitespace content
                self:Print(frameName, category, line)
            end
        end
    else
        self:Print(frameName, category, tostring(data))
    end
end

-- Filtered dump wrapper - only shows specific spell IDs
function addon.DebugFrame:DumpFiltered(frameName, category, data, spellIDs, label)
    local filtered = FilterSpellData(data, spellIDs)
    
    -- Add spell names to label for clarity
    local spellNames = {}
    for _, spellID in ipairs(spellIDs) do
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        local name = spellInfo and spellInfo.name or ("Unknown-" .. spellID)
        table.insert(spellNames, name)
    end
    
    local filterLabel = (label or "Filtered data") .. " (showing: " .. table.concat(spellNames, ", ") .. ")"
    self:Dump(frameName, category, filtered, filterLabel)
end

-- Export categories for external use
addon.DebugFrame.Categories = DEBUG_CATEGORIES