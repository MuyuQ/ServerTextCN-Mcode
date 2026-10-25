-- Mcode_BGTextCN 1.3 rules, retained in their original order and given stable IDs.
-- Author: Mcode. Flags must precede generic node capture rules.
local C = McodeSTCN
-- 2026-10-01: add three observed system notices; retain the original 24 BG rules.
-- 2026-10-05: add AV victory/reinforcement, WSG wording variants, account-ban
-- notices (system) and Nexus Chaotic Rift emotes (boss); uses the new {理由} marker.
local A = { list = {}, dictionaryVersion = "2026.10.13.1", matchCache = {},
    matchOrder = {}, matchBytes = 0, cacheHits = 0, cacheMisses = 0 }
C.AnnouncementRules = A
local CACHE_LIMIT = 128
local CACHE_BYTES = 64 * 1024
local CACHE_RAW_LIMIT = 2 * 1024
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
    ["Mine"] = "金矿", ["Refinery"] = "炼油厂",
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
    ["Bot"] = "使用机器人程序",
    ["Anticheat violation #2"] = "反作弊违规 #2",
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

-- 2026-10-13: recorded BG, Blackrock and local server notices. Existing rules stay first.
add("node-claimed-countdown", "玩家开始占领据点",
    "^([^%s]+) claims the (.+)! If left unchallenged, the (%a+) will control it in 1 minute!$",
    "{玩家名} claims the {据点}! If left unchallenged, the {阵营} will control it in 1 minute!",
    "{玩家名}开始占领{据点}！若无人争夺，{阵营}将在 1 分钟后控制此处！",
    "Pcode claims the Quarry! If left unchallenged, the Horde will control it in 1 minute!",
    function(player, node, f)
        if validFaction(f) and lower["据点"][string.lower(node)] then
            return { ["玩家名"] = player, ["据点"] = node, ["阵营"] = f }
        end
    end)
add("countdown-short-1m", "开局倒计时：省略战场名，1 分钟",
    "^The battle will begin in 1 minute[!%.]$", "The battle will begin in 1 minute.",
    "战斗将在 1 分钟后开始！", "The battle will begin in 1 minute.", function() return {} end)
add("countdown-short-30s", "开局倒计时：省略战场名，30 秒",
    "^The battle will begin in 30 seconds[!%.]$", "The battle will begin in 30 seconds!",
    "战斗将在 30 秒后开始！", "The battle will begin in 30 seconds!", function() return {} end)
add("boss-battle-start-short", "首领公告事件：战斗开始",
    "^The battle has begun!$", "The battle has begun!", "战斗开始了！",
    "The battle has begun!", function() return {} end, "boss")
local gateDirections = { west = "西", east = "东", north = "北", south = "南" }
add("keep-gate-destroyed", "要塞城门被摧毁",
    "^The (%a+) gate of the (%a+) keep is destroyed!$",
    "The {文本} gate of the {阵营} keep is destroyed!", "{阵营}要塞的{文本}门已被摧毁！",
    "The west gate of the horde keep is destroyed!", function(direction, f)
        if gateDirections[direction] and validFaction(f) then
            return { ["文本"] = gateDirections[direction], ["阵营"] = f }
        end
    end)
add("bg-wins-no-article", "战场胜负：省略 The", "^(%a+) wins[!%.]$",
    "{阵营} wins!", "{阵营}获胜！", "Alliance wins!", function(f)
        if validFaction(f) then return { ["阵营"] = f } end
    end)
add("flag-drop-player-capitalized", "玩家丢弃阵营旗帜：大写 Flag",
    "^The (%a+) Flag (%a+%s*%a*) dropped by (.+)[!%.]$",
    "The {阵营} Flag was dropped by {玩家名}!", "{阵营}的旗帜被{玩家名}丢弃了！",
    "The Alliance Flag was dropped by Shocknana!", flagPlayer)
add("flag-placed-at-base", "单方旗帜归位", "^The (%a+) flag is now placed at its base[!%.]$",
    "The {阵营} flag is now placed at its base.", "{阵营}的旗帜已归位。",
    "The Alliance flag is now placed at its base.", function(f)
        if validFaction(f) then return { ["阵营"] = f } end
    end)
add("system-name-ban-days", "系统公告：无 Account 前缀的限时封禁",
    "^([^%s]+) has been banned for (%d+)d, reason: (.+)[!%.]$",
    "{文本} has been banned for {数字}d, reason: {理由}", "{文本}已被封禁 {数字} 天，原因：{理由}。",
    "Yuko has been banned for 30d, reason: Anticheat violation #2",
    function(name, days, reason) return { ["文本"] = name, ["数字"] = days, ["理由"] = reason } end, "system")
add("system-account-ban-permanent", "系统公告：账号永久封禁",
    "^Account (.-) has been banned permanently, reason: (.+)[!%.]$",
    "Account {文本} has been banned permanently, reason: {理由}", "账号{文本}已被永久封禁，原因：{理由}。",
    "Account ANDREYDE*** has been banned permanently, reason: Bot", function(name, reason)
        if name ~= "" then return { ["文本"] = name, ["理由"] = reason } end
    end, "system")
add("system-blackrock-welcome", "系统公告：Blackrock 欢迎语",
    "^Welcome to Blackrock%. The place to be for PvP%.$",
    "Welcome to Blackrock. The place to be for PvP.", "欢迎来到 Blackrock，这里是 PvP 的理想之地。",
    "Welcome to Blackrock. The place to be for PvP.", function() return {} end, "system")
