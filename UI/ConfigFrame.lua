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
        {text="Npcs", value="npcs"},
        {text="Players", value="players"},
        {text="Profiles", value="profiles"}
    })
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        function container:RefreshCurrentTab()
            tabGroup:SelectTab(group)
        end

        container:ReleaseChildren()
        if group == "profiles" then
            -- Use ProfilesTab module for component-based implementation
            if not addon.UI.ProfilesTab then
                -- Load ProfilesTab module if not already loaded
                local ProfilesTab = addon.ProfilesTabModule or {}
                if not ProfilesTab.create then
                    error("ProfilesTab module not found or invalid")
                end
                addon.UI.ProfilesTab = ProfilesTab
            end
            addon.UI.ProfilesTab.create(container)
        elseif group == "display" then
            -- Use DisplayTab module for component-based implementation
            if not addon.UI.DisplayTab then
                -- Load DisplayTab module if not already loaded
                local DisplayTab = addon.DisplayTabModule or {}
                if not DisplayTab.create then
                    error("DisplayTab module not found or invalid")
                end
                addon.UI.DisplayTab = DisplayTab
            end
            addon.UI.DisplayTab.create(container)
        elseif group == "text" then
            -- Use TextTab module for component-based implementation
            if not addon.UI.TextTab then
                -- Load TextTab module if not already loaded
                local TextTab = addon.TextTabModule or {}
                if not TextTab.create then
                    error("TextTab module not found or invalid")
                end
                addon.UI.TextTab = TextTab
            end
            addon.UI.TextTab.create(container)
        elseif group == "icons" then
            -- Use IconsTab module for component-based implementation
            if not addon.UI.IconsTab then
                -- Load IconsTab module if not already loaded
                local IconsTab = addon.IconsTabModule or {}
                if not IconsTab.create then
                    error("IconsTab module not found or invalid")
                end
                addon.UI.IconsTab = IconsTab
            end
            addon.UI.IconsTab.create(container)
        elseif group == "spells" then
            -- Use SpellsTab module for component-based implementation
            if not addon.UI.SpellsTab then
                -- Load SpellsTab module if not already loaded
                local SpellsTab = addon.SpellsTabModule or {}
                if not SpellsTab.create then
                    error("SpellsTab module not found or invalid")
                end
                addon.UI.SpellsTab = SpellsTab
            end
            addon.UI.SpellsTab.create(container)
        elseif group == "npcs" then
            if not addon.UI.NPCsTab then
                local NPCsTab = addon.NPCsTabModule or {}
                addon.UI.NPCsTab = NPCsTab
            end
            
            if addon.UI.NPCsTab.create then
                addon.UI.NPCsTab.create(container)
            else
                error("NPCsTab module not loaded. Check that UI/Tabs/NPCsTab.lua is loaded.")
            end
        elseif group == "players" then
            if not addon.UI.PlayersTab then
                local PlayersTab = addon.PlayersTabModule or {}
                addon.UI.PlayersTab = PlayersTab
            end
            
            if addon.UI.PlayersTab.create then
                addon.UI.PlayersTab.create(container)
            else
                error("PlayersTab module not loaded. Check that UI/Tabs/PlayersTab.lua is loaded.")
            end
        end
    end)
    tabGroup:SelectTab("profiles")
    frame:AddChild(tabGroup)
    
    -- Store reference
    self.configFrame = frame
    
    -- Handle frame closing
    frame:SetCallback("OnClose", function(widget)
        widget:Hide()
    end)
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
    
    -- Immediately update tracked cooldowns cache and rebuild queue
    if addon.CCRotation then
        -- Update the tracked cooldowns cache with new priorities
        addon.CCRotation.trackedCooldowns = addon.Config:GetTrackedSpells()
        -- Force immediate synchronous rebuild instead of debounced rebuild
        if addon.CCRotation.DoRebuildQueue then
            addon.CCRotation:DoRebuildQueue()
        elseif addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
    end
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
