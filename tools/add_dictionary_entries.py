#!/usr/bin/env python3
r"""add_dictionary_entries.py —— ServerTextCN_Mcode 窗口词典批量补录工具。

把 TSV 里的词条增量并入 ServerTextCN_Mcode_Data.lua（GREET 问候 / MENU 菜单），
自动处理：键归一化（与插件/生成器同口径）、重复与冲突检测、按字母序插入、
词典版本号递增与 contentHash 重算。未命中的区域（NPC 索引、注释、其他表）
一律原样保留。

用法：
    python add_dictionary_entries.py 词条.tsv                # 演练：只报告，不写文件
    python add_dictionary_entries.py 词条.tsv --write        # 实际写入（自动生成 .bak 备份）
    python add_dictionary_entries.py 词条.tsv --write --force # 同键不同译文时覆盖旧译文
    python add_dictionary_entries.py --check                 # 校验词典版本头与 contentHash 是否一致

TSV 格式（UTF-8，制表符分隔；# 开头为注释，空行忽略）：
    英文原文<TAB>中文译文
    英文原文<TAB>中文译文<TAB>greet   # 可选第 3 列：greet=只进问候 / menu=只进菜单 / both=两边都进（默认）

词条规则（详见仓库 docs/03-补译与贡献指南.md）：
  · 英文键 = 服务器实发原文；颜色码、$B/$b、连续空白与 4+ 连点会按词典口径归一化；
  · 占位符 $n/$N/$c/$C/$r/$R/$g男:女; 原样保留，不要把实发角色名硬改成 $n；
  · 中文译文必须含汉字；译文可保留 $B（换行）、$n、$g…:…; 等占位符；
  · 键在词典里已存在且译文不同：默认跳过并在报告中列出，--force 才覆盖。

版本规则（与维护工程生成器一致）：
  · 词典版本格式 "年.月.日.当日修订号"（东八区日期）；同日多次修改递增修订号，
    跨日修改使用新日期的 .1；文件主体无变化则保持原版本；
  · contentHash = 去掉版本头块、统一 LF 换行后的文件主体 UTF-8 字节的 SHA-256。
"""
import argparse
import hashlib
import os
import re
import sys
from datetime import datetime, timedelta, timezone

BEGIN = "-- STCN DICTIONARY VERSION\n"
END = "-- END STCN DICTIONARY VERSION\n"
CJK = re.compile(r"[\u4e00-\u9fff]")
HASH_RE = re.compile(r'contentHash\s*=\s*"([0-9a-f]{64})"')

DEFAULT_DATA = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "ServerTextCN_Mcode", "ServerTextCN_Mcode_Data.lua")


# ---------------------------------------------------------------- 归一化（与生成器/插件同口径）
def norm(s):
    """值归一：颜色代码剥离 + 内部空白折叠。"""
    s = re.sub(r"\|c[0-9a-fA-F]{8}", "", s)
    s = s.replace("|r", "")
    return re.sub(r"\s+", " ", s).strip()


def norm_key(s):
    """键归一：值归一 + $B/$b 折叠成空格 + ≥4 连续句点折叠成标准省略号。"""
    s = s.replace("$B", " ").replace("$b", " ")
    s = re.sub(r"\.{4,}", "...", s)
    return norm(s)


def lua_str(s):
    """按生成器的转义规则输出 Lua 字符串字面量。"""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') \
                  .replace("\r", "\\r").replace("\n", "\\n") + '"'


def lua_unquote(text):
    """还原 lua_str 产生的转义（\\n \\r \\\" \\\\，其余按字面）。"""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "\\" and i + 1 < n:
            out.append({"n": "\n", "r": "\r", '"': '"', "\\": "\\"}.get(text[i + 1], text[i + 1]))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


