#!/bin/bash
# novel-cli.sh — 小说写作台终端辅助工具
# 数据文件: /mnt/share/novel/data.json
# 用法: novel-cli.sh <命令> [参数]
#
# 命令:
#   list-chars          列出所有角色卡
#   add-char <name> <desc> <setting> <opening>  添加角色卡
#   show-char <id>      显示角色卡详情
#   list-wb             列出所有世界书条目
#   add-wb <key> <content>  添加世界书条目
#   show-data           显示完整数据 (JSON)
#   raw                 输出原始 JSON (供智能体解析)

DATA="/mnt/share/novel/data.json"

if [ ! -f "$DATA" ]; then
  echo "错误: $DATA 不存在"
  echo "请先在写作台点击「同步到终端」按钮"
  exit 1
fi

cmd="${1:-help}"

case "$cmd" in
  list-chars)
    jq -r '.characters[] | "\(.id) | \(.name) | \(.description[:40])"' "$DATA"
    ;;
  add-char)
    name="$2"; desc="$3"; setting="$4"; opening="$5"
    if [ -z "$name" ]; then echo "用法: add-char <name> <desc> <setting> <opening>"; exit 1; fi
    id="char_$(date +%s)"
    jq --arg id "$id" --arg name "$name" --arg desc "$desc" --arg set "$setting" --arg open "$opening" \
      '.characters += [{id:$id, name:$name, description:$desc, characterSetting:$set, openingStatement:$open, advancedCustomPrompt:"", tags:[]}]' "$DATA" > "$DATA.tmp" && mv "$DATA.tmp" "$DATA"
    echo "已添加角色卡: $id ($name)"
    ;;
  show-char)
    id="$2"
    jq --arg id "$id" '.characters[] | select(.id==$id)' "$DATA"
    ;;
  list-wb)
    jq -r '.worldBook[] | "\(.id) | \(.keyword) | \(.content[:40])"' "$DATA"
    ;;
  add-wb)
    keyword="$2"; content="$3"
    if [ -z "$keyword" ]; then echo "用法: add-wb <keyword> <content>"; exit 1; fi
    id="wb_$(date +%s)"
    jq --arg id "$id" --arg kw "$keyword" --arg ct "$content" \
      '.worldBook += [{id:$id, keyword:$kw, content:$ct, enabled:true}]' "$DATA" > "$DATA.tmp" && mv "$DATA.tmp" "$DATA"
    echo "已添加世界书条目: $id ($keyword)"
    ;;
  show-data)
    jq '.' "$DATA"
    ;;
  raw)
    cat "$DATA"
    ;;
  help|*)
    echo "小说写作台终端辅助工具"
    echo "数据文件: $DATA"
    echo ""
    echo "命令:"
    echo "  list-chars          列出所有角色卡"
    echo "  add-char <name> <desc> <setting> <opening>  添加角色卡"
    echo "  show-char <id>      显示角色卡详情"
    echo "  list-wb             列出所有世界书条目"
    echo "  add-wb <keyword> <content>  添加世界书条目"
    echo "  show-data           显示完整数据 (JSON)"
    echo "  raw                 输出原始 JSON"
    ;;
esac
