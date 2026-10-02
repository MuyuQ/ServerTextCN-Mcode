-- ServerTextCN_Mcode 3.1 entry point. /bgcn deliberately has no registration here.
local C = McodeSTCN
local loader = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_LOGIN",
    "GOSSIP_CLOSED", "QUEST_FINISHED", "TRAINER_CLOSED" }) do loader:RegisterEvent(event) end
loader:SetScript("OnEvent", function(_, event, name)
    if event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" then
        -- Some 3.3.5 clients replace the entire SV table after addon files execute.
        C.Initialize()
        if not C.ready then return end
        C.Window.TryHooks()
        if event == "PLAYER_LOGIN" then
            C.Announcements.Install()
            C.Options.Register()
            C.Notify()
        end
    elseif event == "ADDON_LOADED" then
        C.Window.TryHooks()
        if C.ready and name == "Mcode_BGTextCN" then C.Announcements.CheckConflict(); C.Notify() end
        if C.ready and C.Announcements.installed then C.Announcements.TryDisplayHooks() end
    else C.Window.Close() end
end)
C.Window.TryHooks()

function C.Dump()
    C.Print("v" .. C.version .. "，窗口及公告记录已分别保存；/stcn show 打开管理页。")
    C.Print("窗口词典 " .. C.DictionaryVersion("window") .. "；公告词典 " .. C.DictionaryVersion("announcements") .. "。")
    for _, module in ipairs({ "window", "announcements" }) do
        local label = module == "window" and "窗口" or "公告"
        local misses, hits = C.List(module, false), C.List(module, true)
        C.Print(label .. "未汉化 " .. #misses .. " 条，译文记录 " .. #hits .. " 条。")
        for i = math.max(1, #misses - 49), #misses do
            local item = misses[i]
            C.Print("待翻 [" .. tostring(item.k or item.source or "") .. "｜" .. tostring(item.n or "")
                .. "｜" .. tostring(item.z or "") .. "] " .. tostring(item.rawText or item.t))
        end
        for i = math.max(1, #hits - 14), #hits do
            local item = hits[i]
            C.Print("留痕 [" .. tostring(item.h or "") .. (item.history and "｜旧版历史" or "") .. "] " .. tostring(item.rawText or item.t)
                .. " ⇒ " .. tostring(item.cn or ""))
        end
    end
    if C.Window.lastGreeting then C.Print("最近问候原文：" .. C.Window.lastGreeting) end
end

SLASH_MCODESERVERTEXTCN1 = "/stcn"
SlashCmdList["MCODESERVERTEXTCN"] = function(message)
    local command = string.lower(tostring(message or "")):gsub("^%s+", ""):gsub("%s+$", "")
    if not C.ready then C.Print(C.storageError or "存档尚未加载，请登录角色后再打开管理页。"); return end
    if command == "" or command == "show" then C.Options.Show()
    elseif command == "on" or command == "off" then
        local value = command == "on"
        McodeSTCN_DB.enabled, McodeSTCN_DB.announcements.enabled = value, value
        C.Print("窗口和公告汉化已同时" .. (value and "开启。" or "关闭。") .. "可在各自设置页分别调整。")
        C.Notify()
    elseif command == "debug" then
        McodeSTCN_DB.debug = not McodeSTCN_DB.debug
        C.Print("窗口匹配调试已" .. (McodeSTCN_DB.debug and "开启。" or "关闭。"))
        C.Notify()
    elseif command == "dump" then C.Dump()
    else C.Print("命令：/stcn show、/stcn on、/stcn off、/stcn debug、/stcn dump。") end
end
