local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

-- Configuration frame using AceGUI
function addon.UI:CreateConfigFrame()
    if self.configFrame then 
        self.configFrame:Show()
        return 
    end
    
    -- Create main frame using AceGUI
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("CC Rotation Helper - Configuration")
    frame:SetStatusText("Configure your CC rotation settings")
    frame:SetWidth(900)
    frame:SetHeight(800)
    frame:SetLayout("Fill")
    
    -- Create tab group for organized settings
    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetTabs({
        {text="Display", value="display"},
        {text="Text", value="text"}, 
        {text="Icons", value="icons"},
        {text="Spells", value="spells"},
        {text="Players", value="players"}
    })
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        container:ReleaseChildren()
        if group == "display" then
            self:CreateDisplayTab(container)
        elseif group == "text" then
            self:CreateTextTab(container)
        elseif group == "icons" then
            self:CreateIconsTab(container)
        elseif group == "spells" then
            self:CreateSpellsTab(container)
        elseif group == "players" then
            self:CreatePlayersTab(container)
        end
    end)
    tabGroup:SelectTab("display")
    frame:AddChild(tabGroup)
    
    -- Store reference
    self.configFrame = frame
    
    -- Handle frame closing
    frame:SetCallback("OnClose", function(widget)
        widget:Hide()
    end)
end

