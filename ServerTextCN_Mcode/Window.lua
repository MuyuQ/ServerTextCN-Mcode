-- ServerTextCN_Mcode window module. Original dictionaries and marker expansion by Mcode.
local C = McodeSTCN
local W = { cache = {}, profiles = {}, seen = {}, controls = {}, hooked = {} }
C.Window = W
local MENU = {
	-- 工程[虫洞]（物品 48933）的目的地（官方简中译名）
	["Borean Tundra"]  = "北风苔原",
	["Howling Fjord"]  = "嚎风峡湾",
	["Sholazar Basin"] = "索拉查盆地",
	["Icecrown"]       = "冰冠冰川",
	["Storm Peaks"]    = "风暴峭壁",
}

--------------------------------------------------------------------------
-- 问候语词典（训练师 / NPC 对话顶部的问候段；精确匹配 + 首尾归一）
-- 词条来源：游戏内 /stcn 取原文，翻译后加进来。未命中原样透传。
--------------------------------------------------------------------------

local GREET = {
	-- 训练师（2026-09-27 用户截图实测原文）
	["Hello! Ready for some training?"] = "你好！准备好接受训练了吗？",
}

--------------------------------------------------------------------------
-- 词典数据文件合并（v1.3）
-- ServerTextCN_Mcode_Data.lua 由生成器按 ID 锚定产出（见文件头说明），
-- 经 TOC 先于本文件加载。内置词条优先：只收录内置没有的键。
--------------------------------------------------------------------------
do
	local data = McodeSTCN_Data
	if type(data) == "table" then
		if type(data.GREET) == "table" then
			for k, v in pairs(data.GREET) do
				if type(k) == "string" and type(v) == "string" and GREET[k] == nil then
					GREET[k] = v
				end
			end
		end
		if type(data.MENU) == "table" then
			for k, v in pairs(data.MENU) do
				if type(k) == "string" and type(v) == "string" and MENU[k] == nil then
					MENU[k] = v
				end
			end
		end
	end
end

local MENU_LC = {}

-- NPC 收敛索引（Data.lua）：问候/菜单各一张（键集不同，须配对查询）。
-- 四层匹配（方案 npc-matching-plan）：L1 全库精确 → NPC 层（骨架精确→相似度）→ 透传。
local NPC_INDEX = McodeSTCN_NPC or {}          -- 中文名 → GREET 键
local NPC_INDEX_MENU = McodeSTCN_NPC_MENU or {} -- 中文名 → MENU 键

--------------------------------------------------------------------------
-- 查找共享层（v1.8）
-- ① 颜色代码：服务器菜单选项常带 |cffXXXXXX…|r 包裹（实测棘齿城工程菜单），
--    查找/记录前先剥掉，词典键一律存干净文本；
-- ② 占位符还原：实测 Warmane 对英文问候会展开 $n 为角色名（2026-09-28
--    斯布特瓦夫实发 "…your help, Wcode!"）——查找失败时把文本里的角色名
--    还原成 $n/$N 再试，词典键保持人人通用。
--------------------------------------------------------------------------

