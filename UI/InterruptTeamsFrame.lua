local addonName, addon = ...

addon.UI = addon.UI or {}
local UI = addon.UI

-- Interrupt teams display frame
local InterruptTeamsFrame = {}
UI.InterruptTeamsFrame = InterruptTeamsFrame

-- Target marker constants for display
local RAID_TARGET_MARKERS = {
    [1] = {name = "Star", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:16|t"},
    [2] = {name = "Circle", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:16|t"},
    [3] = {name = "Diamond", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:16|t"},
    [4] = {name = "Triangle", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:16|t"},
    [5] = {name = "Moon", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:16|t"},
    [6] = {name = "Square", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:16|t"},
    [7] = {name = "Cross", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:16|t"},
    [8] = {name = "Skull", icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:16|t"}
}

-- Layout constants
local LINE_HEIGHT = 20  -- Vertical spacing between marker entries
local FRAME_WIDTH = 300
local FRAME_HEIGHT_BASE = 50  -- Base height for title area
local TITLE_Y_OFFSET = -10
local CONTENT_X_PADDING = 10
local CONTENT_Y_START = -30  -- Y position of first marker line
local TEXT_WIDTH = 280
local MAX_MARKERS = 8
local DEFAULT_POSITION_X = 400  -- Default X offset from center

function InterruptTeamsFrame:Initialize()
    if self.frame then
        return  -- Already initialized
    end

    self:CreateFrame()
    self:RegisterEvents()
    self:UpdateDisplay()
end

function InterruptTeamsFrame:CreateFrame()
    -- Create main frame with backdrop template
    self.frame = CreateFrame("Frame", "CCRotationHelperInterruptTeamsFrame", UIParent, "BackdropTemplate")
    self.frame:SetSize(FRAME_WIDTH, 200)  -- Height will be adjusted dynamically
    self.frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POSITION_X, 0)  -- Position to the right of center

    -- Background
    self.frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 5, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.75)
    self.frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Title
    self.titleText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOP", self.frame, "TOP", 0, TITLE_Y_OFFSET)
    self.titleText:SetText("Interrupt Teams")

    -- Create font strings for each potential marker
    self.markerTexts = {}
    for i = 1, MAX_MARKERS do
        local text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", CONTENT_X_PADDING, CONTENT_Y_START - ((i - 1) * LINE_HEIGHT))
        text:SetJustifyH("LEFT")
        text:SetWidth(TEXT_WIDTH)  -- Set width to prevent text wrapping issues
        text:Hide()  -- Initially hidden
        self.markerTexts[i] = text
    end

    -- Make frame movable
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(frame)
        if IsShiftKeyDown() then
            frame:StartMoving()
        end
    end)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        if addon.Config and addon.Config.db then
            addon.Config.db.interruptTeamsFramePoint = point
            addon.Config.db.interruptTeamsFrameX = xOfs
            addon.Config.db.interruptTeamsFrameY = yOfs
        end
    end)

    -- Load saved position
    if addon.Config and addon.Config.db then
        local point = addon.Config.db.interruptTeamsFramePoint
        local x = addon.Config.db.interruptTeamsFrameX
        local y = addon.Config.db.interruptTeamsFrameY
        if point and x and y then
            self.frame:ClearAllPoints()
            self.frame:SetPoint(point, UIParent, point, x, y)
        end
    end

    -- Initially hidden
    self.frame:Hide()
end

function InterruptTeamsFrame:RegisterEvents()
    -- Register for interrupt teams updates
    if addon.InterruptTeams then
        addon.InterruptTeams:RegisterEventListener("INTERRUPT_TEAMS_UPDATED", function()
            self:UpdateDisplay()
        end)
    end

    -- Register for group changes and cooldown updates
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end

    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, function()  -- Small delay to ensure data is updated
                self:UpdateDisplay()
            end)
        elseif event == "SPELL_UPDATE_COOLDOWN" or event == "UNIT_SPELLCAST_SUCCEEDED" then
            -- Update more frequently for cooldown changes, but throttle to avoid spam
            if not self.cooldownUpdatePending then
                self.cooldownUpdatePending = true
                C_Timer.After(0.1, function()
                    self.cooldownUpdatePending = false
                    self:UpdateDisplay()
                end)
            end
        end
    end)
end

function InterruptTeamsFrame:UpdateDisplay()
    if not self.frame then
        return
    end

    -- Check if interrupt teams is enabled
    if not addon.InterruptTeams or not addon.InterruptTeams:IsEnabled() then
        self.frame:Hide()
        return
    end

    -- Get rotation info
    local rotationInfo = addon.InterruptTeams:GetInterruptRotationInfo()

    -- Hide all marker texts first
    for i = 1, MAX_MARKERS do
        self.markerTexts[i]:Hide()
    end

    local visibleCount = 0
    local displayOrder = {}

    -- Create ordered list of markers to display (sorted by marker index for consistency)
    for markerIndex = 1, MAX_MARKERS do
        if rotationInfo[markerIndex] then
            table.insert(displayOrder, markerIndex)
        end
    end

    -- Display markers in sequential widget positions
    for i, markerIndex in ipairs(displayOrder) do
        local info = rotationInfo[markerIndex]
        if self.markerTexts[i] then
            visibleCount = visibleCount + 1

            -- Dynamically position this widget based on display order
            local yOffset = CONTENT_Y_START - ((i - 1) * LINE_HEIGHT)  -- Top-down stacking
            self.markerTexts[i]:ClearAllPoints()
            self.markerTexts[i]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", CONTENT_X_PADDING, yOffset)


            local marker = RAID_TARGET_MARKERS[markerIndex]
            local text = marker.icon .. ": "

            -- Show rotated team queue with next interrupter highlighted
            if info.rotatedTeam and #info.rotatedTeam > 0 then
                local teamText = ""
                for j, playerName in ipairs(info.rotatedTeam) do
                    if j > 1 then
                        teamText = teamText .. " > "
                    end

                    if playerName == info.nextInterrupter then
                        if info.isPlayerNext then
                            teamText = teamText .. "|cff00ff00" .. playerName .. " (YOU)|r"
                        else
                            teamText = teamText .. "|cffffff00" .. playerName .. "|r"
                        end
                    else
                        teamText = teamText .. "|cffcccccc" .. playerName .. "|r"
                    end
                end
                text = text .. teamText
            else
                text = text .. "|cffff0000No team assigned|r"
            end

            self.markerTexts[i]:SetText(text)
            self.markerTexts[i]:Show()
        end
    end

    -- Hide any unused widgets
    for i = visibleCount + 1, MAX_MARKERS do
        self.markerTexts[i]:Hide()
    end

    -- Check for interrupt status changes and send WeakAura messages
    self:CheckInterruptStatusChange(rotationInfo)

    -- Adjust frame size based on content and always show frame when enabled
    if visibleCount > 0 then
        local frameHeight = FRAME_HEIGHT_BASE + (visibleCount * LINE_HEIGHT)  -- Dynamic frame sizing
        self.frame:SetHeight(frameHeight)
    else
        -- Show empty frame with just title when no active markers
        self.frame:SetHeight(FRAME_HEIGHT_BASE)  -- Just enough for title
    end

    self.frame:Show()
end

function InterruptTeamsFrame:Show()
    if self.frame then
        self.frame:Show()
    end
end

function InterruptTeamsFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function InterruptTeamsFrame:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Track interrupt status for WeakAura integration
local previousInterruptStatus = false

-- Send WeakAura messages when interrupt status changes
function InterruptTeamsFrame:CheckInterruptStatusChange(rotationInfo)
    local currentlyInterrupting = false
    local activeMarkers = {}

    -- Check if player is next interrupter for any marker
    for markerIndex, info in pairs(rotationInfo) do
        if info.isPlayerNext then
            currentlyInterrupting = true
            table.insert(activeMarkers, markerIndex)
        end
    end

    -- Only send messages when status changes
    if currentlyInterrupting ~= previousInterruptStatus then
        if currentlyInterrupting then
            -- Player became next interrupter
            _G["CCR_PlayerInterrupting"] = true
            _G["CCR_InterruptMarkers"] = activeMarkers

            -- Send addon message for WeakAuras
            if IsInGroup() then
                C_ChatInfo.SendAddonMessage("CCRotationHelper", "INTERRUPT_START:" .. table.concat(activeMarkers, ","), "PARTY")
            end
        else
            -- Player is no longer next interrupter
            _G["CCR_PlayerInterrupting"] = false
            _G["CCR_InterruptMarkers"] = {}

            -- Send addon message for WeakAuras
            if IsInGroup() then
                C_ChatInfo.SendAddonMessage("CCRotationHelper", "INTERRUPT_STOP", "PARTY")
            end
        end
        previousInterruptStatus = currentlyInterrupting
    end
end

-- Add position reset function
function InterruptTeamsFrame:ResetPosition()
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_POSITION_X, 0)

        -- Clear saved position
        if addon.Config and addon.Config.db then
            addon.Config.db.interruptTeamsFramePoint = nil
            addon.Config.db.interruptTeamsFrameX = nil
            addon.Config.db.interruptTeamsFrameY = nil
        end
    end
end