# ---------------------------------------------------------------- TSV 读取
def read_tsv(path):
    """读取 TSV，返回 (词条列表, 跳过原因列表)。目标列映射：greet/menu/both。"""
    entries, skipped = [], []
    for lineno, raw in enumerate(open(path, encoding="utf-8-sig").read().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "\t" not in line:
            skipped.append((lineno, raw, "没有制表符：第 1、2 列必须用 Tab 分隔"))
            continue
        parts = (line.split("\t") + ["", ""])[:3]
        en, zh, target = norm(parts[0]), norm(parts[1]), parts[2].strip().lower() or "both"
        if target not in ("greet", "menu", "both"):
            skipped.append((lineno, raw, "第 3 列只能是 greet / menu / both"))
            continue
        if not en:
            skipped.append((lineno, raw, "英文键为空"))
            continue
        if not CJK.search(zh):
            skipped.append((lineno, raw, "译文不含中文（纯符号/纯英文不予收录）"))
            continue
        entries.append((norm_key(en), zh, target, lineno))
    return entries, skipped


# ---------------------------------------------------------------- 词典文件解析
def split_dictionary(text):
    """拆出词典版本与文件主体（统一 LF 换行）。返回 (version, body)。"""
    text = text.replace("\r\n", "\n").replace("\r", "\n").lstrip("\ufeff")
    if not text.startswith(BEGIN):
        raise SystemExit("错误：词典文件缺少版本头（-- STCN DICTIONARY VERSION），拒绝修改。")
    if END not in text:
        raise SystemExit("错误：词典版本头不完整（缺少 END 标记），拒绝修改。")
    header, body = text.split(END, 1)
    m = re.search(r'\bversion\s*=\s*"(\d{4}\.\d{2}\.\d{2}\.[1-9]\d*)"', header)
    if not m:
        raise SystemExit("错误：版本头里没有合法的 version 号，拒绝修改。")
    return m.group(1), body


def body_hash(body):
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def scan_lua_string(line, start):
    """从 line[start]（必须是引号）扫描一个 Lua 字符串，返回 (内容, 结束下标)。"""
    quote = line[start]
    i, n = start + 1, len(line)
    out = []
    while i < n:
        c = line[i]
        if c == "\\" and i + 1 < n:
            out.append({"n": "\n", "r": "\r", '"': '"', "\\": "\\"}.get(line[i + 1], line[i + 1]))
            i += 2
            continue
        if c == quote:
            return "".join(out), i
        out.append(c)
        i += 1
    raise ValueError("字符串没有闭合引号")


def parse_entry(raw):
    """解析一行词条 `["键"] = "值",`，返回 (键, 值) 或 None。"""
    s = raw.strip()
    if not (s.startswith("[") and s.endswith(",")):
        return None
    try:
        if s[1] not in "\"'":
            return None
        key, pos = scan_lua_string(s, 1)
        if s[pos + 1:pos + 4] != "] =":
            return None
        rest = s[pos + 4:].lstrip()
        if not rest.startswith("\""):
            return None
        value, end = scan_lua_string(rest, 0)
        if rest[end + 1:].strip() not in ("", ","):
            return None
        return lua_unquote(key), value
    except ValueError:
        return None


def locate_sections(body):
    """定位 GREET / MENU 两个表。返回 (行列表, {名: {"start": 行号, "end": 行号, "lines": [(行号, 行文本)]}})。

    start = "GREET = {" 所在行，end = 收尾 "}," 所在行，条目行位于两者之间。
    """
    lines = body.split("\n")
    sections = {}
    name = None
    for idx, raw in enumerate(lines):
        s = raw.strip()
        if name is None:
            if s in ("GREET = {", "MENU = {"):
                name = s.split(" =")[0]
                sections[name] = {"start": idx, "end": None, "lines": []}
            continue
        if s == "},":
            sections[name]["end"] = idx
            name = None
            continue
        if s.startswith("["):
            sections[name]["lines"].append((idx, raw))
    missing = {"GREET", "MENU"} - set(sections)
    if missing or name is not None:
        raise SystemExit("错误：词典主体结构不符合预期（缺表或表未闭合），拒绝修改。")
    for sec_name, sec in sections.items():
        if not sec["lines"] or sec["end"] is None:
            raise SystemExit("错误：%s 表为空或未闭合，拒绝修改。" % sec_name)
        for _, raw in sec["lines"]:
            if parse_entry(raw) is None:
                raise SystemExit("错误：%s 表中存在无法解析的词条行，拒绝修改以保护词典：\n    %s"
                                 % (sec_name, raw.strip()[:100]))
    return lines, sections


def build_header(version, digest):
    """按生成器格式重建版本头块。"""
    return (BEGIN
            + "-- 窗口词典版本独立于插件版本；内容变化时递增，同内容生成保留版本。\n"
            + "McodeSTCN_DictionaryInfo = {\n"
            + '    version = "%s",\n' % version
            + '    contentHash = "%s",\n' % digest
            + "}\n"
            + END)


# ---------------------------------------------------------------- 合并
def merge_section(entries, lines, sections, sec_name, targets, force, stats):
    """把词条并入一个表：整个表按键重排后一次性替换，天然免掉行号位移问题。

    未触及的条目保留原始行文本（字节不变），因此 diff 里只会出现新增/替换的行。
    """
    sec = sections[sec_name]
    pairs = []  # [键, 译文, 原始行文本(None=新条目/被替换)]
    for _, raw in sec["lines"]:
        key, value = parse_entry(raw)
        pairs.append([key, value, raw])

    for key, zh, target_kind, lineno in entries:
        if target_kind not in targets:
            continue
        found = [p for p in pairs if p[0] == key]
        if found:
            if found[0][1] == zh:
                stats["dup"] += 1
            elif force:
                stats["replaced"] += 1
                found[0][1] = zh
                found[0][2] = None
            else:
                stats["conflict"].append((key, found[0][1], zh))
        else:
            stats["added" if sec_name == "GREET" else "menu_added"] += 1
            pairs.append([key, zh, None])

    pairs.sort(key=lambda p: p[0])
    new_texts = ["\t\t[%s] = %s," % (lua_str(key), lua_str(zh)) if raw is None else raw
                 for key, zh, raw in pairs]
    lines[sec["start"] + 1: sec["end"]] = new_texts


def main():
    ap = argparse.ArgumentParser(description="ServerTextCN_Mcode 窗口词典批量补录")
    ap.add_argument("tsv", nargs="?", help="词条 TSV 文件（英文<TAB>中文[<TAB>greet|menu|both]）")
    ap.add_argument("--data", default=DEFAULT_DATA, help="词典文件路径（默认自动定位插件目录）")
    ap.add_argument("--write", action="store_true", help="实际写入（默认演练，只报告不落盘）")
    ap.add_argument("--force", action="store_true", help="同键不同译文时覆盖旧译文（默认跳过）")
    ap.add_argument("--check", action="store_true", help="只校验版本头与 contentHash，不读取 TSV")
    args = ap.parse_args()

    if not os.path.exists(args.data):
        raise SystemExit("错误：找不到词典文件 %s" % args.data)
    with open(args.data, encoding="utf-8-sig") as f:
        text = f.read().replace("\r\n", "\n").replace("\r", "\n")
    version, body = split_dictionary(text)
    print("当前词典版本：%s" % version)
    m = HASH_RE.search(text)
    if m:
        ok = m.group(1) == body_hash(body)
        print("contentHash 校验：%s" % ("一致" if ok else "不一致（主体被改过而版本头未更新！）"))
        if args.check and not ok:
            sys.exit(1)
    else:
        print("contentHash 校验：版本头里没有 contentHash 字段")
    if args.check:
        return

    if not args.tsv:
        raise SystemExit("错误：需要提供 TSV 文件（或使用 --check）。")
    if not os.path.exists(args.tsv):
        raise SystemExit("错误：找不到 TSV 文件 %s" % args.tsv)
    entries, skipped = read_tsv(args.tsv)
    for lineno, raw, why in skipped:
        print("[跳过第 %d 行] %s ｜ %s" % (lineno, why, raw[:60]))
    if not entries:
        print("TSV 里没有可收录的词条，退出。")
        return
    print("TSV 词条：%d 条（跳过 %d 条）" % (len(entries), len(skipped)))

    lines, sections = locate_sections(body)
    before = len(lines)
    stats = {"added": 0, "menu_added": 0, "replaced": 0, "dup": 0, "conflict": []}
    # 从文件后部往前处理，前面的行号不受影响
    merge_section(entries, lines, sections, "MENU", ("menu", "both"), args.force, stats)
    merge_section(entries, lines, sections, "GREET", ("greet", "both"), args.force, stats)
    new_body = "\n".join(lines)

    for key, old, new in stats["conflict"]:
        print("[冲突·跳过] %s\n    词典现值：%s\n    TSV 译文：%s（要覆盖请加 --force）" % (key[:70], old[:40], new[:40]))
    print("重复（同键同译文，忽略）：%d 条" % stats["dup"])
    if stats["replaced"]:
        print("覆盖旧译文：--force 生效，%d 条" % stats["replaced"])
    print("结果：GREET +%d，MENU +%d，总行数 %d → %d" % (stats["added"], stats["menu_added"], before, len(lines)))

    if new_body == body:
        print("词典主体没有变化，保持版本 %s。" % version)
        return

    today = datetime.now(timezone(timedelta(hours=8))).strftime("%Y.%m.%d")
    if version.rsplit(".", 1)[0] >= today:
        day, revision = version.rsplit(".", 1)
        new_version = day + "." + str(int(revision) + 1)
    else:
        new_version = today + ".1"
    digest = body_hash(new_body)
    print("词典版本：%s → %s" % (version, new_version))
    print("新 contentHash：%s" % digest)

    if not args.write:
        print("\n【演练模式】未写入任何文件。确认无误后加 --write 执行。")
        return

    backup = args.data + ".bak"
    with open(backup, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    with open(args.data, "w", encoding="utf-8", newline="") as f:
        f.write(build_header(new_version, digest) + new_body)
    print("已写入 %s（备份在 %s）" % (args.data, backup))
    print("下一步：进游戏 /reload，重访对应 NPC 验证新词条命中。")


if __name__ == "__main__":
    main()
