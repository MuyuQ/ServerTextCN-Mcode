-- Native 3.3.5 settings: built-in translation switches and read-only feedback.
local C = McodeSTCN
local O = { pages = {}, maxRows = 6 }
C.Options = O
local moduleNames = { window = "窗口汉化", announcements = "战场播报与屏幕公告" }
local sourceNames = { bg = "战场系统播报", system = "系统通知", boss = "首领公告", info = "屏幕信息提示" }
local tagNames = { exact = "精确匹配", ["exact-npc"] = "NPC骨架匹配", builtin = "内置公告规则",
    custom = "旧版手动规则", ["custom-builtin"] = "旧版手动覆盖" }

local function create(kind, name, parent, template)
    O.serial = (O.serial or 0) + 1
    -- Native scroll templates resolve ScrollBar by the frame's global name.
    return CreateFrame(kind, name or ("McodeSTCNWidget" .. O.serial), parent, template)
end

local function shown(frame, value) if value then frame:Show() else frame:Hide() end end
local function enabled(frame, value) if value then frame:Enable() else frame:Disable() end end

local function label(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y); fs:SetJustifyH("LEFT"); fs:SetText(text)
    return fs
end

local function button(parent, text, width, fn)
    local b = create("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(23); b:SetText(text); b:SetScript("OnClick", fn)
    return b
end

local function check(parent, text, x, y, getter, setter)
    local box = create("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetWidth(24); box:SetHeight(24); box:SetPoint("TOPLEFT", x, y)
    box.caption = label(box, text, 26, -5, "GameFontHighlightSmall")
    box:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false); C.Notify() end)
    box.sync = function() box:SetChecked(getter()) end
    return box
end