-- 无模式的纯文本替换（玩家名只含字母数字，但这里不依赖任何模式语义）
local function plain_replace(s, old, new)
	if old == "" then return s end
	local out, i, n, ol = {}, 1, #s, #old
	while i <= n do
		if s:sub(i, i + ol - 1) == old then
			out[#out + 1] = new
			i = i + ol
		else
			out[#out + 1] = s:sub(i, i)
			i = i + 1
		end
	end
	return table.concat(out)
end

-- 词边界安全的替换：old 的前后一位都不能是字母（防 damage 里的 mage 被误换）。
-- 占位符还原与译文展开共用。
local function replace_word(s, old, new)
	if old == "" then return s end
	local out, i, n, ol = {}, 1, #s, #old
	while i <= n do
		local before = s:sub(i - 1, i - 1)
		local after = s:sub(i + ol, i + ol)
		local edge_ok = (before == "" or before:find("[A-Za-z]") == nil)
			and (after == "" or after:find("[A-Za-z]") == nil)
		if edge_ok and s:sub(i, i + ol - 1) == old then
			out[#out + 1] = new
			i = i + ol
		else
			out[#out + 1] = s:sub(i, i)
			i = i + 1
		end
	end
	return table.concat(out)
end

--------------------------------------------------------------------------
-- 玩家自身信息 + 占位符运行期展开（v1.9）
-- 数据库原文的中文译文也带 $n/$N/$c/$C/$r/$R/$g男:女/$B 占位符——客户端不展开
-- 任何占位符（gossip 路径实发连 $n 都是字面，npccache 字节实证），显示前必须
-- 自己展开。信息取不到时占位符原样保留（宁可显示 $n 也不显示空串）。
--------------------------------------------------------------------------

local PLAYER_INFO = nil
local function PlayerInfo()
	if PLAYER_INFO then return PLAYER_INFO end
	local p = { name = "", CLASS = "", class = "", RACE = "", race = "", sex = nil }
	local ok, v
	if type(UnitName) == "function" then
		ok, v = pcall(UnitName, "player")
		if ok and type(v) == "string" then p.name = v end
	end
	if type(UnitClass) == "function" then
		ok, v = pcall(UnitClass, "player")
		if ok and type(v) == "string" and v ~= "" then
			p.CLASS = v
			p.class = string.lower(v)
		end
	end
	if type(UnitRace) == "function" then
		ok, v = pcall(UnitRace, "player")
		if ok and type(v) == "string" and v ~= "" then
			p.RACE = v
			p.race = string.lower(v)
		end
	end
	if type(UnitSex) == "function" then
		ok, v = pcall(UnitSex, "player")
		if ok and type(v) == "number" then p.sex = v end   -- 2=男 3=女
	end
	PLAYER_INFO = p
	return p
end

local function ExpandCN(text)
    if type(text) ~= "string" then return text end
    local p = PlayerInfo()
    return C.RenderNative(text, { name = p.name, class = p.CLASS, race = p.RACE, sex = p.sex })
end

local function DictLookup(dict, dict_lc, text)
    if type(text) ~= "string" or text == "" then return nil end
    local function lookup(candidate)
        if dict[candidate] then return dict[candidate], candidate end
        local entry = dict_lc[string.lower(candidate)]
        if entry then return entry.value, entry.key end
    end
    local value, key = lookup(text)
    if value then return value, key end
    local p = PlayerInfo()
    local variants, seen = { text }, { [text] = true }
    -- Each independent variable can be present alone or with the others.
    for _, group in ipairs({ { { p.name, "$N" }, { p.name, "$n" } },
        { { p.CLASS, "$C" }, { p.class, "$c" } },
        { { p.RACE, "$R" }, { p.race, "$r" } } }) do
        local count = #variants
        for i = 1, count do
            for _, pair in ipairs(group) do
                if pair[1] ~= "" then
                    local alt = replace_word(variants[i], pair[1], pair[2])
                    if not seen[alt] then
                        seen[alt] = true; variants[#variants + 1] = alt
                        value, key = lookup(alt)
                        if value then return value, key end
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------
-- 应用到按钮
--
-- 3.3.5 的菜单选项按钮是 GossipTitleButton1..NUMGOSSIPBUTTONS
-- （NUMGOSSIPBUTTONS = 32，由 FrameXML\GossipFrame.lua 定义）。
-- 任务标题按钮也共用这套按钮，所以这里只做词典精确命中才替换。
--------------------------------------------------------------------------

local NUM_BUTTONS = NUMGOSSIPBUTTONS or 32

local GREET_LC = {}
W.dictionaries = { menu = MENU, greeting = GREET }
W.keyByDict = { [MENU] = {}, [GREET] = {} }
W.caseConflicts = {}
local function buildLower(dict, index)
    local keys = {}
    for key in pairs(dict) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local lower, previous = string.lower(key), index[string.lower(key)]
        local equivalent = function(value) return value:gsub("%$[NnCcRr]", string.lower) end
        if previous == nil then
            index[lower] = { key = key, value = dict[key] }
            W.keyByDict[dict][lower] = key
        elseif previous and equivalent(previous.value) ~= equivalent(dict[key]) then
            index[lower] = false; W.keyByDict[dict][lower] = nil
            W.caseConflicts[#W.caseConflicts + 1] = { first = previous.key, second = key }
        end
    end
end
buildLower(MENU, MENU_LC); buildLower(GREET, GREET_LC)

function W.ClearCache()
    W.cache, W.cacheCount, W.cacheBytes, W.seen = {}, 0, 0, {}
    W.profiles, W.profileCount = {}, 0
    PLAYER_INFO = nil
end

local function npcName()
    return C.Read(UnitName, "npc") or C.Read(UnitName, "questnpc") or ""
end

local function skeleton(text)
    -- Only case, whitespace and sentence-final punctuation are ignorable.
    return string.lower(text):gsub("%s+", " "):gsub("[.!?]+$", "")
end

local function profile(kind, name)
    local id = kind .. "\031" .. name
    if W.profiles[id] ~= nil then return W.profiles[id] or nil end
    if (W.profileCount or 0) >= 256 then W.profiles, W.profileCount = {}, 0 end
    W.profileCount = (W.profileCount or 0) + 1
    local index = kind == "menu" and NPC_INDEX_MENU or NPC_INDEX
    local candidates = index[name]
    if type(candidates) ~= "table" then W.profiles[id] = false; return nil end
    local dict, result = W.dictionaries[kind], { exact = {} }
    for _, key in ipairs(candidates) do
        if dict[key] then
            local sk = skeleton(key)
            local previous = result.exact[sk]
            if previous == nil then result.exact[sk] = key
            elseif previous and dict[previous] ~= dict[key] then result.exact[sk] = false end
        end
    end
    W.profiles[id] = result
    return result
end

function W.LookupBuiltin(raw, kind, ctx, exactOnly)
    kind = C.Group(kind)
    local normalized = C.Normalize(raw)
    local dict, lower = W.dictionaries[kind], kind == "menu" and MENU_LC or GREET_LC
    local cn, key = DictLookup(dict, lower, normalized)
    if cn then return cn, "exact", key end
    if exactOnly then return nil end
    local p = profile(kind, ctx.npc or npcName())
    if not p then return nil end
    local sk = skeleton(normalized)
    key = p.exact[sk]
    if key then return dict[key], "exact-npc", key end
    -- Similarity alone cannot establish meaning (negation, costs, quantities).
    -- Unknown wording stays visible and enters the existing miss collection.

end

function W.Translate(raw, kind, ctx, exactOnly)
    if not C.Enabled("window") then return nil end
    ctx = ctx or C.Context(kind)
    ctx.kind = kind
    local key = C.Scope(ctx) .. "\031" .. C.Group(kind) .. "\031" .. C.Normalize(raw)
        .. "\031" .. tostring(exactOnly)
    local entry = W.cache[key]
    if not entry then
        local cn, tag, matched = W.LookupBuiltin(raw, kind, ctx, exactOnly)
        if cn then
            local id = "window:" .. C.Group(kind) .. ":" .. matched
            entry = { output = ExpandCN(cn), tag = tag,
                meta = { id = id, builtinID = id, template = matched,
                    evidence = tag == "exact" and "dictionary" or "candidate" } }
        else entry = {} end
        local bytes = #key + #(entry.output or "")
        if bytes <= 16384 then
            if (W.cacheCount or 0) >= 1024 or (W.cacheBytes or 0) + bytes > 524288 then
                W.cache, W.cacheCount, W.cacheBytes = {}, 0, 0
            end
            W.cache[key] = entry
            W.cacheCount = (W.cacheCount or 0) + 1
            W.cacheBytes = (W.cacheBytes or 0) + bytes
        end
    end
    if entry.output then return C.WrapColor(raw, entry.output), entry.tag, entry.meta end
end

function W.Observe(raw, kind, ctx, exactOnly)
    ctx = ctx or C.Context(kind)
    ctx.kind = kind
    local cn, tag, meta = W.Translate(raw, kind, ctx, exactOnly)
    local seenKey = C.RecordKey("window", raw, ctx)
    local seen = W.seen[seenKey]
    if not seen then seen = {}; W.seen[seenKey] = seen end
    if not seen.recorded then seen.recorded = C.Record("window", raw, cn, tag, ctx, meta) ~= nil end
    -- Debug output is separate from collection, so enabling collection later
    -- can record a previously seen miss without repeating refresh/debug lines.
    if not seen.logged and McodeSTCN_DB and McodeSTCN_DB.debug then
        seen.logged = true
        local context = tostring(kind or "窗口") .. "｜" .. tostring(ctx.npc or "")
        if type(cn) == "string" and cn ~= raw then
            local labels = { exact = "精确匹配", ["exact-npc"] = "NPC骨架匹配" }
            local method = labels[tag] or tostring(tag or "词典匹配")
            if tag and tag:find("^sim%(") then method = "NPC相似度匹配 " .. tag end
            C.Print("窗口命中[" .. method .. "｜" .. context .. "] 原文：" .. C.Normalize(raw))
            C.Print("译文：" .. C.Normalize(cn))
        elseif C.IsEnglish(raw) then
            C.Print("窗口未命中[" .. context .. "] 原文：" .. C.Normalize(raw))
        end
    end
    return cn
end

local function controlRaw(control, getter, ctx)
    local raw = C.Read(getter)
    if type(raw) == "string" and raw ~= "" then return raw end
    if not control or type(control.GetText) ~= "function" then return nil end
    raw = control:GetText()
    local previous = W.controls[control]
    if previous and raw == previous.output and previous.scope == C.Scope(ctx or C.Context("窗口")) then return previous.raw end
    return raw
end

function W.ApplyGreeting(kind, control, getter)
    if not C.Enabled("window") or not control or not control.SetText then return end
    local ctx = C.Context(kind)
    local raw = controlRaw(control, getter, ctx)
    if type(raw) ~= "string" or raw == "" then return end
    W.lastGreeting = raw
    local cn = W.Observe(raw, kind, ctx)
    if cn and cn ~= raw then
        W.controls[control] = { raw = raw, output = cn, scope = C.Scope(ctx) }
        control:SetText(cn)
    end
end

function W.ApplyButtons()
    if not C.Enabled("window") or not GossipFrame or not GossipFrame:IsShown() then return end
    local options = type(GetGossipOptions) == "function" and { GetGossipOptions() } or {}
    local ctx = C.Context("菜单")
    for i = 1, NUM_BUTTONS do
        local button = _G["GossipTitleButton" .. i]
        if button and button.IsShown and button:IsShown() and button.GetText and button.SetText then
            local raw
            if button.type == "Gossip" and button.GetID then raw = options[button:GetID() * 2 - 1] end
            if type(raw) ~= "string" then raw = controlRaw(button, nil, ctx) end
            if type(raw) == "string" and raw ~= "" then
                -- Quest titles share these buttons. Only keep their existing exact dictionary path.
                local exactOnly = button.type == "Available" or button.type == "Active"
                local cn = W.Observe(raw, "菜单", ctx, exactOnly)
                if cn and cn ~= raw then
                    W.controls[button] = { raw = raw, output = cn, scope = C.Scope(ctx) }
                    button:SetText(cn)
                    if type(GossipResize) == "function" then pcall(GossipResize, button) end
                end
            end
        end
    end
end

function W.TryHooks()
    if type(hooksecurefunc) ~= "function" then return end
    if not W.hooked.trainer and type(ClassTrainerFrame_Update) == "function" then
        W.hooked.trainer = true
        hooksecurefunc("ClassTrainerFrame_Update", function()
            W.ApplyGreeting("训练师", ClassTrainerGreetingText, GetTrainerGreetingText)
        end)
    end
    if not W.hooked.gossip and type(GossipFrameUpdate) == "function" then
        W.hooked.gossip = true
        if type(GossipFrameOptionsUpdate) == "function" then hooksecurefunc("GossipFrameOptionsUpdate", W.ApplyButtons) end
        hooksecurefunc("GossipFrameUpdate", function()
            W.ApplyButtons(); W.ApplyGreeting("NPC对话", GossipGreetingText, GetGossipText)
        end)
    end
    if not W.hooked.quest and QuestFrameGreetingPanel and QuestFrameGreetingPanel.HookScript then
        W.hooked.quest = true
        QuestFrameGreetingPanel:HookScript("OnShow", function()
            W.ApplyGreeting("任务问候", GreetingText, GetGreetingText)
        end)
    elseif not W.hooked.quest and type(QuestFrameGreetingPanel_OnShow) == "function" then
        W.hooked.quest = true
        hooksecurefunc("QuestFrameGreetingPanel_OnShow", function()
            W.ApplyGreeting("任务问候", GreetingText, GetGreetingText)
        end)
    end
end

function W.Close()
    W.seen, W.controls = {}, {}
end

