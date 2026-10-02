-- Read-only evidence for translation feedback. Candidates never participate in matching.
local C = McodeSTCN
local H = { version = 1 }
C.VariableHints = H

local statusNames = { explicit = "发现显式标记", rule = "已由规则识别",
    candidate = "疑似动态文本", unknown = "未发现线索" }
local nativeNames = { n = "玩家名", N = "玩家名", c = "职业", C = "职业",
    r = "种族", R = "种族", g = "性别分支", G = "性别分支", b = "换行", B = "换行" }
local factions = { alliance = "联盟", horde = "部落" }

local function text(value) return type(value) == "string" and value or "" end
local function plain(raw)
    -- Ignore link payloads and texture paths when looking for visible markers.
    return C.Normalize(raw):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
end
local function replaceOnce(s, old, new)
    local a, b = s:find(old, 1, true)
    if not a then return s end
    return s:sub(1, a - 1) .. new .. s:sub(b + 1)
end
local function markers(raw)
    -- Keep $B here: it is formatting evidence, not a dynamic player variable.
    local s = text(raw):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    local result, i = {}, 1
    while i <= #s do
        local tail, marker, kind = s:sub(i)
        if s:sub(i, i + 1) == "%%" then i = i + 2
        else
            if s:sub(i, i) == "$" then
                local code = s:sub(i + 1, i + 1)
                kind = nativeNames[code]
                if code == "g" or code == "G" then
                    marker = tail:match("^%$[gG][^:;]+:[^;]+;")
                elseif kind then marker = s:sub(i, i + 1) end
            elseif s:sub(i, i) == "%" then
                marker = tail:match("^%%%d+%$[-+#0]*%d*%.?%d*[cdiouxXeEfgGqs]")
                    or tail:match("^%%[-+#0]*%d*%.?%d*[cdiouxXeEfgGqs]")
                if marker then kind = "格式化标记（参数角色未知）" end
            end
            if marker then
                result[#result + 1] = { marker = marker, kind = kind }
                i = i + #marker
            else i = i + 1 end
        end
    end
    return result
end

local function sortedKeys(t)
    local keys = {}
    if type(t) == "table" then
        for k in pairs(t) do if type(k) == "string" then keys[#keys + 1] = k end end
    end
    table.sort(keys)
    return keys
end

local function inferFlag(item, hints)
    -- Event scope plus an anchored sentence is evidence for a candidate, not an identity check.
    if item.event ~= "CHAT_MSG_BG_SYSTEM_ALLIANCE" and item.event ~= "CHAT_MSG_BG_SYSTEM_HORDE"
        and item.event ~= "CHAT_MSG_BG_SYSTEM_NEUTRAL" then return end
    local s = plain(item.rawText or item.t)
    local actor, faction = s:match("^([^%s]+) captured the (%a+) [Ff]lag[!%.]$")
    local action = "夺取旗帜的玩家"
    local translation = "{玩家名}夺取了{阵营}的旗帜！"
    if not actor then
        faction, actor = s:match("^The (%a+) [Ff]lag was picked up by ([^%s]+)[!%.]$")
        action, translation = "拾取旗帜的玩家", "{阵营}的旗帜被{玩家名}拾取了！"
    end
    if not actor then
        faction, actor = s:match("^The (%a+) [Ff]lag was returned to its base by ([^%s]+)[!%.]$")
        action, translation = "归还旗帜的玩家", "{玩家名}把{阵营}的旗帜送回了基地！"
    end
    if not actor or not factions[string.lower(faction)] then return end
    -- Reject markup and obvious non-name fragments; do not query today's roster for an old record.
    if actor:find("[|{}$%%]") or actor:find("%d") then return end
    hints.candidateTemplate = replaceOnce(replaceOnce(s, actor, "{玩家名}"), faction, "{阵营}")
    hints.candidateTranslation = translation
    hints.referenceTranslation = replaceOnce(replaceOnce(translation, "{玩家名}", actor),
        "{阵营}", factions[string.lower(faction)])
    hints.reason = "战场事件与完整旗帜公告句式相符；未独立核实玩家身份或服务器原始模板。"
    hints.variables = {
        { name = "玩家名", value = actor, role = action,
          basis = "句中执行动作的位置符合玩家名用法。", certainty = "句式推断，身份未核实" },
        { name = "阵营", value = faction, role = "旗帜所属阵营",
          translated = factions[string.lower(faction)], basis = "原文的阵营名称直接修饰 flag。",
          certainty = "本句含义明确，泛化为变量仍需规则验证" },
    }
    hints.status = "candidate"
end

function H.Analyze(item, origin)
    item = type(item) == "table" and item or {}
    local raw = text(item.rawText or item.t)
    local hints = { analysisVersion = H.version, analysisOrigin = origin or "saved-record",
        analyzedText = raw, status = "unknown",
        explicitMarkers = markers(raw), variables = {}, serverTemplate = "未知" }
    local trusted = (item.variableEvidence == "rule" or item.variableEvidence == "dictionary")
        and text(item.cn) ~= "" and not item.history and not item.legacy
    if trusted and text(item.template) ~= "" then
        hints.status, hints.knownTemplate = "rule", item.template
        hints.ruleID = item.builtinID or item.ruleID
        hints.reason = item.variableEvidence == "rule" and "采集时内置公告规则已匹配，下面展示保存的捕获值。"
            or "采集时内置词典已匹配；没有保存的变量值不从当前角色信息补造。"
        for _, name in ipairs(sortedKeys(item.values)) do
            local value = item.values[name]
            if type(value) == "string" or type(value) == "number" then
                hints.variables[#hints.variables + 1] = { name = name, value = tostring(value),
                    role = "规则捕获参数", basis = "采集时保存的 values 字段。",
                    certainty = "已由匹配规则捕获，仍需核对规则语义" }
            end
        end
        if #hints.variables == 0 then hints.noValues = true end
    elseif #hints.explicitMarkers > 0 then
        hints.status, hints.reason = "explicit", "原文中直接发现格式标记；标记含义与支持范围仍需按代码核对。"
    else
        inferFlag(item, hints)
    end
    if not trusted and text(item.template) ~= "" then
        hints.relatedTemplate = item.template
        hints.relatedReason = (item.history or item.legacy)
            and "历史记录中的模板，不代表当前规则已确认。" or "候选匹配模板，不能认定为服务器原始模板。"
        if hints.status == "unknown" then hints.status = "candidate" end
    end
    return hints
end

function H.Get(item)
    -- Old records are analyzed from their saved text on demand, without altering their timestamp or count.
    if type(item.variableHints) == "table" and item.variableHints.analysisVersion == H.version
        and item.variableHints.analyzedText == text(item.rawText or item.t)
        and not item.history and not item.legacy then
        return item.variableHints, item.variableHints.analysisOrigin ~= "capture"
    end
    return H.Analyze(item), true
end

function H.Describe(module, item)
    local hints, computed = H.Get(item)
    local lines = { "【占位符与变量线索】", "判断状态：" .. (statusNames[hints.status] or "未发现线索") }
    if computed then lines[#lines + 1] = "分析来源：根据现有记录补充分析；未重新采集现场。"
    else lines[#lines + 1] = "分析来源：采集时生成的变量线索。" end
    local explicit = {}
    for _, entry in ipairs(hints.explicitMarkers) do
        explicit[#explicit + 1] = entry.marker .. "（" .. entry.kind .. "）"
    end
    lines[#lines + 1] = "原文中的显式标记：" .. (#explicit > 0 and table.concat(explicit, "、") or "未发现")
    lines[#lines + 1] = "服务器原始模板：未知；记录中的文字可能已经展开变量。"
    if hints.reason then lines[#lines + 1] = "判断依据：" .. hints.reason end
    if hints.knownTemplate then
        lines[#lines + 1] = "已匹配的内置模板：\n" .. hints.knownTemplate
        lines[#lines + 1] = "规则/词条标识：" .. tostring(hints.ruleID or "未记录")
    end
    if hints.candidateTemplate then lines[#lines + 1] = "候选模板（推断）：\n" .. hints.candidateTemplate end
    if hints.relatedTemplate then
        lines[#lines + 1] = "相关模板：\n" .. hints.relatedTemplate .. "\n" .. hints.relatedReason
    end
    for i, value in ipairs(hints.variables) do
        lines[#lines + 1] = "\n变量 " .. i .. "：" .. value.name
        lines[#lines + 1] = "  原文内容/已保存值：" .. value.value
        lines[#lines + 1] = "  语义角色：" .. value.role
        if value.translated then lines[#lines + 1] = "  对应译名：" .. value.translated end
        lines[#lines + 1] = "  判断依据：" .. value.basis
        lines[#lines + 1] = "  确认程度：" .. value.certainty
        if value.name == "玩家名" then
            local recorder = item.player and text(item.player.name) or ""
            lines[#lines + 1] = "  与采集角色的关系：" .. (recorder == "" and "采集角色未记录，无法比较。"
                or plain(value.value) == recorder and "文字与采集角色同名；此处仍应使用事件中的捕获值。"
                or "不同于采集角色 " .. recorder .. "。")
        end
    end
    if hints.noValues then lines[#lines + 1] = "变量值：未保存捕获值，或该条为固定文本；不能据此认定没有变量。" end
    if hints.status == "unknown" then lines[#lines + 1] = "目前没有足够线索；未发现显式标记不等于没有动态变量。" end
    if module == "announcements" then
        lines[#lines + 1] = "\n事件信息限制：事件名只作为来源线索，不能据此替换原文阵营或确认动作执行者的阵营。"
    end
    lines[#lines + 1] = "\n当前缺少的证据：服务器原始格式字符串及未保存的参数；候选变量还需身份或其他实发样本核实。"
    lines[#lines + 1] = "\n【给 AI 的翻译与回填提示】"
    if hints.referenceTranslation then
        lines[#lines + 1] = "本条参考译文（未应用）：\n" .. hints.referenceTranslation
        lines[#lines + 1] = "候选通用译文（未应用）：\n" .. hints.candidateTranslation
    end
    lines[#lines + 1] = "保留完整原文；候选模板仅作附加线索，不代表服务器原始模板。"
    lines[#lines + 1] = "事件中的玩家名应取事件捕获值，不固定写入规则，也不能用采集角色或 $n 代替。"
    lines[#lines + 1] = module == "announcements"
        and "回填位置：AnnouncementRules.lua；先核对已有规则、事件来源和完整句式边界。"
        or "回填位置：窗口内置词典；区分问候 GREET 与菜单 MENU，并核对角色占位符还原条件。"
    lines[#lines + 1] = "保留格式标记、颜色与链接；不要翻译链接 ID。推断信息不得直接启用为自动替换。"
    lines[#lines + 1] = "用不同变量值验证；人工样本标为测试数据。回填后更新对应词典版本，未核实项列为待确认。"
    return table.concat(lines, "\n")
end