add("system-blackrock-3v3-hour", "系统公告：Blackrock 每周 3v3 活动",
    "^Every Sunday at 19:00 Realm time, Blackrock hosts 3vs3 hour%. During this weekly event players will only be able to queue for 3vs3 for an hour%.$",
    "Every Sunday at 19:00 Realm time, Blackrock hosts 3vs3 hour. During this weekly event players will only be able to queue for 3vs3 for an hour.",
    "Blackrock 每周日服务器时间 19:00 举办一小时的 3v3 活动。活动期间，玩家在这一小时内只能排队参加 3v3 比赛。",
    "Every Sunday at 19:00 Realm time, Blackrock hosts 3vs3 hour. During this weekly event players will only be able to queue for 3vs3 for an hour.",
    function() return {} end, "system")
add("system-azerothcore-welcome", "系统公告：AzerothCore 欢迎语",
    "^Welcome to an AzerothCore server%.$", "Welcome to an AzerothCore server.",
    "欢迎来到采用 AzerothCore 的服务器。", "Welcome to an AzerothCore server.", function() return {} end, "system")
add("system-playerbots-module", "系统公告：mod-playerbots 模块",
    "^This server runs with mod%-playerbots https://github%.com/liyunfan1223/mod%-playerbots[!%.]$",
    "This server runs with mod-playerbots https://github.com/liyunfan1223/mod-playerbots",
    "本服务器使用 |cff00ccffmod-playerbots|r 模块：|cffcccccchttps://github.com/liyunfan1223/mod-playerbots|r",
    "This server runs with mod-playerbots https://github.com/liyunfan1223/mod-playerbots", function() return {} end, "system")
add("system-playerbots-startup", "系统公告：机器人初始化耗时",
    "^Playerbots: bot initialization at server startup takes about '(%d+%.?%d*)' minutes%.$",
    "Playerbots: bot initialization at server startup takes about '{数字}' minutes.",
    "Playerbots：服务器启动时，机器人初始化约需 {数字} 分钟。",
    "Playerbots: bot initialization at server startup takes about '0.1' minutes.",
    function(duration) return { ["数字"] = duration } end, "system")
add("system-spec-reward-module", "系统公告：Spec Reward 模块",
    "^This server is running the Spec Reward module%.$", "This server is running the Spec Reward module.",
    "本服务器正在运行 |cff4CFF00Spec Reward（专精奖励）|r 模块。",
    "This server is running the Spec Reward module.", function() return {} end, "system")

function A.Normalize(raw)
    local text = C.Normalize(raw)
    if not text:find("[!%.]$") then text = text .. "!" end
    return text
end

local function copyValues(values)
    local copy = {}
    for name, value in pairs(values or {}) do copy[name] = value end
    return copy
end

function A.ClearCache()
    A.matchCache, A.matchOrder = {}, {}
    A.matchBytes, A.cacheHits, A.cacheMisses = 0, 0, 0
end

function A.CacheStats()
    return { count = #A.matchOrder, rawBytes = A.matchBytes,
        hits = A.cacheHits, misses = A.cacheMisses }
end

local function remember(source, raw, rule, values)
    local byRaw = A.matchCache[source]
    if not byRaw then byRaw = {}; A.matchCache[source] = byRaw end
    local entry = { source = source, raw = raw, bytes = #raw, rule = rule, values = values }
    byRaw[raw] = entry
    A.matchOrder[#A.matchOrder + 1] = entry
    A.matchBytes = A.matchBytes + #raw
    while #A.matchOrder > CACHE_LIMIT or A.matchBytes > CACHE_BYTES do
        local old = table.remove(A.matchOrder, 1)
        if old then
            A.matchBytes = math.max(0, A.matchBytes - old.bytes)
            local oldSource = A.matchCache[old.source]
            if oldSource and oldSource[old.raw] == old then oldSource[old.raw] = nil end
        end
    end
end

function A.Capture(rule, raw, message)
    message = message or A.Normalize(raw)
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

local function match(raw, source)
    if type(raw) ~= "string" or raw == "" then return nil end
    local cacheSource = source or "none"
    if #raw > CACHE_RAW_LIMIT then
        local message = A.Normalize(raw)
        for _, rule in ipairs(A.list) do
            local values = (rule.source == "bg" or rule.source == cacheSource) and A.Capture(rule, raw, message)
            if values then return rule, values end
        end
        return nil
    end
    local byRaw = A.matchCache[cacheSource]
    local entry = byRaw and byRaw[raw]
    if entry then A.cacheHits = A.cacheHits + 1; return entry.rule, entry.values end
    A.cacheMisses = A.cacheMisses + 1
    local message = A.Normalize(raw)
    for _, rule in ipairs(A.list) do
        -- Preserve legacy BG display fallback; new notices require a known system source.
        local values = (rule.source == "bg" or rule.source == cacheSource) and A.Capture(rule, raw, message)
        if values then
            remember(cacheSource, raw, rule, values)
            return rule, values
        end
    end
    remember(cacheSource, raw, false, false)
    return nil
end

function A.Translate(raw, source)
    local rule, values = match(raw, source)
    if not rule then return nil end
    if rule.translation ~= rule.tokenText then
        rule.tokenText, rule.tokenInfo = rule.translation, C.Scan(rule.translation)
    end
    local output = C.RenderParsed(rule.translation, rule.tokenInfo, copyValues(values))
    return C.WrapColor(raw, output), "builtin",
        { id = rule.id, builtinID = rule.id,
            template = rule.template, values = copyValues(values), evidence = "rule" }
end
