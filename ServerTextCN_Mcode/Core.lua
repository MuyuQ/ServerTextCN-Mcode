-- ServerTextCN_Mcode 3.1: built-in translation and read-only feedback records.
McodeSTCN = { version = "3.1", schema = 4, ready = false, listeners = {} }
local C = McodeSTCN

function C.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = C.Copy(v) end
    return copy
end

function C.Print(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[服务器文本汉化]|r " .. tostring(text))
    end
end

function C.Notify(reason)
    for _, fn in ipairs(C.listeners) do fn(reason) end
end

function C.DictionaryVersion(module)
    local version
    if module == "window" then
        version = type(McodeSTCN_DictionaryInfo) == "table" and McodeSTCN_DictionaryInfo.version
    elseif module == "announcements" and C.AnnouncementRules then
        version = C.AnnouncementRules.dictionaryVersion
    end
    return type(version) == "string" and version ~= "" and version or "未标注"
end

function C.Normalize(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("%$[Bb]", " ")
    while text:find("....", 1, true) do text = text:gsub("%.%.%.%.", "...") end
    return text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

function C.Now()
    if type(time) == "function" then return time() end
    return type(GetTime) == "function" and GetTime() or 0
end

function C.Stamp()
    return type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or ""
end

local function read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end
C.Read = read

function C.Player()
    local name = read(UnitName, "player") or ""
    local class, classToken = read(UnitClass, "player")
    local race, raceToken = read(UnitRace, "player")
    return { name = name, class = class or "", race = race or "",
        classToken = classToken, raceToken = raceToken, sex = read(UnitSex, "player") }
end

function C.Context(kind, event, speaker)
    local unit = "npc"
    local name = read(UnitName, unit)
    if not name then unit = "questnpc"; name = read(UnitName, unit) end
    local guid = read(UnitGUID, unit)
    local entry
    -- 3.3.5 creature / vehicle GUID, never decode a player GUID as an NPC entry.
    if type(guid) == "string" and (guid:sub(1, 6) == "0xF130" or guid:sub(1, 6) == "0xF150") then
        entry = tonumber(guid:sub(7, 12), 16)
    end
    local zone, sub = read(GetZoneText) or "", read(GetSubZoneText) or ""
    if sub ~= "" and sub ~= zone then zone = zone .. "·" .. sub end
    local x, y = read(GetPlayerMapPosition, "player")
    local coords = ""
    if type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
        coords = string.format("%.1f,%.1f", x * 100, y * 100)
    end
    return { kind = kind, event = event, speaker = speaker, npc = name or "",
        npcID = entry, npcGUID = guid, zone = zone, coords = coords, player = C.Player() }
end

function C.Group(kind)
    if kind == "菜单" or kind == "menu" then return "menu" end
    return "greeting"
end

function C.Scope(ctx)
    if ctx and ctx.npcID then return "id:" .. tostring(ctx.npcID) end
    if ctx and ctx.npc and ctx.npc ~= "" then return "name:" .. ctx.npc end
    return "*"
end

function C.Enabled(module)
    if not C.ready or C.storageError then return false end
    local db = McodeSTCN_DB
    if module == "window" then return db.enabled end
    return db.announcements.enabled and not C.announcementConflict
end

function C.Collecting(module, source)
    if not C.Enabled(module) then return false end
    if module == "window" then return McodeSTCN_DB.windowCollect end
    local a = McodeSTCN_DB.announcements
    return a.collect and a.sources[source] == true
end

function C.IsEnglish(raw)
    local text = C.Normalize(raw)
    if text == "" or not text:find("[A-Za-z]") or text:find(" -VS- ", 1, true) then return false end
    -- Remove rich-text metadata before deciding whether the visible text needs translation.
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    if text:find("[\228-\233]") then return false end
    return text:find("[A-Za-z]") ~= nil
end

function C.Summary(raw, count)
    local text = C.Normalize(raw):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    local pos, characters = 1, 0
    while pos <= #text and characters < count do
        local first = text:byte(pos)
        pos = pos + (first < 128 and 1 or first < 224 and 2 or first < 240 and 3 or 4)
        characters = characters + 1
    end
    local result = pos <= #text and text:sub(1, pos - 1) .. "…" or text
    return (result:gsub("|", "||"))
end

function C.List(module, hits)
    if module == "window" then return hits and McodeSTCN_DB.hits or McodeSTCN_DB.misses end
    local a = McodeSTCN_DB.announcements
    return hits and a.hits or a.misses
end

local function identity(module, raw, ctx)
    local group = module == "window" and (ctx.kind or "问候") or (ctx.source or "unknown")
    return module .. "\031" .. group .. "\031" .. C.Scope(module == "window" and ctx or nil)
        .. "\031" .. C.Normalize(raw)
end
C.RecordKey = identity

local function historicalMatch(module, item, raw, ctx)
    return module == "window" and item.legacy and not item.npcID
        and item.n == ctx.npc and item.k == ctx.kind and item.t == C.Normalize(raw)
end

function C.RemoveMiss(module, raw, ctx)
    local key = identity(module, raw, ctx)
    local list = C.List(module, false)
    for i = #list, 1, -1 do
        local item = list[i]
        if item.key == key or historicalMatch(module, item, raw, ctx) then table.remove(list, i) end
    end
end

function C.Record(module, raw, cn, tag, ctx, meta)
    if not C.Enabled(module) or type(raw) ~= "string" or raw == "" then return end
    ctx = ctx or C.Context("问候")
    local hit = type(cn) == "string" and cn ~= raw
    if not hit and (not C.Collecting(module, ctx.source) or not C.IsEnglish(raw)) then return end
    local list, key = C.List(module, hit), identity(module, raw, ctx)
    local found
    for i, item in ipairs(list) do
        if item.key == key or historicalMatch(module, item, raw, ctx) then
            found = table.remove(list, i); break
        end
    end
    local item = found or { key = key, first = C.Now(), firstRawText = raw, count = 0 }
    item.key = key
    item.count = (tonumber(item.count) or 0) + 1
    item.last, item.d = C.Now(), C.Stamp()
    item.rawText, item.t, item.k = raw, C.Normalize(raw), ctx.kind
    item.n, item.npcID, item.npcGUID = ctx.npc, ctx.npcID, ctx.npcGUID
    item.z, item.c = ctx.zone, ctx.coords
    item.player, item.source, item.event, item.speaker = C.Copy(ctx.player), ctx.source, ctx.event, ctx.speaker
    item.displayText = ctx.displayText
    item.displayTranslation = ctx.displayTranslation
    item.cn, item.h = cn, tag
    item.ruleID = meta and meta.id
    item.builtinID = meta and meta.builtinID
    item.template = meta and meta.template
    item.values = meta and C.Copy(meta.values)
    item.variableEvidence = meta and meta.evidence
    item.b = meta and meta.best
    item.history, item.legacy, item.version = nil, nil, C.version
    item.dictionaryVersion = C.DictionaryVersion(module)
    list[#list + 1] = item -- repeated encounters also move to the most recent position
    while #list > (hit and 200 or 300) do table.remove(list, 1) end
    if hit then C.RemoveMiss(module, raw, ctx) end
    C.Notify("records")
    if not hit then
        local sources = { bg = "战场播报", system = "系统通知", boss = "首领公告", info = "屏幕提示" }
        local origin = module == "window" and (ctx.kind or "窗口") or (sources[ctx.source] or "公告")
        if module == "window" and ctx.npc and ctx.npc ~= "" then origin = origin .. "｜" .. C.Summary(ctx.npc, 24) end
        C.Print("已记录未汉化[" .. origin .. "]：" .. C.Summary(raw, 64)
            .. "；/stcn show 查看。AI 补译请阅读插件目录《使用说明-3.1.md》。")
        C.Notifications.Show(module, item.key)
    end
    return item
end

local function migrateList(list, module, hits)
    local result, order = {}, {}
    for _, item in ipairs(list) do
        if type(item) == "table" and type(item.t or item.rawText) == "string" then
            if not item.rawText then item.rawText = item.t; item.legacy = true end
            item.t = C.Normalize(item.t or item.rawText)
            item.count = tonumber(item.count) or 1
            item.last = tonumber(item.last) or 0
            item.first = tonumber(item.first) or item.last
            item.n = item.n or ""
            item.key = item.key or identity(module, item.rawText, { kind = item.k,
                npc = item.n, npcID = item.npcID, source = item.source })
            if hits or C.IsEnglish(item.rawText) then
                result[#result + 1] = item; order[item] = #result
            end
        end
    end
    table.sort(result, function(a, b)
        if a.last ~= b.last then return a.last < b.last end
        local firstDate, secondDate = tostring(a.d or ""), tostring(b.d or "")
        if firstDate ~= secondDate then return firstDate < secondDate end
        return order[a] < order[b]
    end)
    while #result > (hits and 200 or 300) do table.remove(result, 1) end
    return result
end

function C.Initialize()
    C.ready = false
    if type(McodeSTCN_DB) ~= "table" then McodeSTCN_DB = {} end
    local db = McodeSTCN_DB
    local storedVersion = tonumber(db.schemaVersion)
    if storedVersion and storedVersion > C.schema then
        C.storageError = "存档来自更高版本，已保留原数据；请安装对应版本的插件。"
        C.Print(C.storageError); return
    end
    C.storageError = nil
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.debug) ~= "boolean" then db.debug = false end
    if type(db.windowCollect) ~= "boolean" then db.windowCollect = true end
    db.misses = migrateList(type(db.misses) == "table" and db.misses or {}, "window", false)
    db.hits = migrateList(type(db.hits) == "table" and db.hits or {}, "window", true)
    if type(db.announcements) ~= "table" then db.announcements = {} end
    local a = db.announcements
    if type(a.enabled) ~= "boolean" then a.enabled = true end
    -- Retire the old master switch without re-enabling disabled translations.
    if db.masterEnabled == false then db.enabled, a.enabled = false, false end
    db.masterEnabled = nil
    if type(a.collect) ~= "boolean" then a.collect = true end
    if type(a.sources) ~= "table" then a.sources = {} end
    for _, source in ipairs({ "bg", "system", "boss" }) do
        if type(a.sources[source]) ~= "boolean" then a.sources[source] = true end
    end
    if type(a.sources.info) ~= "boolean" then a.sources.info = false end
    a.misses = migrateList(type(a.misses) == "table" and a.misses or {}, "announcements", false)
    a.hits = migrateList(type(a.hits) == "table" and a.hits or {}, "announcements", true)
    -- The old editing engine is removed. These fields are migration-only.
    db.rules, db.lastValidRules, db.drafts = nil, nil, nil
    db.pendingReload, db.nextRuleID = nil, nil
    for _, module in ipairs({ "window", "announcements" }) do
        for _, item in ipairs(C.List(module, false)) do item.pending = nil end
        for _, item in ipairs(C.List(module, true)) do
            item.pending = nil
            if not storedVersion or storedVersion < C.schema then item.history = true end
        end
    end
    if type(db.ui) ~= "table" then db.ui = {} end
    for _, module in ipairs({ "window", "announcements" }) do
        local old = type(db.ui[module]) == "table" and db.ui[module] or {}
        local tab = old.tab == "hits" and "hits" or "misses"
        -- Rebuild only supported UI state; discard obsolete editor/catalog fields.
        db.ui[module] = { tab = tab, query = type(old.query) == "string" and old.query or "",
            offset = math.max(0, tonumber(old.offset) or 0) }
    end
    if db.ui.lastModule ~= "announcements" then db.ui.lastModule = "window" end
    db.schemaVersion = C.schema
    C.ready = true
    if C.Window then C.Window.ClearCache() end
end