-- Create Display tab content
function addon.UI:CreateDisplayTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Main enabled checkbox
    local enabledCheck = AceGUI:Create("CheckBox")
    enabledCheck:SetLabel("Enable CC Rotation Helper")
    enabledCheck:SetValue(addon.Config:Get("enabled"))
    enabledCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("enabled", value)
        if addon.UI.UpdateVisibility then
            addon.UI:UpdateVisibility()
        end
    end)
    enabledCheck:SetFullWidth(true)
    scroll:AddChild(enabledCheck)
    
    -- Show in solo checkbox
    local soloCheck = AceGUI:Create("CheckBox")
    soloCheck:SetLabel("Show when not in group")
    soloCheck:SetValue(addon.Config:Get("showInSolo"))
    soloCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showInSolo", value)
        if addon.UI.UpdateVisibility then
            addon.UI:UpdateVisibility()
        end
    end)
    soloCheck:SetFullWidth(true)
    scroll:AddChild(soloCheck)
    
    -- Show spell names
    local spellNameCheck = AceGUI:Create("CheckBox")
    spellNameCheck:SetLabel("Show spell names")
    spellNameCheck:SetValue(addon.Config:Get("showSpellName"))
    spellNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showSpellName", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameCheck:SetFullWidth(true)
    scroll:AddChild(spellNameCheck)
    
    -- Show player names
    local playerNameCheck = AceGUI:Create("CheckBox")
    playerNameCheck:SetLabel("Show player names")
    playerNameCheck:SetValue(addon.Config:Get("showPlayerName"))
    playerNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showPlayerName", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameCheck:SetFullWidth(true)
    scroll:AddChild(playerNameCheck)
    
    -- Show cooldown text
    local cooldownTextCheck = AceGUI:Create("CheckBox")
    cooldownTextCheck:SetLabel("Show cooldown numbers")
    cooldownTextCheck:SetValue(addon.Config:Get("showCooldownText"))
    cooldownTextCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showCooldownText", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    cooldownTextCheck:SetFullWidth(true)
    scroll:AddChild(cooldownTextCheck)
    
    -- Highlight next spell
    local highlightCheck = AceGUI:Create("CheckBox")
    highlightCheck:SetLabel("Highlight next spell")
    highlightCheck:SetValue(addon.Config:Get("highlightNext"))
    highlightCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("highlightNext", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    highlightCheck:SetFullWidth(true)
    scroll:AddChild(highlightCheck)
    
    -- Cooldown decimal threshold slider
    local decimalThresholdSlider = AceGUI:Create("Slider")
    decimalThresholdSlider:SetLabel("Show decimals below (seconds)")
    decimalThresholdSlider:SetSliderValues(0, 10, 1)
    decimalThresholdSlider:SetValue(addon.Config:Get("cooldownDecimalThreshold"))
    decimalThresholdSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("cooldownDecimalThreshold", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    decimalThresholdSlider:SetFullWidth(true)
    scroll:AddChild(decimalThresholdSlider)
    
end

-- Create Text tab content
function addon.UI:CreateTextTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Spell name font size slider
    local spellNameFontSlider = AceGUI:Create("Slider")
    spellNameFontSlider:SetLabel("Spell Name Font Size")
    spellNameFontSlider:SetSliderValues(8, 24, 1)
    spellNameFontSlider:SetValue(addon.Config:Get("spellNameFontSize"))
    spellNameFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("spellNameFontSize", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameFontSlider:SetFullWidth(true)
    scroll:AddChild(spellNameFontSlider)
    
    -- Spell name max length slider
    local spellNameLengthSlider = AceGUI:Create("Slider")
    spellNameLengthSlider:SetLabel("Spell Name Max Length")
    spellNameLengthSlider:SetSliderValues(5, 50, 1)
    spellNameLengthSlider:SetValue(addon.Config:Get("spellNameMaxLength"))
    spellNameLengthSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("spellNameMaxLength", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameLengthSlider:SetFullWidth(true)
    scroll:AddChild(spellNameLengthSlider)
    
    -- Player name font size slider
    local playerNameFontSlider = AceGUI:Create("Slider")
    playerNameFontSlider:SetLabel("Player Name Font Size")
    playerNameFontSlider:SetSliderValues(8, 24, 1)
    playerNameFontSlider:SetValue(addon.Config:Get("playerNameFontSize"))
    playerNameFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("playerNameFontSize", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameFontSlider:SetFullWidth(true)
    scroll:AddChild(playerNameFontSlider)
    
    -- Player name max length slider
    local playerNameLengthSlider = AceGUI:Create("Slider")
    playerNameLengthSlider:SetLabel("Player Name Max Length")
    playerNameLengthSlider:SetSliderValues(3, 30, 1)
    playerNameLengthSlider:SetValue(addon.Config:Get("playerNameMaxLength"))
    playerNameLengthSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("playerNameMaxLength", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameLengthSlider:SetFullWidth(true)
    scroll:AddChild(playerNameLengthSlider)
    
    -- Cooldown font size percentage slider
    local cooldownFontSlider = AceGUI:Create("Slider")
    cooldownFontSlider:SetLabel("Cooldown Font Size (% of icon)")
    cooldownFontSlider:SetSliderValues(10, 50, 1)
    cooldownFontSlider:SetValue(addon.Config:Get("cooldownFontSizePercent") or 25)
    cooldownFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("cooldownFontSizePercent", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    cooldownFontSlider:SetFullWidth(true)
    scroll:AddChild(cooldownFontSlider)
end

-- Create Icons tab content
function addon.UI:CreateIconsTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Max icons slider
    local maxIconsSlider = AceGUI:Create("Slider")
    maxIconsSlider:SetLabel("Max Icons")
    maxIconsSlider:SetSliderValues(1, 5, 1)
    maxIconsSlider:SetValue(addon.Config:Get("maxIcons"))
    
    -- Individual icon controls
    local iconSizeSliders = {}
    local iconSpellNameChecks = {}
    local iconPlayerNameChecks = {}
    
    for i = 1, 5 do
        -- Icon size slider
        local iconSlider = AceGUI:Create("Slider")
        iconSlider:SetLabel("Icon " .. i .. " Size")
        iconSlider:SetSliderValues(16, 128, 1)
        iconSlider:SetValue(addon.Config:Get("iconSize" .. i))
        iconSlider:SetCallback("OnValueChanged", function(widget, event, value)
            addon.Config:Set("iconSize" .. i, value)
            if addon.UI.RefreshDisplay then
                addon.UI:RefreshDisplay()
            end
        end)
        iconSlider:SetFullWidth(true)
        scroll:AddChild(iconSlider)
        iconSizeSliders[i] = iconSlider
        
        -- Spell name checkbox for this icon
        local spellNameCheck = AceGUI:Create("CheckBox")
        spellNameCheck:SetLabel("Icon " .. i .. " - Show spell name")
        spellNameCheck:SetValue(addon.Config:Get("showSpellName" .. i))
        spellNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
            addon.Config:Set("showSpellName" .. i, value)
            if addon.UI.RefreshDisplay then
                addon.UI:RefreshDisplay()
            end
        end)
        spellNameCheck:SetFullWidth(true)
        scroll:AddChild(spellNameCheck)
        iconSpellNameChecks[i] = spellNameCheck
        
        -- Player name checkbox for this icon
        local playerNameCheck = AceGUI:Create("CheckBox")
        playerNameCheck:SetLabel("Icon " .. i .. " - Show player name")
        playerNameCheck:SetValue(addon.Config:Get("showPlayerName" .. i))
        playerNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
            addon.Config:Set("showPlayerName" .. i, value)
            if addon.UI.RefreshDisplay then
                addon.UI:RefreshDisplay()
            end
        end)
        playerNameCheck:SetFullWidth(true)
        scroll:AddChild(playerNameCheck)
        iconPlayerNameChecks[i] = playerNameCheck
        
        -- Initially hide controls beyond maxIcons
        if i > addon.Config:Get("maxIcons") then
            iconSlider.frame:Hide()
            spellNameCheck.frame:Hide()
            playerNameCheck.frame:Hide()
        end
    end
    
    -- Add callback and widget for max icons slider
    maxIconsSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("maxIcons", value)
        
        -- Show/hide icon controls based on maxIcons
        for i = 1, 5 do
            if iconSizeSliders[i] then
                if i <= value then
                    iconSizeSliders[i].frame:Show()
                    iconSpellNameChecks[i].frame:Show()
                    iconPlayerNameChecks[i].frame:Show()
                else
                    iconSizeSliders[i].frame:Hide()
                    iconSpellNameChecks[i].frame:Hide()
                    iconPlayerNameChecks[i].frame:Hide()
                end
            end
        end
        
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    maxIconsSlider:SetFullWidth(true)
    scroll:AddChild(maxIconsSlider)
end

-- Function to renumber spell priorities to eliminate gaps
function addon.UI:RenumberSpellPriorities()
    -- Get all active spells
    local allSpells = {}
    
    -- Add database spells (if not inactive)
    for spellID, data in pairs(addon.Database.defaultSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "database"
            }
        end
    end
    
    -- Add custom spells (if not inactive, override database if same ID)
    for spellID, data in pairs(addon.Config.db.customSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "custom"
            }
        end
    end
    
    -- Sort spells by current priority
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    table.sort(sortedSpells, function(a, b) return a.data.priority < b.data.priority end)
    
    -- Renumber priorities starting from 1
    for i, spell in ipairs(sortedSpells) do
        local newPriority = i
        
        if spell.data.source == "custom" then
            -- Update custom spell priority
            addon.Config.db.customSpells[spell.spellID].priority = newPriority
        else
            -- Create custom entry to override database spell
            addon.Config.db.customSpells[spell.spellID] = {
                name = spell.data.name,
                ccType = spell.data.ccType,
                priority = newPriority
            }
        end
    end
end

-- Function to move spell priority up or down
function addon.UI:MoveSpellPriority(spellID, spellData, direction, sortedSpells, currentIndex)
    local targetIndex = direction == "up" and currentIndex - 1 or currentIndex + 1
    
    if targetIndex < 1 or targetIndex > #sortedSpells then
        return -- Can't move beyond bounds
    end
    
    local targetSpell = sortedSpells[targetIndex]
    local currentPriority = spellData.priority
    local targetPriority = targetSpell.data.priority
    
    -- Swap priorities
    if spellData.source == "custom" then
        -- Update custom spell priority
        addon.Config.db.customSpells[spellID].priority = targetPriority
    else
        -- Create custom entry to override database spell
        addon.Config.db.customSpells[spellID] = {
            name = spellData.name,
            ccType = spellData.ccType,
            priority = targetPriority
        }
    end
    
    if targetSpell.data.source == "custom" then
        -- Update target custom spell priority
        addon.Config.db.customSpells[targetSpell.spellID].priority = currentPriority
    else
        -- Create custom entry to override target database spell
        addon.Config.db.customSpells[targetSpell.spellID] = {
            name = targetSpell.data.name,
            ccType = targetSpell.data.ccType,
            priority = currentPriority
        }
    end
    
    -- Rebuild rotation queue
    if addon.CCRotation and addon.CCRotation.RebuildQueue then
        addon.CCRotation:RebuildQueue()
    end
end

-- Create Spells tab content
function addon.UI:CreateSpellsTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("Manage which spells are tracked in the rotation. Lower priority numbers mean higher priority (1 = highest).")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)
    
    -- CC Type reference
    local ccTypeText = AceGUI:Create("Label")
    ccTypeText:SetText("CC Types: 1=Stun, 2=Disorient, 3=Fear, 4=Knock, 5=Incapacitate")
    ccTypeText:SetFullWidth(true)
    scroll:AddChild(ccTypeText)
    
    -- Current tracked spells display
    local spellListGroup = AceGUI:Create("InlineGroup")
    spellListGroup:SetTitle("Currently Tracked Spells")
    spellListGroup:SetFullWidth(true)
    spellListGroup:SetLayout("Flow")
    scroll:AddChild(spellListGroup)
    
    -- Get all active spells (from database + custom, excluding inactive)
    local allSpells = {}
    
    -- Add database spells (if not inactive)
    for spellID, data in pairs(addon.Database.defaultSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "database"
            }
        end
    end
    
    -- Add custom spells (if not inactive, override database if same ID)
    for spellID, data in pairs(addon.Config.db.customSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "custom"
            }
        end
    end
    
    -- Sort spells by priority
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    table.sort(sortedSpells, function(a, b) return a.data.priority < b.data.priority end)
    
    -- Display spells as interactive rows
    for i, spell in ipairs(sortedSpells) do
        local rowGroup = AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("Flow")
        spellListGroup:AddChild(rowGroup)
        
        -- Move up button (disabled for first item)
        local upButton = AceGUI:Create("Button")
        upButton:SetText("Up")
        upButton:SetWidth(60)
        if i == 1 then
            upButton:SetDisabled(true)
        else
            upButton:SetCallback("OnClick", function()
                self:MoveSpellPriority(spell.spellID, spell.data, "up", sortedSpells, i)
                container:ReleaseChildren()
                self:CreateSpellsTab(container)
            end)
        end
        rowGroup:AddChild(upButton)
        
        -- Move down button (disabled for last item)
        local downButton = AceGUI:Create("Button")
        downButton:SetText("Down")
        downButton:SetWidth(70)
        if i == #sortedSpells then
            downButton:SetDisabled(true)
        else
            downButton:SetCallback("OnClick", function()
                self:MoveSpellPriority(spell.spellID, spell.data, "down", sortedSpells, i)
                container:ReleaseChildren()
                self:CreateSpellsTab(container)
            end)
        end
        rowGroup:AddChild(downButton)
        
        -- Spell icon
        local spellIcon = AceGUI:Create("Icon")
        spellIcon:SetWidth(32)
        spellIcon:SetHeight(32)
        spellIcon:SetImageSize(32, 32)
        
        -- Get spell icon from WoW API
        local spellInfo = C_Spell.GetSpellInfo(spell.spellID)
        if spellInfo and spellInfo.iconID then
            spellIcon:SetImage(spellInfo.iconID)
        else
            -- Fallback icon if spell not found
            spellIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        rowGroup:AddChild(spellIcon)
        
        -- Spell info label
        local spellLine = AceGUI:Create("Label")
        local ccTypeName = addon.Database.ccTypeLookup[spell.data.ccType] or "unknown"
        spellLine:SetText(string.format("%s (ID: %d, Priority: %d, Type: %s)", 
            spell.data.name, spell.spellID, spell.data.priority, ccTypeName))
        spellLine:SetWidth(350)
        rowGroup:AddChild(spellLine)
        
        -- Disable button (for all spells)
        local disableButton = AceGUI:Create("Button")
        disableButton:SetText("Disable")
        disableButton:SetWidth(80)
        disableButton:SetCallback("OnClick", function()
            -- Move spell to inactive list
            addon.Config.db.inactiveSpells[spell.spellID] = {
                name = spell.data.name,
                ccType = spell.data.ccType,
                priority = spell.data.priority,
                source = spell.data.source
            }
            
            -- Renumber remaining active spells to eliminate gaps
            self:RenumberSpellPriorities()
            
            container:ReleaseChildren()
            self:CreateSpellsTab(container)
            if addon.CCRotation and addon.CCRotation.RebuildQueue then
                addon.CCRotation:RebuildQueue()
            end
        end)
        rowGroup:AddChild(disableButton)
    end
    
    -- Add new spell section
    local addSpellGroup = AceGUI:Create("InlineGroup")
    addSpellGroup:SetTitle("Add Custom Spell")
    addSpellGroup:SetFullWidth(true)
    addSpellGroup:SetLayout("Flow")
    scroll:AddChild(addSpellGroup)
    
    -- Spell ID input
    local spellIDEdit = AceGUI:Create("EditBox")
    spellIDEdit:SetLabel("Spell ID")
    spellIDEdit:SetWidth(150)
    addSpellGroup:AddChild(spellIDEdit)
    
    -- Spell name input
    local spellNameEdit = AceGUI:Create("EditBox")
    spellNameEdit:SetLabel("Spell Name")
    spellNameEdit:SetWidth(200)
    addSpellGroup:AddChild(spellNameEdit)
    
    -- CC Type dropdown
    local ccTypeDropdown = AceGUI:Create("Dropdown")
    ccTypeDropdown:SetLabel("CC Type")
    ccTypeDropdown:SetWidth(150)
    ccTypeDropdown:SetList({
        [1] = "1 - Stun",
        [2] = "2 - Disorient", 
        [3] = "3 - Fear",
        [4] = "4 - Knock",
        [5] = "5 - Incapacitate"
    })
    ccTypeDropdown:SetValue(1)
    addSpellGroup:AddChild(ccTypeDropdown)
    
    -- Priority input
    local priorityEdit = AceGUI:Create("EditBox")
    priorityEdit:SetLabel("Priority (1-50)")
    priorityEdit:SetWidth(100)
    priorityEdit:SetText("25")
    addSpellGroup:AddChild(priorityEdit)
    
    -- Add button
    local addButton = AceGUI:Create("Button")
    addButton:SetText("Add Spell")
    addButton:SetWidth(100)
    addButton:SetCallback("OnClick", function()
        local spellID = tonumber(spellIDEdit:GetText())
        local spellName = spellNameEdit:GetText():trim()
        local ccType = ccTypeDropdown:GetValue()
        local priority = tonumber(priorityEdit:GetText()) or 25
        
        if spellID and spellName ~= "" and ccType and priority then
            -- Add to custom spells
            addon.Config.db.customSpells[spellID] = {
                name = spellName,
                ccType = ccType,
                priority = priority
            }
            
            -- Clear inputs
            spellIDEdit:SetText("")
            spellNameEdit:SetText("")
            priorityEdit:SetText("25")
            
            -- Refresh the tab
            container:ReleaseChildren()
            self:CreateSpellsTab(container)
            
            -- Rebuild rotation queue
            if addon.CCRotation and addon.CCRotation.RebuildQueue then
                addon.CCRotation:RebuildQueue()
            end
        end
    end)
    addSpellGroup:AddChild(addButton)
    
    -- Inactive spells section
    local inactiveSpellsGroup = AceGUI:Create("InlineGroup")
    inactiveSpellsGroup:SetTitle("Disabled Spells")
    inactiveSpellsGroup:SetFullWidth(true)
    inactiveSpellsGroup:SetLayout("Flow")
    scroll:AddChild(inactiveSpellsGroup)
    
    -- Check if there are any inactive spells
    local hasInactiveSpells = false
    for _ in pairs(addon.Config.db.inactiveSpells) do
        hasInactiveSpells = true
        break
    end
    
    if hasInactiveSpells then
        -- Display inactive spells
        for spellID, spellData in pairs(addon.Config.db.inactiveSpells) do
            local inactiveRowGroup = AceGUI:Create("SimpleGroup")
            inactiveRowGroup:SetFullWidth(true)
            inactiveRowGroup:SetLayout("Flow")
            inactiveSpellsGroup:AddChild(inactiveRowGroup)
            
            -- Enable button
            local enableButton = AceGUI:Create("Button")
            enableButton:SetText("Enable")
            enableButton:SetWidth(80)
            enableButton:SetCallback("OnClick", function()
                -- Remove from inactive list
                addon.Config.db.inactiveSpells[spellID] = nil
                
                -- Renumber all active spells (including the newly enabled one)
                self:RenumberSpellPriorities()
                
                container:ReleaseChildren()
                self:CreateSpellsTab(container)
                if addon.CCRotation and addon.CCRotation.RebuildQueue then
                    addon.CCRotation:RebuildQueue()
                end
            end)
            inactiveRowGroup:AddChild(enableButton)
            
            -- Spell icon
            local inactiveIcon = AceGUI:Create("Icon")
            inactiveIcon:SetWidth(32)
            inactiveIcon:SetHeight(32)
            inactiveIcon:SetImageSize(32, 32)
            
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            if spellInfo and spellInfo.iconID then
                inactiveIcon:SetImage(spellInfo.iconID)
            else
                inactiveIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            inactiveRowGroup:AddChild(inactiveIcon)
            
            -- Spell info (grayed out)
            local inactiveSpellLine = AceGUI:Create("Label")
            local ccTypeName = addon.Database.ccTypeLookup[spellData.ccType] or "unknown"
            inactiveSpellLine:SetText(string.format("|cff888888%s (ID: %d, Priority: %d, Type: %s)|r", 
                spellData.name, spellID, spellData.priority, ccTypeName))
            inactiveSpellLine:SetWidth(350)
            inactiveRowGroup:AddChild(inactiveSpellLine)
            
            -- Delete button (permanent removal)
            if spellData.source == "custom" then
                local deleteButton = AceGUI:Create("Button")
                deleteButton:SetText("Delete")
                deleteButton:SetWidth(80)
                deleteButton:SetCallback("OnClick", function()
                    -- Permanently remove custom spell
                    addon.Config.db.inactiveSpells[spellID] = nil
                    addon.Config.db.customSpells[spellID] = nil
                    
                    container:ReleaseChildren()
                    self:CreateSpellsTab(container)
                    if addon.CCRotation and addon.CCRotation.RebuildQueue then
                        addon.CCRotation:RebuildQueue()
                    end
                end)
                inactiveRowGroup:AddChild(deleteButton)
            end
        end
    else
        local noInactiveText = AceGUI:Create("Label")
        noInactiveText:SetText("No disabled spells.")
        noInactiveText:SetFullWidth(true)
        inactiveSpellsGroup:AddChild(noInactiveText)
    end
    
    -- Help text for spell management
    local manageHelpText = AceGUI:Create("Label")
    manageHelpText:SetText("Use Up/Down buttons to reorder spells. Use Disable button to temporarily remove spells from rotation. Use Enable button to restore disabled spells.")
    manageHelpText:SetFullWidth(true)
    scroll:AddChild(manageHelpText)
end

-- Create Players tab content
function addon.UI:CreatePlayersTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Priority players help text
    local priorityHelp = AceGUI:Create("Label")
    priorityHelp:SetText("Players listed here will be prioritized in the rotation order.")
    priorityHelp:SetFullWidth(true)
    scroll:AddChild(priorityHelp)
    
    -- Current priority players display
    local priorityDisplay = AceGUI:Create("Label")
    priorityDisplay:SetFullWidth(true)
    
    local function updatePriorityDisplay()
        local players = {}
        for name in pairs(addon.Config.db.priorityPlayers) do
            table.insert(players, name)
        end
        table.sort(players)
        if #players > 0 then
            priorityDisplay:SetText("Current: " .. table.concat(players, ", "))
        else
            priorityDisplay:SetText("Current: (No priority players set)")
        end
    end
    updatePriorityDisplay()
    scroll:AddChild(priorityDisplay)
    
    -- Add player editbox
    local addPlayerEdit = AceGUI:Create("EditBox")
    addPlayerEdit:SetLabel("Add Player")
    addPlayerEdit:SetWidth(200)
    addPlayerEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        local name = text:trim()
        if name ~= "" then
            addon.Config:AddPriorityPlayer(name)
            widget:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(addPlayerEdit)
    
    -- Add player button
    local addButton = AceGUI:Create("Button")
    addButton:SetText("Add")
    addButton:SetWidth(80)
    addButton:SetCallback("OnClick", function()
        local name = addPlayerEdit:GetText():trim()
        if name ~= "" then
            addon.Config:AddPriorityPlayer(name)
            addPlayerEdit:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(addButton)
    
    -- Add some spacing
    local spacer1 = AceGUI:Create("Label")
    spacer1:SetText(" ")
    spacer1:SetFullWidth(true)
    scroll:AddChild(spacer1)
    
    -- Remove player editbox
    local removePlayerEdit = AceGUI:Create("EditBox")
    removePlayerEdit:SetLabel("Remove Player")
    removePlayerEdit:SetWidth(200)
    removePlayerEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        local name = text:trim()
        if name ~= "" then
            addon.Config:RemovePriorityPlayer(name)
            widget:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(removePlayerEdit)
    
    -- Remove player button
    local removeButton = AceGUI:Create("Button")
    removeButton:SetText("Remove")
    removeButton:SetWidth(80)
    removeButton:SetCallback("OnClick", function()
        local name = removePlayerEdit:GetText():trim()
        if name ~= "" then
            addon.Config:RemovePriorityPlayer(name)
            removePlayerEdit:SetText("")
            updatePriorityDisplay()
        end
    end)
    scroll:AddChild(removeButton)
end

-- Show configuration frame
function addon.UI:ShowConfigFrame()
    if not AceGUI then
        print("|cffff0000CC Rotation Helper:|r AceGUI-3.0 not found! Please install Ace3 libraries.")
        return
    end
    
    self:CreateConfigFrame()
    self.configFrame:Show()
end