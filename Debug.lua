local addonName, addon = ...

-- Debug functions for testing UI issues
addon.Debug = {}

function addon.Debug:TestIconDisplay()
    print("=== CC Rotation Helper Debug Test ===")
    
    -- Check if UI exists
    if not addon.UI then
        print("ERROR: UI object missing")
        return
    end
    
    -- Check if main frame exists
    if not addon.UI.mainFrame then
        print("ERROR: Main frame missing")
        return
    end
    
    print("✓ Main frame exists")
    
    -- Check if icon frames exist
    if not addon.UI.iconFrames or #addon.UI.iconFrames == 0 then
        print("ERROR: Icon frames missing")
        return
    end
    
    print("✓ Icon frames exist:", #addon.UI.iconFrames)
    
    -- Test first icon frame
    local iconFrame = addon.UI.iconFrames[1]
    if not iconFrame then
        print("ERROR: First icon frame missing")
        return
    end
    
    print("✓ First icon frame exists")
    
    -- Show main frame and icon frame
    addon.UI.mainFrame:Show()
    iconFrame:Show()
    
    print("✓ Frames shown")
    
    -- Test basic texture
    print("Testing red color texture...")
    if not iconFrame.testTexture then
        iconFrame.testTexture = iconFrame:CreateTexture("TestTexture", "OVERLAY")
        iconFrame.testTexture:SetAllPoints()
    end
    iconFrame.testTexture:SetColorTexture(1, 0, 0, 1) -- Red
    iconFrame.testTexture:Show()
    
    print("✓ Red texture should be visible")
    
    -- Test spell icon
    C_Timer.After(2, function()
        print("Testing spell icon...")
        local spellInfo = C_Spell.GetSpellInfo(2094) -- Blind
        if spellInfo then
            print("✓ Spell found:", spellInfo.name, "Icon ID:", spellInfo.iconID)
            iconFrame.testTexture:SetTexture(spellInfo.iconID)
            iconFrame.testTexture:SetTexCoord(0, 1, 0, 1) -- Reset coords
            print("✓ Spell texture set - should see Blind icon")
        else
            print("ERROR: Spell not found")
        end
    end)
    
    print("=== Test complete ===")
end

function addon.Debug:TestWithRealData()
    print("=== Testing with Real Cooldown Data ===")
    
    -- Create test queue data
    local testQueue = {
        {
            GUID = UnitGUID("player"),
            spellID = 99, -- Incapacitating Roar
            priority = 1,
            expirationTime = GetTime() + 30,
            duration = 30,
            charges = 1
        }
    }
    
    print("Created test queue with 1 item")
    
    -- Test display update with fixed texture approach
    if addon.UI.UpdateDisplay then
        addon.UI:UpdateDisplay(testQueue)
        print("Called UpdateDisplay with test data")
        print("Should now show Incapacitating Roar icon using fixed approach")
    else
        print("ERROR: UpdateDisplay function missing")
    end
end

function addon.Debug:CreateIndependentTest()
    print("=== Creating Independent Test Frame ===")
    
    -- Create completely separate test frame
    local testFrame = CreateFrame("Frame", "CCRotationDebugFrame", UIParent)
    testFrame:SetSize(64, 64)
    testFrame:SetPoint("CENTER", UIParent, "CENTER", 100, 100)
    
    -- Add background
    local bg = testFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    
    -- Add icon
    local icon = testFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(2094) -- Try spell ID directly
    
    testFrame:Show()
    
    print("✓ Independent test frame created at center+100")
    print("You should see a black square with spell icon")
    
    -- Try different texture methods
    C_Timer.After(2, function()
        local spellInfo = C_Spell.GetSpellInfo(2094)
        if spellInfo then
            icon:SetTexture(spellInfo.iconID)
            print("✓ Set texture using spell info")
        end
    end)
end

function addon.Debug:DiagnoseQueue()
    print("=== Queue Diagnosis ===")
    
    -- Check LibOpenRaid
    local lib = LibStub("LibOpenRaid-1.0", true)
    if not lib then
        print("ERROR: LibOpenRaid-1.0 not found")
        return
    end
    print("✓ LibOpenRaid-1.0 loaded")
    
    -- Check cooldown data
    local data = lib.GetAllUnitsCooldown()
    if not data then
        print("❌ No cooldown data from LibOpenRaid")
        return
    end
    print("✓ LibOpenRaid has cooldown data")
    
    -- Show what units we have
    local unitCount = 0
    for unit, cds in pairs(data) do
        unitCount = unitCount + 1
        print("  Unit:", unit)
        local spellCount = 0
        for spellID, info in pairs(cds) do
            spellCount = spellCount + 1
            if spellCount <= 3 then -- Show first 3 spells
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                print("    Spell:", spellID, spellInfo and spellInfo.name or "unknown")
            end
        end
        if spellCount > 3 then
            print("    ... and", spellCount - 3, "more spells")
        end
    end
    print("Total units with cooldowns:", unitCount)
    
    -- Check our tracked spells
    print("\n--- Our Tracked Spells ---")
    local trackedCount = 0
    for spellID, info in pairs(addon.CCRotation.trackedCooldowns) do
        trackedCount = trackedCount + 1
        if trackedCount <= 5 then
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            print("  Tracking:", spellID, spellInfo and spellInfo.name or "unknown", "Type:", info.type)
        end
    end
    if trackedCount > 5 then
        print("  ... and", trackedCount - 5, "more tracked spells")
    end
    
    -- Check GUID mapping
    print("\n--- GUID Mapping ---")
    local playerGUID = UnitGUID("player")
    local mappedUnit = addon.CCRotation.GUIDToUnit[playerGUID]
    print("Player GUID:", playerGUID)
    print("Mapped to unit:", mappedUnit)
    
    -- Check current queue
    print("\n--- Current Queue ---")
    print("Queue length:", #addon.CCRotation.cooldownQueue)
    for i, cd in ipairs(addon.CCRotation.cooldownQueue) do
        if i <= 3 then
            local spellInfo = C_Spell.GetSpellInfo(cd.spellID)
            print("  Item", i .. ":", spellInfo and spellInfo.name or ("SpellID " .. cd.spellID))
        end
    end
    
    print("=== Diagnosis Complete ===")
end

function addon.Debug:DiagnoseTexture()
    print("=== Texture Diagnosis ===")
    
    local iconFrame = addon.UI.iconFrames and addon.UI.iconFrames[1]
    if not iconFrame then
        print("ERROR: No icon frame found")
        return
    end
    print("✓ Icon frame exists")
    
    -- Check name elements
    print("\n--- Name Elements ---")
    if iconFrame.spellName then
        print("Spell name element exists, text:", iconFrame.spellName:GetText() or "nil")
        print("Spell name shown:", iconFrame.spellName:IsShown())
        local point, relativeTo, relativePoint, x, y = iconFrame.spellName:GetPoint()
        print("Spell name position:", point, relativePoint, x, y)
    else
        print("❌ No spell name element")
    end
    
    if iconFrame.playerName then
        print("Player name element exists, text:", iconFrame.playerName:GetText() or "nil")
        print("Player name shown:", iconFrame.playerName:IsShown())
        local point, relativeTo, relativePoint, x, y = iconFrame.playerName:GetPoint()
        print("Player name position:", point, relativePoint, x, y)
    else
        print("❌ No player name element")
    end
    
    -- Check display icon texture
    if iconFrame.displayIcon then
        print("\nDisplay icon texture:", iconFrame.displayIcon:GetTexture() or "nil")
        print("Display icon shown:", iconFrame.displayIcon:IsShown())
    else
        print("❌ No display icon texture")
    end
    
    -- Test creating a fresh texture
    print("\n--- Creating Test Texture ---")
    if iconFrame.diagTexture then
        iconFrame.diagTexture:Hide()
    end
    
    iconFrame.diagTexture = iconFrame:CreateTexture("DiagTexture", "OVERLAY")
    iconFrame.diagTexture:SetAllPoints()
    iconFrame.diagTexture:SetTexture(132121) -- Incap Roar
    
    print("✓ Created diagnostic texture with Incap Roar")
    
    -- Test setting names
    if iconFrame.spellName then
        iconFrame.spellName:SetText("TEST SPELL NAME")
        iconFrame.spellName:Show()
        print("✓ Set test spell name")
    end
    
    if iconFrame.playerName then
        iconFrame.playerName:SetText("TEST PLAYER NAME")
        iconFrame.playerName:Show()
        print("✓ Set test player name")
    end
    
    print("=== Texture Diagnosis Complete ===")
end

function addon.Debug:ForceRebuild()
    print("=== Force Rebuild Queue ===")
    
    addon.CCRotation:RefreshGUIDToUnit()
    print("✓ Refreshed GUID mapping")
    
    -- Debug the rebuild process step by step
    print("\n--- Detailed Rebuild Process ---")
    
    local lib = LibStub("LibOpenRaid-1.0", true)
    local allUnits = lib.GetAllUnitsCooldown()
    
    if not allUnits then
        print("❌ No data from GetAllUnitsCooldown")
        return
    end
    
    print("✓ Got data from LibOpenRaid")
    
    -- Clear queue manually
    addon.CCRotation.cooldownQueue = {}
    
    -- Process each unit
    for unit, cds in pairs(allUnits) do
        print("Processing unit:", unit)
        local processedCount = 0
        
        for spellID, info in pairs(cds) do
            local trackedInfo = addon.CCRotation.trackedCooldowns[spellID]
            if trackedInfo then
                print("  Found tracked spell:", spellID, "trying to add to queue...")
                local success = addon.CCRotation:UpdateEntry(unit, spellID, info)
                if success then
                    processedCount = processedCount + 1
                    print("    ✓ Added to queue")
                else
                    print("    ❌ Failed to add to queue")
                end
            end
        end
        
        print("  Processed", processedCount, "spells for", unit)
    end
    
    print("Final queue length:", #addon.CCRotation.cooldownQueue)
    
    if #addon.CCRotation.cooldownQueue > 0 then
        print("✓ Queue has items - triggering display update")
        if addon.UI then
            addon.UI:UpdateDisplay(addon.CCRotation.cooldownQueue)
        end
    else
        print("❌ Queue still empty after manual rebuild")
    end
end

function addon.Debug:TestDisplayUpdate()
    print("=== Test Display Update ===")
    
    local queue = addon.CCRotation.cooldownQueue
    print("Current queue length:", #queue)
    
    if #queue == 0 then
        print("❌ Queue is empty - nothing to display")
        return
    end
    
    -- Show details of queue items
    for i, cd in ipairs(queue) do
        local spellInfo = C_Spell.GetSpellInfo(cd.spellID)
        local unit = addon.CCRotation.GUIDToUnit[cd.GUID]
        local now = GetTime()
        local isReady = (cd.charges and cd.charges > 0) or cd.expirationTime <= now
        
        print("Queue item", i .. ":")
        print("  Spell:", spellInfo and spellInfo.name or cd.spellID)
        print("  Unit:", unit)
        print("  Ready:", isReady)
        print("  Time left:", math.max(0, cd.expirationTime - now))
    end
    
    -- Force display update
    print("\n--- Forcing Display Update ---")
    addon.UI:UpdateDisplay(queue)
    print("✓ Display update called")
    
    -- Check if icons are showing
    local iconFrame = addon.UI.iconFrames[1]
    if iconFrame then
        print("Icon frame 1 shown:", iconFrame:IsShown())
        if iconFrame.displayIcon then
            print("Display icon shown:", iconFrame.displayIcon:IsShown())
        end
    end
end

function addon.Debug:TestInitTiming()
    print("=== Testing Initialization Timing ===")
    
    -- Check if LibOpenRaid is loaded
    local lib = LibStub("LibOpenRaid-1.0", true)
    if not lib then
        print("❌ LibOpenRaid-1.0 not found")
        return
    end
    print("✓ LibOpenRaid-1.0 loaded")
    
    -- Check if it has data immediately
    local data = lib.GetAllUnitsCooldown()
    if not data then
        print("❌ No cooldown data available immediately")
        
        -- Schedule checks at different intervals
        print("Scheduling delayed checks...")
        for _, delay in ipairs({0.5, 1, 2, 5}) do
            C_Timer.After(delay, function()
                local delayedData = lib.GetAllUnitsCooldown()
                if delayedData then
                    print("✓ LibOpenRaid has data after", delay, "seconds")
                    local unitCount = 0
                    for unit in pairs(delayedData) do
                        unitCount = unitCount + 1
                    end
                    print("  Units with cooldowns:", unitCount)
                else
                    print("❌ Still no data after", delay, "seconds")
                end
            end)
        end
    else
        print("✓ LibOpenRaid has data immediately")
        local unitCount = 0
        for unit in pairs(data) do
            unitCount = unitCount + 1
        end
        print("  Units with cooldowns:", unitCount)
    end
end

function addon.Debug:TestTextureSetup()
    print("=== Testing Texture Setup After Reload ===")
    
    -- Check if UI is initialized
    if not addon.UI or not addon.UI.iconFrames then
        print("❌ UI not initialized")
        return
    end
    
    print("✓ UI initialized")
    
    -- Check each icon frame texture setup
    for i = 1, 2 do
        local iconFrame = addon.UI.iconFrames[i]
        if iconFrame then
            print("Icon", i, "setup:")
            print("  Frame exists: ✓")
            print("  displayIcon exists:", iconFrame.displayIcon and "✓" or "❌")
            print("  glow exists:", iconFrame.glow and "✓" or "❌")
            
            if iconFrame.displayIcon then
                print("  displayIcon texture:", iconFrame.displayIcon:GetTexture() or "nil")
                print("  displayIcon shown:", iconFrame.displayIcon:IsShown())
            end
            
            if iconFrame.glow then
                print("  glow shown:", iconFrame.glow:IsShown())
                print("  glow texture:", iconFrame.glow:GetTexture() or "nil")
            end
        else
            print("Icon", i, "❌ frame missing")
        end
    end
    
    -- Test setting a texture immediately
    local iconFrame = addon.UI.iconFrames[1]
    if iconFrame and iconFrame.displayIcon then
        print("\\nTesting immediate texture set...")
        local spellInfo = C_Spell.GetSpellInfo(99) -- Incap Roar
        if spellInfo then
            iconFrame.displayIcon:SetTexture(spellInfo.iconID)
            iconFrame.displayIcon:Show()
            iconFrame:Show()
            addon.UI.mainFrame:Show()
            print("✓ Set test texture -", spellInfo.name)
        else
            print("❌ Could not get spell info")
        end
    end
end

function addon.Debug:FixBlackIcons()
    print("=== Fixing Black Icons ===")
    
    -- Get current queue
    local queue = addon.CCRotation.cooldownQueue
    if #queue == 0 then
        print("❌ No queue data to fix icons with")
        return
    end
    
    print("Found", #queue, "queue items to display")
    
    -- Force texture update for each visible icon
    for i = 1, math.min(#queue, 2) do
        local cooldownData = queue[i]
        local iconFrame = addon.UI.iconFrames[i]
        
        if cooldownData and iconFrame then
            local spellInfo = C_Spell.GetSpellInfo(cooldownData.spellID)
            if spellInfo then
                print("Fixing icon", i, "with", spellInfo.name)
                
                -- Force recreate the texture
                if iconFrame.displayIcon then
                    iconFrame.displayIcon:Hide()
                    iconFrame.displayIcon:SetTexture(nil)
                end
                
                -- Create fresh texture
                if iconFrame.fixedIcon then
                    iconFrame.fixedIcon:Hide()
                end
                iconFrame.fixedIcon = iconFrame:CreateTexture("FixedIcon_" .. i, "OVERLAY")
                iconFrame.fixedIcon:SetAllPoints()
                iconFrame.fixedIcon:SetTexture(spellInfo.iconID)
                iconFrame.fixedIcon:Show()
                
                -- Show the frame
                iconFrame:Show()
                addon.UI.mainFrame:Show()
                
                print("✓ Fixed icon", i)
            end
        end
    end
    
    print("Icon fix complete")
end

function addon.Debug:RefreshDisplay()
    print("=== Refreshing Display with Current Settings ===")
    
    -- Force update display with current queue
    local queue = addon.CCRotation.cooldownQueue
    if #queue > 0 then
        addon.UI:UpdateDisplay(queue)
        print("✓ Display refreshed with", #queue, "items")
    else
        print("❌ No queue data to refresh display")
    end
end

function addon.Debug:TestNewXMLTemplate()
    print("=== Testing New XML Template System ===")
    
    -- Hide old test icon if it exists
    local oldIcon = _G["TestXMLIcon"]
    if oldIcon then
        oldIcon:Hide()
    end
    
    -- Test creating icon directly
    local icon = CreateFrame("Button", "TestXMLIcon2", UIParent, "CCRotationIconTemplate")
    if icon then
        print("✓ XML template icon created")
        
        -- Test setting texture
        local spellInfo = C_Spell.GetSpellInfo(99) -- Incap Roar
        if spellInfo and icon.icon then
            print("✓ Icon texture element found")
            
            -- Try the same approach that worked in our manual fix
            icon.icon:SetTexture(spellInfo.iconID)
            print("✓ Texture set to:", spellInfo.iconID)
            
            -- Position and show
            icon:SetPoint("CENTER", UIParent, "CENTER", 100, 0) -- Offset so we can see both
            icon:SetSize(64, 64)
            icon:Show()
            
            -- Test texture display
            C_Timer.After(0.1, function()
                local texture = icon.icon:GetTexture()
                print("Texture result:", texture or "nil")
                print("Icon shown:", icon:IsShown())
                print("Icon texture shown:", icon.icon:IsShown())
                
                -- Try our working approach - create a new texture
                if not icon.workingTexture then
                    print("Creating working texture as fallback...")
                    icon.workingTexture = icon:CreateTexture("WorkingTexture", "OVERLAY")
                    icon.workingTexture:SetAllPoints()
                    icon.workingTexture:SetTexture(spellInfo.iconID)
                    icon.workingTexture:Show()
                    print("✓ Working texture created and shown")
                end
            end)
            
        else
            print("❌ Could not get spell info or icon.icon is nil")
        end
    else
        print("❌ Failed to create XML template icon")
    end
end

function addon.Debug:TestAllFeatures()
    print("=== Testing All Display Features ===")
    
    local queue = addon.CCRotation.cooldownQueue
    print("Current queue length:", #queue)
    
    if #queue == 0 then
        print("Queue is empty, trying to rebuild...")
        -- Only rebuild if queue is actually empty
        addon.CCRotation:DoRebuildQueue()
        
        -- Wait a moment for rebuild
        C_Timer.After(0.1, function()
            queue = addon.CCRotation.cooldownQueue
            print("Queue length after rebuild:", #queue)
            
            if #queue == 0 then
                print("❌ No queue items to test display features")
                return
            end
            
            -- Test with rebuilt queue
            addon.Debug:_TestDisplayElements(queue)
        end)
        return
    end
    
    -- Test with existing queue
    addon.Debug:_TestDisplayElements(queue)
end

function addon.Debug:_TestDisplayElements(queue)
    -- Update display
    addon.UI:UpdateDisplay(queue)
    
    -- Check all display elements
    for i = 1, math.min(#queue, 2) do
        local iconFrame = addon.UI.iconFrames[i]
        if iconFrame and iconFrame:IsShown() then
            print("Icon", i, "shown: ✓")
            
            -- Check texture
            if iconFrame.displayIcon and iconFrame.displayIcon:IsShown() then
                print("  Icon texture: ✓")
            else
                print("  Icon texture: ❌")
            end
            
            -- Check spell name
            if iconFrame.spellName and iconFrame.spellName:IsShown() then
                print("  Spell name:", iconFrame.spellName:GetText() or "nil")
            else
                print("  Spell name: ❌ hidden or missing")
            end
            
            -- Check player name
            if iconFrame.playerName and iconFrame.playerName:IsShown() then
                print("  Player name:", iconFrame.playerName:GetText() or "nil")
            else
                print("  Player name: ❌ hidden or missing")
            end
            
            -- Check cooldown text
            if iconFrame.cooldownText then
                print("  Cooldown text:", iconFrame.cooldownText:GetText() or "empty")
            else
                print("  Cooldown text: ❌ missing")
            end
            
            -- Check glow state
            if iconFrame.glow then
                print("  Glow shown:", iconFrame.glow:IsShown())
                if iconFrame.glowAnim then
                    print("  Glow animation playing:", iconFrame.glowAnim:IsPlaying())
                end
            else
                print("  Glow: ❌ missing")
            end
        else
            print("Icon", i, "shown: ❌")
        end
    end
end

function addon.Debug:CheckGlowStates()
    print("=== Checking Glow States ===")
    
    for i = 1, 2 do
        local iconFrame = addon.UI.iconFrames[i]
        if iconFrame then
            print("Icon", i .. ":")
            print("  Frame shown:", iconFrame:IsShown())
            print("  Glow shown:", iconFrame.glow and iconFrame.glow:IsShown() or "no glow")
            print("  Glow animation playing:", iconFrame.glowAnim and iconFrame.glowAnim:IsPlaying() or "no anim")
            
            -- Check glow positioning
            if iconFrame.glow then
                local point, relativeTo, relativePoint, x, y = iconFrame.glow:GetPoint()
                print("  Glow position:", point or "no point", relativePoint or "", x or 0, y or 0)
            end
        end
    end
end

function addon.Debug:HideAllGlows()
    print("=== Hiding All Glow Effects ===")
    
    for i = 1, 2 do
        local iconFrame = addon.UI.iconFrames[i]
        if iconFrame then
            if iconFrame.glow then
                iconFrame.glow:Hide()
                print("Hidden glow on icon", i)
            end
            if iconFrame.glowAnim then
                iconFrame.glowAnim:Stop()
                print("Stopped glow animation on icon", i)
            end
        end
    end
    
    -- Also hide any debug textures that might be lingering
    for i = 1, 2 do
        local iconFrame = addon.UI.iconFrames[i]
        if iconFrame then
            if iconFrame.testTexture then
                iconFrame.testTexture:Hide()
                print("Hidden test texture on icon", i)
            end
            if iconFrame.diagTexture then
                iconFrame.diagTexture:Hide()
                print("Hidden diagnostic texture on icon", i)
            end
        end
    end
    
    print("All glow effects and debug textures hidden")
end

function addon.Debug:FindAllTextures()
    print("=== Finding All Textures ===")
    
    for i = 1, 2 do
        local iconFrame = addon.UI.iconFrames[i]
        if iconFrame then
            print("Icon", i, "textures:")
            
            -- List all regions of the icon frame
            local regions = {iconFrame:GetRegions()}
            for j, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    local shown = region:IsShown()
                    print("  Texture", j .. ":", texture or "nil", "shown:", shown)
                    
                    -- Check if it's a glow-like texture
                    if texture and string.find(texture, "IconAlert") then
                        print("    ^ This is a glow texture!")
                        region:Hide()
                        print("    ^ Hidden!")
                    end
                end
            end
            
            -- Check named textures specifically
            local namedTextures = {
                "icon", "border", "glow", "displayIcon", "testTexture", "diagTexture"
            }
            
            for _, name in ipairs(namedTextures) do
                if iconFrame[name] then
                    print("  Named texture '" .. name .. "':", iconFrame[name]:IsShown())
                end
            end
        end
    end
    
    -- Also check if there's an independent test frame
    local testFrame = _G["CCRotationDebugFrame"]
    if testFrame then
        print("Independent test frame found - hiding it")
        testFrame:Hide()
    end
end

function addon.Debug:NukeAllTextures()
    print("=== NUCLEAR OPTION: Hiding All Textures ===")
    
    for i = 1, 2 do
        local iconFrame = addon.UI.iconFrames[i]
        if iconFrame then
            print("Nuking textures on icon", i)
            
            -- Hide all regions
            local regions = {iconFrame:GetRegions()}
            for j, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    if texture and (string.find(texture, "IconAlert") or string.find(texture, "Glow")) then
                        region:Hide()
                        print("  Hidden texture:", texture)
                    end
                end
            end
            
            -- Hide specific named textures
            if iconFrame.glow then
                iconFrame.glow:Hide()
                iconFrame.glow:SetAlpha(0)
                iconFrame.glow:SetTexture(nil)
            end
            if iconFrame.glowAnim then
                iconFrame.glowAnim:Stop()
            end
        end
    end
    
    -- Hide independent test frame
    local testFrame = _G["CCRotationDebugFrame"]
    if testFrame then
        testFrame:Hide()
    end
    
    print("Nuclear cleanup complete!")
end

-- Add slash command for easy testing
SLASH_CCDEBUG1 = "/ccdebug"
SlashCmdList["CCDEBUG"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "test" or command == "" then
        addon.Debug:TestIconDisplay()
    elseif command == "data" then
        addon.Debug:TestWithRealData()
    elseif command == "independent" then
        addon.Debug:CreateIndependentTest()
    elseif command == "queue" then
        addon.Debug:DiagnoseQueue()
    elseif command == "texture" then
        addon.Debug:DiagnoseTexture()
    elseif command == "rebuild" then
        addon.Debug:ForceRebuild()
    elseif command == "display" then
        addon.Debug:TestDisplayUpdate()
    elseif command == "timing" then
        addon.Debug:TestInitTiming()
    elseif command == "all" then
        addon.Debug:TestAllFeatures()
    elseif command == "glow" then
        addon.Debug:CheckGlowStates()
    elseif command == "hideglow" or command == "cleanglow" then
        addon.Debug:HideAllGlows()
    elseif command == "findtextures" then
        addon.Debug:FindAllTextures()
    elseif command == "nuke" then
        addon.Debug:NukeAllTextures()
    elseif command == "setup" then
        addon.Debug:TestTextureSetup()
    elseif command == "fix" or command == "fixicons" then
        addon.Debug:FixBlackIcons()
    elseif command == "refresh" then
        addon.Debug:RefreshDisplay()
    elseif command == "xmltest" then
        addon.Debug:TestNewXMLTemplate()
    else
        print("CC Rotation Debug Commands:")
        print("  /ccdebug test - Test icon display")
        print("  /ccdebug data - Test with real data")
        print("  /ccdebug independent - Create independent test frame")
        print("  /ccdebug queue - Diagnose queue system")
        print("  /ccdebug texture - Diagnose texture system") 
        print("  /ccdebug rebuild - Force rebuild queue")
        print("  /ccdebug display - Test display update with current queue")
        print("  /ccdebug timing - Test LibOpenRaid initialization timing")
        print("  /ccdebug all - Test all display features comprehensively")
        print("  /ccdebug glow - Check glow texture states and positioning")
        print("  /ccdebug hideglow - Hide all glow effects and debug textures")
        print("  /ccdebug findtextures - Find and analyze all textures")
        print("  /ccdebug nuke - Nuclear option: hide all glow-like textures")
        print("  /ccdebug setup - Test texture setup after reload")
        print("  /ccdebug fix - Force fix black icons using fresh textures")
        print("  /ccdebug refresh - Refresh display with current settings")
        print("  /ccdebug xmltest - Test XML template system directly")
    end
end