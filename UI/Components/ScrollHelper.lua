-- ScrollHelper.lua - Utility for preserving scroll position in AceGUI ScrollFrames
local addonName, addon = ...

local ScrollHelper = {}

-- Save the current scroll position of an AceGUI ScrollFrame
function ScrollHelper:saveScrollPosition(scrollFrame)
    if not scrollFrame then return 0 end
    
    -- AceGUI ScrollFrame stores scroll state in status or localstatus
    if scrollFrame.status and scrollFrame.status.scrollvalue then
        return scrollFrame.status.scrollvalue
    elseif scrollFrame.localstatus and scrollFrame.localstatus.scrollvalue then
        return scrollFrame.localstatus.scrollvalue
    end
    
    return 0
end

-- Restore scroll position to an AceGUI ScrollFrame
function ScrollHelper:restoreScrollPosition(scrollFrame, scrollValue)
    if not scrollFrame or not scrollValue or scrollValue <= 0 then return end
    
    -- Use AceGUI's built-in SetScroll method
    if scrollFrame.SetScroll then
        scrollFrame:SetScroll(scrollValue)
    end
end

-- Convenience method to refresh a container while preserving scroll
function ScrollHelper:refreshWithScrollPreservation(container, refreshCallback)
    if not container or not refreshCallback then return end
    
    -- Save current scroll position
    local scrollValue = self:saveScrollPosition(container)
    
    -- Execute the refresh callback (usually ReleaseChildren + buildUI)
    refreshCallback()
    
    -- Restore scroll position
    self:restoreScrollPosition(container, scrollValue)
end

-- Register in addon namespace
addon.ScrollHelper = ScrollHelper

return ScrollHelper