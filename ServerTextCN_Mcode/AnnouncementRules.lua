-- Mcode_BGTextCN 1.3 rules, retained in their original order and given stable IDs.
-- Author: Mcode. Flags must precede generic node capture rules.
local C = McodeSTCN
-- 2026-10-01: add three observed system notices; retain the original 24 BG rules.
-- 2026-10-05: add AV victory/reinforcement, WSG wording variants, account-ban
-- notices (system) and Nexus Chaotic Rift emotes (boss); uses the new {理由} marker.
local A = { list = {}, dictionaryVersion = "2026.10.05.1" }
C.AnnouncementRules = A
local faction = { Alliance = "联盟", Horde = "部落" }
local nodes = {
    ["Mage Tower"] = "法师塔", ["Draenei Ruins"] = "德莱尼废墟", ["Fel Reaver Ruins"] = "魔能机甲废墟",
    ["Blood Elf Tower"] = "血精灵塔", ["Farm"] = "农场", ["Lumber Mill"] = "伐木场",
    ["Blacksmith"] = "铁匠铺", ["Gold Mine"] = "金矿", ["Stables"] = "兽栏",
    ["Keep"] = "要塞", ["Docks"] = "码头", ["Hangar"] = "机库", ["Quarry"] = "采石场",
    ["Oil Refinery"] = "炼油厂", ["Workshop"] = "车间", ["Fortress"] = "要塞",
    ["Siege Workshop"] = "攻城车间", ["Sunken Ring"] = "沉没之环", ["Broken Temple"] = "破碎神殿",
    ["Eastspark Workshop"] = "东火花车间", ["Westspark Workshop"] = "西火花车间",
    ["Dun Baldar"] = "登巴尔达", ["Stormpike Graveyard"] = "雷矛墓地", ["Icewing Bunker"] = "冰翼碉堡",
    ["Stonehearth Bunker"] = "石炉碉堡", ["Frostwolf Keep"] = "霜狼要塞", ["Frostwolf Graveyard"] = "霜狼墓地",
    ["Iceblood Graveyard"] = "冰血墓地", ["Tower Point"] = "哨塔高地", ["Snowfall Graveyard"] = "雪落墓地",
    ["Frostwolf Relief Hut"] = "霜狼急救所", ["Stormpike Aid Station"] = "雷矛急救站",
}
local battlefields = { ["Eye of the Storm"] = "风暴之眼", ["Warsong Gulch"] = "战歌峡谷",
    ["Arathi Basin"] = "阿拉希盆地", ["Alterac Valley"] = "奥特兰克山谷",
    ["Strand of the Ancients"] = "远古海滩", ["Isle of Conquest"] = "征服之岛",
    ["Wintergrasp"] = "冬拥湖", ["Lake Wintergrasp"] = "冬拥湖" }
-- Ban reasons observed in CHAT_MSG_SYSTEM (2026-10-03/04); unknown reasons fall
-- back to the English text via A.Lookup instead of failing the rule.
local reasons = {
    ["Ninja looting in dungeons"] = "在地下城中黑装备",
    ["Ninja looting in dungeon"] = "在地下城中黑装备",
    ["Exploiting"] = "利用游戏漏洞",
    ["Cheating"] = "作弊",
    ["Harassment"] = "骚扰行为",
}
-- Exact dictionary contents are carried over from the backed-up 1.3 source.
local dictionaries = { ["阵营"] = faction, ["据点"] = nodes, ["战场"] = battlefields, ["理由"] = reasons }
local lower = {}
for name, dict in pairs(dictionaries) do
    lower[name] = {}
    for key, value in pairs(dict) do lower[name][string.lower(key)] = value end
end

function A.Lookup(name, value)
    local dict = dictionaries[name]
    return dict and (dict[value] or lower[name][string.lower(value)]) or value
end

local function validFaction(value)
    return type(value) == "string" and lower["阵营"][string.lower(value)] ~= nil
end

local function tense(value)
    value = value and value:gsub("%s+$", "")
    return value == "was" or value == "has been"
end

