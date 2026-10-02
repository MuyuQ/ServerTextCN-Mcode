-- Source-aware event collection, pure display translation and legacy display fallback.
local C = McodeSTCN
local A = { hookedFrames = {}, inEvent = 0 }
C.Announcements = A
A.events = {
    CHAT_MSG_BG_SYSTEM_NEUTRAL = "bg", CHAT_MSG_BG_SYSTEM_ALLIANCE = "bg", CHAT_MSG_BG_SYSTEM_HORDE = "bg",
    CHAT_MSG_SYSTEM = "system", SYSMSG = "system", UI_INFO_MESSAGE = "info",
    CHAT_MSG_RAID_BOSS_EMOTE = "boss", CHAT_MSG_RAID_BOSS_WHISPER = "boss",
}
A.sourceNames = { bg = "战场系统播报", system = "系统通知", boss = "首领公告", info = "屏幕信息提示" }

function A.Context(event, speaker, raw, translated)
    if A.events[event] ~= "boss" or type(speaker) ~= "string" then speaker = nil end
    local ctx = C.Context(A.sourceNames[A.events[event]] or "未知来源", event, speaker)
    ctx.source, ctx.npc, ctx.npcID, ctx.npcGUID = A.events[event], "", nil, nil
    if ctx.source == "boss" and speaker then
        ctx.displayPrefix = _G["CHAT_" .. event:sub(10) .. "_GET"] or ""
        if raw then ctx.displayText = C.Read(string.format, ctx.displayPrefix .. raw, speaker, speaker) end
        if translated then ctx.displayTranslation = C.Read(string.format, ctx.displayPrefix .. translated, speaker, speaker) end
    end
    return ctx
end

function A.Translate(raw, event, speaker)
    if not C.Enabled("announcements") or type(raw) ~= "string" or raw == "" then return nil end
    local ctx = A.Context(event, speaker)
    local cn, tag, meta = C.AnnouncementRules.Translate(raw, ctx.source)
    if cn and ctx.source == "boss" and type(speaker) == "string"
        and not C.Read(string.format, (ctx.displayPrefix or "") .. cn, speaker, speaker) then return nil end
    return cn, tag, meta
end

function A.CheckConflict()
    local loaded = type(IsAddOnLoaded) == "function" and IsAddOnLoaded("Mcode_BGTextCN")
    local was = C.announcementConflict
    C.announcementConflict = loaded and true or false
    if C.announcementConflict and not was then
        C.Print("旧 Mcode_BGTextCN 仍在运行，合并版公告模块已暂停。请在管理页停用旧版并重载。")
    end
    return C.announcementConflict
end

function A.DisableOld()
    if type(DisableAddOn) ~= "function" then return nil, "当前客户端没有停用插件接口，请在角色选择页停用旧版。" end
    DisableAddOn("Mcode_BGTextCN")
    if type(ReloadUI) == "function" then ReloadUI() end
    return true
end

local function pack(...) return { n = select("#", ...), ... } end

function A.WrapFrame(frame)
    if not frame or not frame.GetScript or not frame.SetScript then return end
    local previous = frame:GetScript("OnEvent")
    if A.hookedFrames[frame] == previous then return end
    if type(previous) ~= "function" then return end
    local wrapper = function(self, event, ...)
        local source = A.events[event]
        if not source or A.inEvent > 0 or not C.Enabled("announcements") then return previous(self, event, ...) end
        local args = pack(...)
        local translated = A.Translate(args[1], event, args[2])
        if translated then args[1] = translated end
        A.inEvent = A.inEvent + 1
        local results = pack(pcall(previous, self, event, unpack(args, 1, args.n)))
        A.inEvent = A.inEvent - 1
        if not results[1] then error(results[2]) end
        return unpack(results, 2, results.n)
    end
    frame:SetScript("OnEvent", wrapper)
    A.hookedFrames[frame] = wrapper
end

function A.TryDisplayHooks()
    if A.CheckConflict() then return end
    A.WrapFrame(RaidBossEmoteFrame)
    A.WrapFrame(UIErrorsFrame)
    if not A.raidHook and type(RaidNotice_AddMessage) == "function" then
        local previous = RaidNotice_AddMessage
        RaidNotice_AddMessage = function(frame, raw, ...)
            if A.inEvent == 0 and C.Enabled("announcements") then
                -- A direct display call has no trusted source. Only the old built-in rules run here.
                local cn = C.AnnouncementRules.Translate(raw)
                if cn then raw = cn end
            end
            return previous(frame, raw, ...)
        end
        A.raidHook = true
    end
    if not A.errorHook and UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
        local previous = UIErrorsFrame.AddMessage
        local wrapper = function(self, raw, ...)
            if A.inEvent == 0 and C.Enabled("announcements") then
                local cn = C.AnnouncementRules.Translate(raw)
                if cn then raw = cn end
            end
            return previous(self, raw, ...)
        end
        local ok = pcall(function() UIErrorsFrame.AddMessage = wrapper end)
        if ok and UIErrorsFrame.AddMessage == wrapper then A.errorHook = true end
    end
end

function A.Install()
    if A.CheckConflict() then return end
    if not A.installed then
        A.installed = true
        if type(ChatFrame_AddMessageEventFilter) == "function" then
            for event in pairs(A.events) do
                if event:sub(1, 9) == "CHAT_MSG_" then
                    ChatFrame_AddMessageEventFilter(event, function(_, ev, raw, ...)
                        local cn = A.Translate(raw, ev, select(1, ...))
                        if cn then return false, cn, ... end
                        return nil
                    end)
                end
            end
        end
        local collector = CreateFrame("Frame")
        for event in pairs(A.events) do collector:RegisterEvent(event) end
        collector:SetScript("OnEvent", function(_, event, raw, speaker)
            if not C.Enabled("announcements") or type(raw) ~= "string" then return end
            local cn, tag, meta = A.Translate(raw, event, speaker)
            local ctx = A.Context(event, speaker, raw, cn)
            -- Chat filters may run once per chat frame. Counting only here avoids duplicate encounters.
            C.Record("announcements", raw, cn, tag, ctx, meta)
        end)
        A.collector = collector
    end
    A.TryDisplayHooks()
end
