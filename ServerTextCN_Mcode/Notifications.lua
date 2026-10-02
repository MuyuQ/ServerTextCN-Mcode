-- A private notice frame: never send addon notices through announcement hooks.
local C = McodeSTCN
local N = { duration = 3, count = 0 }
C.Notifications = N
local moduleNames = { window = "窗口汉化", announcements = "战场播报与屏幕公告" }

function N.Layout()
    local frame = N.frame
    N.parentWidth = UIParent:GetWidth()
    local width = math.max(100, math.min(420, N.parentWidth - 48))
    frame:SetWidth(width)
    frame.heading:SetWidth(width - 24); frame.heading:SetHeight(0)
    frame.caption:SetWidth(width - 24); frame.caption:SetHeight(0)
    local headingHeight = math.ceil(frame.heading:GetStringHeight())
    local captionHeight = math.ceil(frame.caption:GetStringHeight())
    frame.heading:SetHeight(headingHeight); frame.caption:SetHeight(captionHeight)
    frame.caption:ClearAllPoints(); frame.caption:SetPoint("TOPLEFT", 12, -16 - headingHeight)
    frame:SetHeight(math.max(64, headingHeight + captionHeight + 28))
end

function N.Create()
    if N.frame then return end
    local frame = CreateFrame("Button", "McodeSTCNMissNotice", UIParent)
    N.frame = frame
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.06, 0.04, 0.01, 0.94)
    frame:SetBackdropBorderColor(1, 0.72, 0.12, 1)
    frame.heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.heading:SetPoint("TOPLEFT", 12, -12)
    frame.heading:SetJustifyH("CENTER"); frame.heading:SetTextColor(1, 0.82, 0.2)
    frame.caption = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.caption:SetJustifyH("CENTER")
    frame:SetScript("OnHide", function()
        N.count, N.deadline, N.module, N.key = 0, nil, nil, nil
    end)
    frame:SetScript("OnShow", function()
        -- UIParent may be hidden during cinematics or by Alt+Z.
        if not N.deadline or GetTime() >= N.deadline then frame:Hide() end
    end)
    frame:SetScript("OnUpdate", function()
        if N.deadline and GetTime() >= N.deadline then frame:Hide(); return end
        if N.parentWidth ~= UIParent:GetWidth() then N.Layout() end
    end)
    frame:SetScript("OnClick", function()
        if not N.deadline or GetTime() >= N.deadline then frame:Hide(); return end
        if InCombatLockdown() then
            C.Print("战斗结束后输入 /stcn show 查看。")
            return
        end
        C.Options.ShowMiss(N.module, N.key)
        frame:Hide()
    end)
    frame:Hide()
end

function N.Show(module, key)
    N.Create()
    local frame, now = N.frame, GetTime()
    if not frame:IsShown() or not N.deadline or now >= N.deadline then N.count = 0 end
    N.count, N.module, N.key = N.count + 1, module, key
    N.deadline = now + N.duration
    frame.heading:SetText(N.count == 1 and "发现未汉化文本，已记录"
        or "已记录 " .. N.count .. " 条未汉化文本")
    frame.caption:SetText((N.count > 1 and "最近：" or "") .. moduleNames[module] .. " · 点击查看记录")
    N.Layout(); frame:Show()
end