local function add(id, name, pattern, template, translation, sample, capture, source)
    local rule = { id = "announcement:" .. id, name = name, pattern = pattern,
        template = template, translation = translation, sample = sample, capture = capture, source = source or "bg" }
    A.list[#A.list + 1] = rule
end

add("countdown-2m", "开局倒计时：2 分钟", "^The [Bb]attle for (.+) begins in 2 minutes%.$",
    "The battle for {战场} begins in {数字} minutes.", "距离{战场}的战斗开始还有 {数字} 分钟。",
    "The battle for Arathi Basin begins in 2 minutes.", function(b) return { ["战场"] = b, ["数字"] = "2" } end)
add("countdown-1m", "开局倒计时：1 分钟", "^The [Bb]attle for (.+) begins in 1 minute%.$",
    "The battle for {战场} begins in {数字} minute.", "距离{战场}的战斗开始还有 {数字} 分钟。",
    "The battle for Warsong Gulch begins in 1 minute.", function(b) return { ["战场"] = b, ["数字"] = "1" } end)
add("countdown-30s", "开局倒计时：30 秒", "^The [Bb]attle for (.+) begins in 30 seconds%.$",
    "The battle for {战场} begins in {数字} seconds.", "距离{战场}的战斗开始还有 {数字} 秒。",
    "The battle for Arathi Basin begins in 30 seconds.", function(b) return { ["战场"] = b, ["数字"] = "30" } end)
add("battle-start", "战斗开始", "^The [Bb]attle for (.+) has begun!$",
    "The battle for {战场} has begun!", "{战场}的战斗已经开始！",
    "The battle for Warsong Gulch has begun!", function(b) return { ["战场"] = b } end)
add("flag-dropped", "战旗被丢弃", "^The flag has been dropped[!%.]$",
    "The flag has been dropped.", "战旗已被丢弃。", "The flag has been dropped.", function() return {} end)

local function flagPlayer(f, v, n)
    if validFaction(f) and tense(v) then return { ["阵营"] = f, ["玩家名"] = n } end
end
local function flagFaction(f, v)
    if validFaction(f) and tense(v) then return { ["阵营"] = f } end
end
add("flag-pickup-player", "玩家拾取阵营旗帜", "^The (%a+) flag (%a+%s*%a*) picked up by (.+)[!%.]$",
    "The {阵营} flag was picked up by {玩家名}!", "{阵营}的旗帜被{玩家名}拾取了！",
    "The Alliance flag was picked up by Lisatha!", flagPlayer)
add("flag-drop-player", "玩家丢弃阵营旗帜", "^The (%a+) flag (%a+%s*%a*) dropped by (.+)[!%.]$",
    "The {阵营} flag was dropped by {玩家名}!", "{阵营}的旗帜被{玩家名}丢弃了！",
    "The Horde flag was dropped by Mallkor!", flagPlayer)
add("flag-drop-faction", "阵营旗帜被丢弃", "^The (%a+) flag (%a+%s*%a*) dropped[!%.]$",
    "The {阵营} flag was dropped!", "{阵营}的旗帜被丢弃了！", "The Horde flag was dropped!", flagFaction)
add("flag-capture-player", "玩家夺取阵营旗帜", "^The (%a+) flag (%a+%s*%a*) captured by (.+)[!%.]$",
    "The {阵营} flag was captured by {玩家名}!", "{玩家名}夺取了{阵营}的旗帜！",
    "The Alliance flag was captured by Lisatha!", flagPlayer)
add("flag-return-player", "玩家归还阵营旗帜", "^The (%a+) flag (%a+%s*%a*) returned to its base by (.+)[!%.]$",
    "The {阵营} flag was returned to its base by {玩家名}!", "{玩家名}把{阵营}的旗帜送回了基地！",
    "The Horde flag was returned to its base by Zephiron!", flagPlayer)
add("flag-return-faction", "阵营旗帜归还基地", "^The (%a+) flag (%a+%s*%a*) returned to its base[!%.]$",
    "The {阵营} flag was returned to its base!", "{阵营}的旗帜已归还基地。",
    "The Alliance flag was returned to its base!", flagFaction)
add("player-takes-faction-flag", "玩家夺取敌方旗帜", "^(.+) has (%a+) the (%a+) flag[!%.]$",
    "{玩家名} has taken the {阵营} flag!", "{玩家名}夺取了{阵营}的旗帜！",
    "Zephiron has taken the Horde flag!", function(n, verb, f)
        if (verb == "taken" or verb == "captured") and validFaction(f) then return { ["玩家名"] = n, ["阵营"] = f } end
    end)
add("faction-takes-flag", "阵营夺回战旗", "^The (%a+) (%a+) (%a+) the flag[!%.]$",
    "The {阵营} has taken the flag!", "{阵营}夺回了战旗！", "The Horde has taken the flag!",
    function(f, v1, v2)
        if validFaction(f) and (v1 == "has" or v1 == "have") and (v2 == "taken" or v2 == "captured") then return { ["阵营"] = f } end
    end)
add("flag-available", "阵营旗帜可拾取", "^The (.+) flag is now available for pickup[!%.]$",
    "The {阵营} flag is now available for pickup.", "{阵营}的旗帜现在可以拾取。",
    "The Alliance flag is now available for pickup.", function(f) return { ["阵营"] = f } end)
add("player-takes-flag", "玩家夺取战旗", "^(.+) has taken the flag[!%.]$",
    "{玩家名} has taken the flag!", "{玩家名}夺取了战旗！", "Lisatha has taken the flag!",
    function(n) return { ["玩家名"] = n } end)
add("player-captures-flag", "玩家夺取战旗：captured", "^(.+) has captured the flag[!%.]$",
    "{玩家名} has captured the flag!", "{玩家名}夺取了战旗！", "Grommash has captured the flag!",
    function(n) return { ["玩家名"] = n } end)

local function factionNode(f, n)
    if validFaction(f) then return { ["阵营"] = f, ["据点"] = n } end
end
add("node-control", "阵营控制据点", "^The (%a+) has taken control of the (.+)!$",
    "The {阵营} has taken control of the {据点}!", "{阵营}占领了{据点}！",
    "The Alliance has taken control of the Gold Mine!", factionNode)
add("node-taken", "阵营占领据点", "^The (%a+) (%a+) taken the (.+)!$",
    "The {阵营} has taken the {据点}!", "{阵营}占领了{据点}！",
    "The Horde has taken the Lumber Mill!", function(f, verb, n)
        if validFaction(f) and (verb == "has" or verb == "have") then return { ["阵营"] = f, ["据点"] = n } end
    end)
add("node-assaulted", "阵营进攻据点", "^The (%a+) has assaulted the (.+)!$",
    "The {阵营} has assaulted the {据点}!", "{阵营}进攻了{据点}！",
    "The Alliance has assaulted the Blacksmith!", factionNode)
add("node-defended", "阵营防守据点", "^The (%a+) has defended the (.+)!$",
    "The {阵营} has defended the {据点}!", "{阵营}防守住了{据点}！",
    "The Horde has defended the blacksmith", factionNode)
add("player-assaulted-node", "玩家进攻据点", "^(.+) has assaulted the (.+)!$",
    "{玩家名} has assaulted the {据点}!", "{玩家名}进攻了{据点}！",
    "Lisatha has assaulted the lumber mill", function(n, node) return { ["玩家名"] = n, ["据点"] = node } end)
add("player-defended-node", "玩家防守据点", "^(.+) has defended the (.+)!$",
    "{玩家名} has defended the {据点}!", "{玩家名}防守住了{据点}！",
    "Zephiron has defended the lumber mill", function(n, node) return { ["玩家名"] = n, ["据点"] = node } end)
add("node-captured", "阵营夺取建筑或据点", "^The (%a+) has captured the (.+)!$",
    "The {阵营} has captured the {据点}!", "{阵营}夺取了{据点}！",
    "The Alliance has captured the Mage Tower!", factionNode)
add("node-destroyed", "阵营摧毁建筑", "^The (%a+) has destroyed the (.+)!$",
    "The {阵营} has destroyed the {据点}!", "{阵营}摧毁了{据点}！",
    "The Horde has destroyed the Keep!", factionNode)

-- Collected CHAT_MSG_SYSTEM messages, 2026-10-01. Keep server name, URL and command literal.
add("system-character-trade", "系统公告：角色交易",
    "^Players can trade their characters on our website using the Character Trade system%.$",
    "Players can trade their characters on our website using the Character Trade system.",
    "玩家可以通过我们网站上的角色交易系统交易角色。",
    "Players can trade their characters on our website using the Character Trade system.",
    function() return {} end, "system")
add("system-icecrown-welcome", "系统公告：Icecrown 欢迎语",
    "^Welcome to Icecrown 3%.3%.5a%. Visit www%.warmane%.com for information%.$",
    "Welcome to Icecrown 3.3.5a. Visit www.warmane.com for information.",
    "欢迎来到 Icecrown 3.3.5a 服务器。更多信息请访问 www.warmane.com。",
    "Welcome to Icecrown 3.3.5a. Visit www.warmane.com for information.",
    function() return {} end, "system")
add("system-global-channel", "系统公告：世界频道",
    "^Create dungeon groups and chat with other players by typing /join global!$",
    "Create dungeon groups and chat with other players by typing /join global",
    "输入 /join global 加入世界频道，与其他玩家聊天或组建地下城队伍。",
    "Create dungeon groups and chat with other players by typing /join global",
    function() return {} end, "system")

-- 2026-10-05: observed gaps and server wording variants (22 collected misses).
-- Appended after the original rules, so an original rule still wins when it matches.
add("bg-wins", "战场胜负", "^The (%a+) wins[!%.]$",
    "The {阵营} wins!", "{阵营}获胜！",
    "The Horde wins!", function(f)
        if validFaction(f) then return { ["阵营"] = f } end
    end)
add("bg-reinforcements", "增援即将耗尽", "^The (%a+) Team is running out of reinforcements[!%.]$",
    "The {阵营} Team is running out of reinforcements!", "{阵营}队伍的增援即将耗尽！",
    "The Horde Team is running out of reinforcements!", function(f)
        if validFaction(f) then return { ["阵营"] = f } end
    end)
add("flags-at-bases", "旗帜归位", "^The flags are now placed at their bases[!%.]$",
    "The flags are now placed at their bases.", "双方旗帜已放回各自的基地。",
    "The flags are now placed at their bases.", function() return {} end)
add("countdown-30s-prepare", "开局倒计时：30 秒（带准备提示）", "^The [Bb]attle for (.+) begins in 30 seconds%. Prepare yourselves[!%.]$",
    "The battle for {战场} begins in {数字} seconds. Prepare yourselves!", "距离{战场}的战斗开始还有 {数字} 秒。请做好准备！",
    "The battle for Warsong Gulch begins in 30 seconds. Prepare yourselves!", function(b)
        return { ["战场"] = b, ["数字"] = "30" }
    end)
add("battle-let-begin", "战斗开始（Let 句式）", "^Let the battle for (.+) begin[!%.]$",
    "Let the battle for {战场} begin!", "让{战场}的战斗开始吧！",
    "Let the battle for Warsong Gulch begin!", function(b) return { ["战场"] = b } end)
add("flag-pickup-player-cap", "玩家拾取阵营旗帜（大写 Flag 变体）", "^The (%a+) Flag was picked up by (.+)[!%.]$",
    "The {阵营} Flag was picked up by {玩家名}!", "{阵营}的旗帜被{玩家名}拾取了！",
    "The Alliance Flag was picked up by Derpriest!", function(f, n)
        if validFaction(f) then return { ["阵营"] = f, ["玩家名"] = n } end
    end)
add("player-captured-faction-flag", "玩家夺取阵营旗帜（无 has 变体）", "^(.+) captured the (%a+) [Ff]lag[!%.]$",
    "{玩家名} captured the {阵营} flag!", "{玩家名}夺取了{阵营}的旗帜！",
    "Derpriest captured the Alliance flag!", function(n, f)
        if validFaction(f) then return { ["玩家名"] = n, ["阵营"] = f } end
    end)
-- Ban notices keep the server's red color; unknown reasons stay English via A.Lookup.
add("system-account-banned", "系统公告：账号封禁", "^Account (.+) has been banned for (%d+)d, reason: (.+)[!%.]$",
    "Account {文本} has been banned for {数字}d, reason: {理由}.",
    "|cffff0000账号 {文本} 已被封禁 {数字} 天，原因：{理由}。|r",
    "Account MARIANT*** has been banned for 5d, reason: Ninja looting in dungeons",
    function(name, days, reason)
        if name ~= "" and reason ~= "" then
            return { ["文本"] = name, ["数字"] = days, ["理由"] = reason }
        end
    end, "system")
-- Nexus (Anomalus) boss emotes; %s is filled in with the boss name by the display path.
add("boss-chaotic-rift-open", "首领公告：打开混乱裂隙", "^%%s opens a Chaotic Rift![!%.]?$",
    "%s opens a Chaotic Rift!", "%s打开了混乱裂隙！",
    "%s opens a Chaotic Rift!", function() return {} end, "boss")
add("boss-chaotic-rift-shield", "首领公告：护盾并转移力量", "^%%s shields himself and diverts his power to the rifts![!%.]?$",
    "%s shields himself and diverts his power to the rifts!", "%s以护盾保护自己，并将力量转移给裂隙！",
    "%s shields himself and diverts his power to the rifts!", function() return {} end, "boss")

function A.Normalize(raw)
    local text = C.Normalize(raw)
    if not text:find("[!%.]$") then text = text .. "!" end
    return text
end

function A.Capture(rule, raw)
    local message = A.Normalize(raw)
    local args = { message:match(rule.pattern) }
    if args[1] == nil then return nil end
    local values = rule.capture(unpack(args))
    if not values then return nil end
    for name, value in pairs(values) do
        local translated = A.Lookup(name, value)
        -- Keep a color span around a captured value when the source supplies one.
        values[name] = C.ColorValue(raw, value, translated)
    end
    return values
end

function A.Translate(raw, source)
    if type(raw) ~= "string" or raw == "" then return nil end
    for _, rule in ipairs(A.list) do
        -- Preserve legacy BG display fallback; new notices require a known system source.
        local values = (rule.source == "bg" or rule.source == source) and A.Capture(rule, raw)
        if values then
            local output = C.Render(rule.translation, values)
            return C.WrapColor(raw, output), "builtin",
                { id = rule.id, builtinID = rule.id,
                    template = rule.template, values = values, evidence = "rule" }
        end
    end
end
