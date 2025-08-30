local addonName, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local NPCsTab = {}

-- Create NPCs tab content using component-based architecture
function NPCsTab.create(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Validate DataManager is available
    if not addon.Components or not addon.Components.DataManager then
        error("DataManager not loaded. Make sure UI/Components/DataManager.lua is loaded first.")
    end
    
    -- Help text
    local helpText = AceGUI:Create("Label")
    helpText:SetText("View dangerous casts that the addon tracks for interrupt alerts. These are abilities that should be stopped with crowd control.")
    helpText:SetFullWidth(true)
    scroll:AddChild(helpText)
    
    -- Dangerous casts display
    local dangerousCastsGroup = addon.BaseComponent:createInlineGroup("Tracked Dangerous Casts", scroll)
    
    -- Group dangerous casts by dungeon and display
    if addon.Database and addon.Database.dangerousCasts then
        -- Create dungeon groups based on the new database structure
        local dungeonGroups = {}
        local dungeonOrder = {}
        local currentDungeon = "Other"
        
        -- Parse the new structure using ipairs for ordered traversal
        -- Structure: "DungeonName", { [spellID] = data, ... }, next entries...
        local i = 1
        local dangerousCasts = addon.Database.dangerousCasts
        
        while i <= #dangerousCasts do
            local entry = dangerousCasts[i]
            
            -- Check if this entry is a dungeon name (string)
            if type(entry) == "string" then
                currentDungeon = entry
                if not dungeonGroups[currentDungeon] then
                    dungeonGroups[currentDungeon] = {}
                    table.insert(dungeonOrder, currentDungeon)
                end
                
                -- Check if the next entry is the spell table for this dungeon
                if i + 1 <= #dangerousCasts and type(dangerousCasts[i + 1]) == "table" then
                    local spellTable = dangerousCasts[i + 1]
                    for spellID, castData in pairs(spellTable) do
                        if type(spellID) == "number" and type(castData) == "table" then
                            table.insert(dungeonGroups[currentDungeon], {spellID = spellID, data = castData})
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
        
        
        -- Display each dungeon group
        for _, dungeonName in ipairs(dungeonOrder) do
            local casts = dungeonGroups[dungeonName]
            
            -- Dungeon header
            local dungeonHeader = AceGUI:Create("Heading")
            dungeonHeader:SetText(dungeonName)
            dungeonHeader:SetFullWidth(true)
            dangerousCastsGroup:AddChild(dungeonHeader)
            
            -- Display casts in this dungeon
            for _, castInfo in ipairs(casts) do
                local spellID = castInfo.spellID
                local castData = castInfo.data
                
                -- Only process if castData is valid
                if castData and type(castData) == "table" then
                    local castFrame = AceGUI:Create("SimpleGroup")
                    castFrame:SetFullWidth(true)
                    castFrame:SetLayout("Flow")
                    dangerousCastsGroup:AddChild(castFrame)
                    
                    -- Spell icon
                    local spellIcon = AceGUI:Create("Icon")
                    spellIcon:SetWidth(32)
                    spellIcon:SetHeight(32)
                    spellIcon:SetImageSize(32, 32)
                    
                    local spellInfo = C_Spell.GetSpellInfo(spellID)
                    if spellInfo and spellInfo.iconID then
                        spellIcon:SetImage(spellInfo.iconID)
                    else
                        spellIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
                    end
                    castFrame:AddChild(spellIcon)
                    
                    -- Spell details
                    local detailsGroup = AceGUI:Create("SimpleGroup")
                    detailsGroup:SetWidth(400)
                    detailsGroup:SetLayout("Flow")
                    castFrame:AddChild(detailsGroup)
                    
                    local spellName = AceGUI:Create("Label")
                    local name = castData.name or "Unknown Spell"
                    spellName:SetText(string.format("|cff00ff00%s|r (ID: %d)", name, spellID))
                    spellName:SetWidth(400)
                    detailsGroup:AddChild(spellName)
                    
                    local npcName = AceGUI:Create("Label")
                    local npc = castData.npcName or "Unknown NPC"
                    npcName:SetText(string.format("Cast by: |cffffff00%s|r", npc))
                    npcName:SetWidth(400)
                    detailsGroup:AddChild(npcName)
                    
                    local ccTypes = AceGUI:Create("Label")
                    local ccTypeNames = {}
                    if castData.ccTypes then
                        for _, ccType in ipairs(castData.ccTypes) do
                            local displayName = addon.Database.ccTypeDisplayNames and addon.Database.ccTypeDisplayNames[ccType] or ccType
                            table.insert(ccTypeNames, displayName)
                        end
                    end
                    ccTypes:SetText(string.format("Stoppable with: |cffff8800%s|r", table.concat(ccTypeNames, ", ")))
                    ccTypes:SetWidth(400)
                    detailsGroup:AddChild(ccTypes)
                else
                    print("|cff00ff00CC Rotation Helper|r: Invalid cast data for spell ID", spellID)
                end
            end
            
            -- Add spacing after each dungeon
            local spacer = AceGUI:Create("Label")
            spacer:SetText(" ")
            spacer:SetFullWidth(true)
            dangerousCastsGroup:AddChild(spacer)
        end
    else
        local noCastsLabel = AceGUI:Create("Label")
        noCastsLabel:SetText("No dangerous casts configured.")
        noCastsLabel:SetFullWidth(true)
        dangerousCastsGroup:AddChild(noCastsLabel)
    end
    
    -- Information about dangerous cast system
    local infoText = AceGUI:Create("Label")
    infoText:SetText("The addon now uses dangerous cast detection instead of NPC effectiveness tracking. When these abilities are being cast, you'll receive visual alerts to use your crowd control abilities to stop them.")
    infoText:SetFullWidth(true)
    scroll:AddChild(infoText)
    
    -- Force layout refresh to fix scrolling
    C_Timer.After(0.1, function()
        if scroll and scroll.DoLayout then
            scroll:DoLayout()
        end
    end)
end

-- Register NPCsTab module for ConfigFrame to load
addon.NPCsTabModule = NPCsTab

return NPCsTab