local function visibleText(raw)
    return tostring(raw or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
end

local function short(raw, count)
    raw = visibleText(raw):gsub("%s+", " ")
    local pos, characters = 1, 0
    while pos <= #raw and characters < count do
        local first = raw:byte(pos)
        pos = pos + (first < 128 and 1 or first < 224 and 2 or first < 240 and 3 or 4)
        characters = characters + 1
    end
    return pos <= #raw and raw:sub(1, pos - 1) .. "…" or raw
end

local function textField(parent)
    local border = create("Frame", nil, parent)
    border:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    border:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
    local scroll = create("ScrollFrame", nil, border, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 7, -7); scroll:SetPoint("BOTTOMRIGHT", -27, 7)
    local edit = create("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(GameFontHighlight)
    edit:SetMaxLetters(0); edit:SetWidth(300); edit:SetHeight(100)
    local function fit()
        local text = edit:GetText() or ""
        local _, newlines = text:gsub("\n", "")
        -- Conservative height leaves enough scroll range for long Chinese paragraphs.
        local columns = math.max(10, math.floor(edit:GetWidth() / 14))
        edit:SetHeight(math.max(100, (math.ceil(#text / columns) + newlines + 3) * 16))
        scroll:UpdateScrollChildRect()
    end
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(self.originalText or ""); return end
        fit()
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnCursorChanged", function(_, _, cursorY, _, lineHeight)
        local top, cursor = scroll:GetVerticalScroll(), -cursorY
        if cursor < top then scroll:SetVerticalScroll(math.max(0, cursor))
        elseif cursor + lineHeight > top + scroll:GetHeight() then
            scroll:SetVerticalScroll(math.max(0, cursor + lineHeight - scroll:GetHeight()))
        end
    end)
    edit.SetReadOnlyText = function(self, text)
        self.originalText = tostring(text or "")
        self:SetText(self.originalText); self:ClearFocus(); scroll:SetVerticalScroll(0)
    end
    scroll:SetScrollChild(edit)
    border:SetScript("OnSizeChanged", function()
        edit:SetWidth(math.max(100, border:GetWidth() - 40)); fit()
    end)
    border.edit, border.scroll = edit, scroll
    return border
end

function O.Confirm(text, action)
    StaticPopupDialogs["MCODE_STCN_CONFIRM"] = {
        text = "%s", button1 = ACCEPT or "确认", button2 = CANCEL or "取消",
        OnAccept = function(self) if self.data then self.data() end end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    local dialog = StaticPopup_Show("MCODE_STCN_CONFIRM", text)
    if dialog then dialog.data = action end
end

function O.RecordText(module, item, feedback)
    local lines = {}
    if feedback then lines[#lines + 1] = "ServerTextCN_Mcode " .. C.version .. " · " .. moduleNames[module] end
    lines[#lines + 1] = item.cn and "【汉化记录】" or "【未汉化记录】"
    lines[#lines + 1] = "原文：\n" .. (feedback and tostring(item.rawText or item.t or "") or visibleText(item.rawText or item.t))
    if item.cn then lines[#lines + 1] = "译文：\n" .. (feedback and tostring(item.cn) or visibleText(item.cn)) end
    if item.displayText and item.displayText ~= item.rawText then
        lines[#lines + 1] = "屏幕原文：\n" .. visibleText(item.displayText)
    end
    if item.displayTranslation and item.displayTranslation ~= item.cn then
        lines[#lines + 1] = "屏幕译文：\n" .. visibleText(item.displayTranslation)
    end
    local source = sourceNames[item.source] or item.k or "未知"
    local context = "来源：" .. source
    if item.n and item.n ~= "" then context = context .. "\nNPC：" .. item.n end
    if item.npcID then context = context .. "（ID " .. tostring(item.npcID) .. "）" end
    if item.z and item.z ~= "" then context = context .. "\n地点：" .. item.z end
    if item.c and item.c ~= "" then context = context .. " " .. item.c end
    if item.speaker and item.speaker ~= "" then context = context .. "\n发言者：" .. item.speaker end
    if item.event then context = context .. "\n事件：" .. item.event end
    context = context .. "\n最近出现：" .. tostring(item.d or "未知") .. " · 次数：" .. tostring(item.count or 1)
    context = context .. "\n采集时词典版本：" .. tostring(item.dictionaryVersion or "未记录（旧版记录）")
    context = context .. "\n采集时插件版本：" .. tostring(item.version or "未记录")
    if item.h then context = context .. "\n匹配：" .. (tagNames[item.h] or tostring(item.h)) end
    if item.player and item.player.name and item.player.name ~= "" then
        context = context .. "\n采集时角色：" .. item.player.name
    end
    if item.history or item.legacy then
        context = context .. "\n旧版历史记录；译文不代表当前内置词典，缺失的现场信息未补造。"
    end
    lines[#lines + 1] = context
    local hints = C.VariableHints.Describe(module, item)
    lines[#lines + 1] = feedback and hints or visibleText(hints)
    return table.concat(lines, "\n\n")
end

function O.CopyFeedback(page)
    if not page.selected then return end
    if not O.copyFrame then
        local frame = create("Frame", "McodeSTCNFeedback", UIParent)
        frame:SetFrameStrata("DIALOG"); frame:SetWidth(510); frame:SetHeight(360)
        frame:SetPoint("CENTER"); frame:EnableMouse(true)
        frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32,
            edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        label(frame, "复制汉化反馈", 20, -20, "GameFontNormalLarge")
        label(frame, "文字已选中，按 Ctrl+C 复制后可粘贴到论坛。", 20, -47, "GameFontHighlightSmall")
        local field = textField(frame)
        field:SetPoint("TOPLEFT", 20, -73); field:SetPoint("BOTTOMRIGHT", -20, 52)
        local close = button(frame, "关闭", 80, function() frame:Hide() end)
        close:SetPoint("BOTTOMRIGHT", -20, 18)
        frame:SetScript("OnHide", function() field.edit:ClearFocus() end)
        field.edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        tinsert(UISpecialFrames, "McodeSTCNFeedback")
        frame.field = field
        frame:Hide(); O.copyFrame = frame
    end
    local frame = O.copyFrame
    frame:Show()
    frame.field.edit:SetReadOnlyText(O.RecordText(page.module, page.selected, true))
    frame.field.edit:SetFocus(); frame.field.edit:HighlightText()
end

function O.Select(page, item)
    -- Keep the viewed/copyable record stable while new events refresh the list.
    page.selected = C.Copy(item)
    page.details.edit:SetReadOnlyText(O.RecordText(page.module, item, false))
    enabled(page.copy, true)
    O.RefreshList(page)
end

function O.RefreshList(page)
    local state, results = McodeSTCN_DB.ui[page.module], {}
    local list = C.List(page.module, state.tab == "hits")
    local query = string.lower(state.query or "")
    for i = #list, 1, -1 do
        local item = list[i]
        local haystack = string.lower(tostring(item.rawText or item.t or "") .. " " .. tostring(item.cn or "")
            .. " " .. tostring(item.n or "") .. " " .. tostring(item.z or "") .. " " .. tostring(item.k or "")
            .. " " .. tostring(sourceNames[item.source] or ""))
        if query == "" or haystack:find(query, 1, true) then results[#results + 1] = item end
    end
    local count = page.rowCount or 4
    state.offset = math.floor(math.max(0, math.min(state.offset or 0,
        math.max(0, math.ceil(#results / count) - 1) * count)) / count) * count
    for i, row in ipairs(page.rows) do
        local item = i <= count and results[state.offset + i] or nil
        row.item = item
        shown(row, item ~= nil)
        if item then
            local who = page.module == "window" and (item.n ~= "" and item.n or item.k)
                or (sourceNames[item.source] or item.k)
            row.text:SetText(tostring(who or "未知") .. " · " .. short(item.rawText or item.t, 60))
            row.meta:SetText(tostring(item.d or "未知") .. " · " .. tostring(item.count or 1) .. "次"
                .. ((item.history or item.legacy) and " · 历史" or ""))
            if page.selected and page.selected.key == item.key then row:LockHighlight() else row:UnlockHighlight() end
        end
    end
    page.title:SetText((state.tab == "hits" and "汉化记录" or "未汉化记录") .. "（" .. #results .. "）")
    page.toggle:SetText(state.tab == "hits" and "查看未汉化记录" or "查看汉化记录")
    page.empty:SetText(#results == 0 and (query ~= "" and "没有找到符合搜索条件的记录。"
        or state.tab == "hits" and "尚无汉化记录。成功翻译后会在这里留下原文与译文。"
        or "尚无未汉化记录。开启收集后，遇到漏译可以回来查看并复制反馈。") or "")
    enabled(page.previous, state.offset > 0)
    enabled(page.next, state.offset + count < #results)
    enabled(page.clear, #list > 0)
    page.pageLabel:SetText(tostring(math.floor(state.offset / count) + 1) .. " / " .. math.max(1, math.ceil(#results / count)))
end

function O.Layout(page)
    local panel = page.panel
    local width, height = panel:GetWidth(), panel:GetHeight()
    local reserved = page.sourcesOpen and (page.module == "announcements" and 216 or 140) or 96
    local available = math.max(130, height - 132 - reserved)
    local rows = math.max(page.sourcesOpen and 1 or 2,
        math.min(O.maxRows, math.floor(available * 0.40 / 35)))
    page.rowCount = rows
    for i, row in ipairs(page.rows) do
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 16, -116 - (i - 1) * 35)
        row:SetPoint("TOPRIGHT", -16, -116 - (i - 1) * 35); row:SetHeight(34)
    end
    local pagerY = -120 - rows * 35
    page.previous:ClearAllPoints(); page.previous:SetPoint("TOPLEFT", 16, pagerY)
    page.next:ClearAllPoints(); page.next:SetPoint("TOPLEFT", 88, pagerY)
    page.pageLabel:ClearAllPoints(); page.pageLabel:SetPoint("TOPLEFT", 164, pagerY - 5)
    page.details:ClearAllPoints()
    page.details:SetPoint("TOPLEFT", 16, pagerY - 30)
    page.details:SetPoint("BOTTOMRIGHT", -16, reserved + 10)
    local enoughSpace = height - 160 - rows * 35 - reserved >= 35
    shown(page.details, enoughSpace)
    page.compactHint:ClearAllPoints()
    page.compactHint:SetPoint("TOPLEFT", 16, pagerY - 30)
    page.compactHint:SetPoint("TOPRIGHT", -16, pagerY - 30)
    shown(page.compactHint, not enoughSpace and page.sourcesOpen)
    page.search:SetWidth(math.max(100, width - 216))
    O.RefreshList(page)
end

function O.BuildPage(panel, module)
    local page = { panel = panel, module = module, rows = {}, boxes = {} }
    O.pages[module] = page
    label(panel, moduleNames[module], 16, -16, "GameFontNormalLarge")
    page.boxes[1] = check(panel, module == "window" and "启用窗口汉化" or "启用播报与公告汉化", 12, -39,
        function() if module == "window" then return McodeSTCN_DB.enabled end; return McodeSTCN_DB.announcements.enabled end,
        function(value) if module == "window" then McodeSTCN_DB.enabled = value else McodeSTCN_DB.announcements.enabled = value end end)
    page.status = label(panel, "", 0, 0, "GameFontHighlightSmall")
    page.status:ClearAllPoints(); page.status:SetPoint("TOPRIGHT", -16, -45)
    label(panel, "搜索", 16, -80, "GameFontHighlightSmall")
    local search = create("EditBox", nil, panel, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 55, -74); search:SetHeight(23); search:SetWidth(220)
    search:SetAutoFocus(false); search:SetMaxLetters(200)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local state = McodeSTCN_DB.ui[module]
            state.query, state.offset = self:GetText(), 0
            page.searchDelay = 0.2
        end
    end)
    page.search = search
    page.toggle = button(panel, "查看汉化记录", 136, function()
        local state = McodeSTCN_DB.ui[module]
        state.tab, state.offset = state.tab == "hits" and "misses" or "hits", 0
        page.selected = nil
        page.details.edit:SetReadOnlyText("点击记录查看完整原文与现场。")
        enabled(page.copy, false); O.RefreshList(page)
    end)
    page.toggle:SetPoint("TOPRIGHT", -16, -74)
    page.title = label(panel, "未汉化记录", 16, -101)
    page.empty = label(panel, "", 20, -133, "GameFontHighlightSmall")
    page.empty:SetPoint("TOPRIGHT", -24, -133); page.empty:SetHeight(80); page.empty:SetJustifyV("TOP")
    for i = 1, O.maxRows do
        local row = create("Button", nil, panel)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.text = label(row, "", 4, -2, "GameFontHighlightSmall")
        row.text:SetPoint("TOPRIGHT", -4, -2); row.text:SetHeight(15)
        row.meta = label(row, "", 4, -18, "GameFontHighlightSmall")
        row.meta:SetPoint("TOPRIGHT", -4, -18); row.meta:SetHeight(14)
        row:SetScript("OnClick", function(self) if self.item then O.Select(page, self.item) end end)
        page.rows[i] = row
    end
    page.previous = button(panel, "上一页", 65, function()
        local state = McodeSTCN_DB.ui[module]
        state.offset = math.max(0, state.offset - page.rowCount); O.RefreshList(page)
    end)
    page.next = button(panel, "下一页", 65, function()
        local state = McodeSTCN_DB.ui[module]
        state.offset = state.offset + page.rowCount; O.RefreshList(page)
    end)
    page.pageLabel = label(panel, "", 164, -230, "GameFontHighlightSmall")
    page.details = textField(panel)
    page.details.edit:SetReadOnlyText("点击记录查看完整原文与现场。")
    page.compactHint = label(panel, "收起收集设置可查看完整原文与现场。", 0, 0, "GameFontHighlightSmall")
    page.compactHint:SetHeight(25); page.compactHint:SetJustifyV("TOP"); page.compactHint:Hide()
    page.copy = button(panel, "复制反馈", 100, function() O.CopyFeedback(page) end)
    page.copy:SetPoint("BOTTOMLEFT", 16, 14); enabled(page.copy, false)
    page.clear = button(panel, "清空当前记录", 120, function()
        local hits = McodeSTCN_DB.ui[module].tab == "hits"
        O.Confirm("清空“" .. moduleNames[module] .. "”的全部" .. (hits and "汉化记录" or "未汉化记录") .. "？", function()
            local owner = module == "window" and McodeSTCN_DB or McodeSTCN_DB.announcements
            owner[hits and "hits" or "misses"] = {}
            McodeSTCN_DB.ui[module].offset = 0
            page.selected = nil; enabled(page.copy, false)
            page.details.edit:SetReadOnlyText("当前记录已清空。"); C.Notify("records")
        end)
    end)
    page.clear:SetPoint("BOTTOMRIGHT", -16, 14)
    local guide = label(panel, "AI 补译方法与提示词：请阅读插件目录内《README.md》。", 0, 0, "GameFontHighlightSmall")
    guide:ClearAllPoints(); guide:SetPoint("BOTTOMLEFT", 16, 41); guide:SetPoint("BOTTOMRIGHT", -16, 41)
    guide:SetHeight(25); guide:SetJustifyV("TOP")
    page.sources = create("Frame", nil, panel)
    page.sources:SetPoint("BOTTOMLEFT", 12, 101); page.sources:SetPoint("BOTTOMRIGHT", -16, 101)
    page.sources:SetHeight(module == "announcements" and 110 or 34); page.sources:Hide()
    page.boxes[2] = check(page.sources, "收集未汉化文本并在聊天框提示", 0, -4,
        function() if module == "window" then return McodeSTCN_DB.windowCollect end; return McodeSTCN_DB.announcements.collect end,
        function(value) if module == "window" then McodeSTCN_DB.windowCollect = value else McodeSTCN_DB.announcements.collect = value end end)
    if module == "announcements" then
        for i, source in ipairs({ "bg", "system", "boss", "info" }) do
            local key = source
            page.boxes[#page.boxes + 1] = check(page.sources, sourceNames[key],
                i % 2 == 1 and 0 or 204, i <= 2 and -40 or -73,
                function() return McodeSTCN_DB.announcements.sources[key] end,
                function(value) McodeSTCN_DB.announcements.sources[key] = value end)
        end
    end
    page.settings = button(panel, "展开收集设置", 120, function()
        page.sourcesOpen = not page.sourcesOpen
        shown(page.sources, page.sourcesOpen)
        page.settings:SetText(page.sourcesOpen and "收起收集设置" or "展开收集设置")
        O.Layout(page)
    end)
    page.settings:SetPoint("BOTTOMLEFT", 16, 71)
    panel:SetScript("OnSizeChanged", function() O.Layout(page) end)
    panel:SetScript("OnShow", function()
        McodeSTCN_DB.ui.lastModule = module
        page.search:SetText(McodeSTCN_DB.ui[module].query)
        for _, box in ipairs(page.boxes) do box.sync() end
        O.RefreshStatus(page)
        O.Layout(page)
    end)
    panel:SetScript("OnHide", function()
        page.search:ClearFocus(); page.details.edit:ClearFocus()
    end)
    panel:SetScript("OnUpdate", function(_, elapsed)
        if page.searchDelay then
            page.searchDelay = page.searchDelay - elapsed
            if page.searchDelay <= 0 then page.searchDelay = nil; page.refreshNeeded = true end
        end
        if page.refreshNeeded then page.refreshNeeded = nil; O.RefreshList(page) end
    end)
    O.Layout(page)
    return page
end

function O.RefreshStatus(page)
    local value = page.module == "window" and McodeSTCN_DB.enabled
        or page.module == "announcements" and McodeSTCN_DB.announcements.enabled
    page.status:SetText(not value and "已关闭"
        or page.module == "announcements" and C.announcementConflict and "旧插件冲突，已暂停"
        or "运行中")
end

function O.Show(module)
    if not O.registered then O.Register() end
    module = module or McodeSTCN_DB.ui.lastModule
    if not O.pages[module] then module = "window" end
    McodeSTCN_DB.ui.lastModule = module
    if type(InterfaceOptionsFrame_OpenToCategory) == "function" then
        InterfaceOptionsFrame_OpenToCategory(O.pages[module].panel)
        InterfaceOptionsFrame_OpenToCategory(O.pages[module].panel)
    else C.Print("请打开 ESC → 界面 → 插件 → 服务器文本汉化。") end
end

function O.ShowMiss(module, key)
    -- Resolve the live miss; it may have been translated or cleared since the notice.
    local list, item, index = C.List(module, false)
    for i, candidate in ipairs(list) do
        if candidate.key == key then item, index = candidate, i; break end
    end
    if not item then C.Print("这条未汉化记录已汉化或清除，请在设置页查看现有记录。"); return false end
    local state = McodeSTCN_DB.ui[module]
    state.tab, state.query, state.offset = "misses", "", 0
    O.Show(module)
    local page = O.pages[module]
    state.offset = math.floor((#list - index) / page.rowCount) * page.rowCount
    O.Select(page, item)
    return true
end

function O.Register()
    if O.registered or not C.ready or type(InterfaceOptions_AddCategory) ~= "function" then return end
    O.registered = true
    local parent = InterfaceOptionsFramePanelContainer or UIParent
    local root = create("Frame", "McodeSTCNOptions", parent)
    -- 界面插件列表显示中文名；右栏标题用"插件名 + 中文名"（2026-10-05 用户定案）。
    root.name = "服务器文本汉化"; root:SetAllPoints(parent); root:Hide()
    label(root, "ServerTextCN_Mcode 服务器文本汉化", 16, -16, "GameFontNormalLarge")
    local scroll = create("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -50); scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    local content = create("Frame", nil, scroll)
    content:SetWidth(400); content:SetHeight(600); scroll:SetScrollChild(content)
    root.scroll, root.content, root.sections = scroll, content, {}
    for _, section in ipairs({
        { "插件作用", "汉化服务器提供的 NPC 对话、选项，以及战场播报和屏幕公告。\n两个功能可在左侧子页面分别开启。" },
        { "汉化范围", "汉化内容取决于内置词典的收录情况，未收录的文字会保留原文。\n本插件不翻译玩家聊天，也不提供实时机器翻译。" },
        { "使用方法", "开启对应功能后，插件会自动汉化已收录的内容。\n开启漏译收集后，发现未汉化英文时，会自动记录并在聊天框提示。\n可在对应页面查看、复制反馈。\n输入 /stcn show 可直接打开上次使用的功能页。" },
        { "内置词典位置", "插件目录：\n游戏目录\\Interface\\AddOns\\ServerTextCN_Mcode\\\n\n窗口汉化词典：\nServerTextCN_Mcode_Data.lua\n\n战场播报与屏幕公告词典：\nAnnouncementRules.lua\n\n使用说明与 AI 补译提示词：\nREADME.md" },
        { "更新汉化", "遇到未收录的内容，需要补充或更新内置词典。\n你可以将对应词典文件和漏译记录交给 AI，请它辅助翻译并回填词典。\n具体步骤及可直接复制的 AI 提示词，请阅读插件目录内《README.md》。\n修改词典时须同步更新词典版本号，保存文件后输入 /reload 生效。" },
    }) do
        local heading = label(content, section[1], 0, 0)
        local body = label(content, section[2], 0, 0, "GameFontHighlight")
        body:SetJustifyV("TOP")
        if body.SetNonSpaceWrap then body:SetNonSpaceWrap(true) end
        root.sections[#root.sections + 1] = { heading = heading, body = body }
    end
    local note = label(content, "", 0, 0, "GameFontHighlightSmall")
    note:SetJustifyV("TOP"); root.note = note
    local debug = check(content, "开启调试日志（窗口匹配）", 0, 0,
        function() return McodeSTCN_DB.debug end,
        function(value) McodeSTCN_DB.debug = value end)
    root.debug = debug
    local debugHelp = label(content, "排查问题时开启，会在聊天框打印匹配方式、原文和译文。\n普通漏译提醒不需要开启此选项。", 0, 0, "GameFontHighlightSmall")
    debugHelp:SetJustifyV("TOP")
    local conflict = button(content, "停用旧版并重载", 170, function()
        O.Confirm("停用旧 Mcode_BGTextCN 并重载？合并版会接管播报汉化。", function()
            local ok, err = C.Announcements.DisableOld(); if not ok then C.Print(err) end
        end)
    end)
    root.layout = function()
        local width, y = math.max(100, scroll:GetWidth() - 8), 0
        content:SetWidth(width)
        local function placeText(fs)
            fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 0, -y); fs:SetWidth(width)
            fs:SetHeight(0)
            local height = math.ceil(fs:GetStringHeight()) + 4
            fs:SetHeight(height); y = y + height
        end
        for _, section in ipairs(root.sections) do
            placeText(section.heading); y = y + 4
            placeText(section.body); y = y + 16
        end
        placeText(note); y = y + 14
        debug:ClearAllPoints(); debug:SetPoint("TOPLEFT", -4, -y); y = y + 30
        placeText(debugHelp); y = y + 12
        conflict:ClearAllPoints(); conflict:SetPoint("TOPLEFT", 0, -y)
        if C.announcementConflict then y = y + 35 end
        content:SetHeight(y + 8); scroll:UpdateScrollChildRect()
    end
    root:SetScript("OnSizeChanged", function() root.layout() end)
    root:SetScript("OnShow", function()
        debug.sync(); shown(conflict, C.announcementConflict == true)
        note:SetText("插件版本 " .. C.version .. "\n窗口词典 " .. C.DictionaryVersion("window") .. "\n"
            .. "公告词典 " .. C.DictionaryVersion("announcements")
            .. (C.announcementConflict and "\n旧战场插件正在运行，公告模块已暂停。" or ""))
        root.layout()
    end)
    InterfaceOptions_AddCategory(root); O.root = root
    for _, module in ipairs({ "window", "announcements" }) do
        local panel = create("Frame", module == "window" and "McodeSTCNWindowOptions" or "McodeSTCNAnnouncementOptions", parent)
        panel.name, panel.parent = moduleNames[module], root.name
        panel:SetAllPoints(parent); panel:Hide()
        O.BuildPage(panel, module); InterfaceOptions_AddCategory(panel)
    end
    C.listeners[#C.listeners + 1] = function(reason)
        for _, page in pairs(O.pages) do
            if page.panel:IsShown() then
                page.refreshNeeded = true
                if reason ~= "records" then
                    for _, box in ipairs(page.boxes) do box.sync() end
                    O.RefreshStatus(page)
                end
            end
        end
        if reason ~= "records" and root:IsShown() then root:GetScript("OnShow")(root) end
    end
end
