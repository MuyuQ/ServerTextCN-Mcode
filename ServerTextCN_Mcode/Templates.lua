-- Rendering helpers for shipped built-in translations; no user rule compiler.
local C = McodeSTCN
local allowed = { ["玩家名"] = true, ["阵营"] = true, ["据点"] = true,
    ["战场"] = true, ["数字"] = true, ["文本"] = true, ["职业"] = true, ["种族"] = true }
local native = { n = "玩家名", N = "玩家名", c = "职业", C = "职业", r = "种族", R = "种族" }

local function literal(text)
    return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

function C.Scan(text)
    if type(text) ~= "string" then return nil end
    local tokens, start, i = {}, 1, 1
    local function emit(last, token)
        if last >= start then tokens[#tokens + 1] = { text = text:sub(start, last) } end
        tokens[#tokens + 1] = token
    end
    while i <= #text do
        local ch = text:sub(i, i)
        if ch == "{" then
            local close = text:find("}", i + 1, true)
            if not close then return nil end
            local name = text:sub(i + 1, close - 1)
            if not allowed[name] then return nil end
            emit(i - 1, { name = name, marker = text:sub(i, close) })
            i, start = close + 1, close + 1
        elseif ch == "}" then return nil
        elseif ch == "$" then
            local code = text:sub(i + 1, i + 1)
            if native[code] then
                emit(i - 1, { name = native[code], native = code, marker = "$" .. code })
                i, start = i + 2, i + 2
            elseif code == "b" or code == "B" then
                emit(i - 1, { newline = true, marker = "$" .. code })
                i, start = i + 2, i + 2
            elseif code == "g" or code == "G" then
                local finish = text:find(";", i + 2, true)
                if not finish then return nil end
                local male, female = text:sub(i + 2, finish - 1):match("^([^:]+):([^:]+)$")
                if not male then return nil end
                emit(i - 1, { gender = true, male = male, female = female, marker = text:sub(i, finish) })
                i, start = finish + 1, finish + 1
            else i = i + 1 end
        else i = i + 1 end
    end
    if start <= #text then tokens[#tokens + 1] = { text = text:sub(start) } end
    return { tokens = tokens }
end

function C.Render(text, values, player)
    values, player = values or {}, player or C.Player()
    local info = C.Scan(text)
    if not info then return text end
    local parts = {}
    local playerVars = { ["玩家名"] = player.name, ["职业"] = player.class, ["种族"] = player.race }
    for _, token in ipairs(info.tokens) do
        if token.text then parts[#parts + 1] = token.text
        elseif token.newline then parts[#parts + 1] = "\n"
        elseif token.gender then
            local branch = player.sex == 2 and token.male or player.sex == 3 and token.female
            parts[#parts + 1] = branch and C.Render(branch, values, player) or token.marker
        elseif token.name then
            local value = values[token.name] or playerVars[token.name]
            if token.native and not values[token.name] then
                if token.native == "c" or token.native == "r" then value = value and string.lower(value) end
            end
            parts[#parts + 1] = value and value ~= "" and value or token.marker
        end
    end
    return table.concat(parts)
end

function C.ColorValue(raw, value, translated)
    local color, reset = raw:match("(|c%x%x%x%x%x%x%x%x)" .. literal(value) .. "(|r)")
    return color and color .. translated .. reset or translated
end

function C.WrapColor(raw, translated)
    local prefix, suffix = raw:match("^%s*(|c%x%x%x%x%x%x%x%x).-(|r)%s*$")
    if prefix and translated:sub(1, #prefix) ~= prefix then return prefix .. translated .. suffix end
    return translated
end

