local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

-- UI Helper utilities for common UI patterns
addon.UI.Helpers = {}

--- Create a horizontal spacer
--- @param width number
function addon.UI.Helpers:HorizontalSpacer(width)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(width)

    return spacer
end

--- Create a vertical spacer
--- @param height number
function addon.UI.Helpers:VerticalSpacer(height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetFullWidth(true)
    spacer:SetHeight(height)

    return spacer
end

--- Open a confirmation dialog
--- @param name string - Unique string for dialog
--- @param prompt string
--- @param confirmText string
--- @param onConfirm function
--- @param declineText[opt=nil] string
--- @param onDecline[opt=nil] function
function addon.UI.Helpers:ConfirmationDialog(name, prompt, confirmText, onConfirm, declineText, onDecline)
    local DIALOG_PREFIX = "CCRH_CONFIRMATION_DIALOG_"
    StaticPopupDialogs[DIALOG_PREFIX..name] = {
        text = prompt,
        button1 = confirmText,
        button2 = declineText,
        OnAccept = onConfirm,
        OnCancel = onDecline,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show(DIALOG_PREFIX..name)
end