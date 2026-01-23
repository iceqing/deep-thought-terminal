#!/bin/bash
# 字符宽度测试脚本
# 用于诊断 Powerline/Nerd Font 显示问题

echo "=== Character Width Test ==="
echo ""

# 测试对齐
echo "--- Alignment Test ---"
echo "If lines don't align, there's a width mismatch"
echo ""
echo "12345678901234567890"
echo "│    │    │    │   │"
echo ""

# Powerline 箭头测试
echo "--- Powerline Arrows ---"
echo "Each arrow should occupy 1 cell"
printf ">\uE0B0<  Right solid arrow\n"
printf ">\uE0B1<  Right thin arrow\n"
printf ">\uE0B2<  Left solid arrow\n"
printf ">\uE0B3<  Left thin arrow\n"
printf ">\uE0B4<  Right round\n"
printf ">\uE0B6<  Left round\n"
echo ""

# Box drawing 测试
echo "--- Box Drawing ---"
echo "┌─────────────────┐"
echo "│  Box drawing    │"
echo "├─────────────────┤"
echo "│  Should align   │"
echo "└─────────────────┘"
echo ""

# Block 元素测试
echo "--- Block Elements ---"
printf ">\u2580< Upper half\n"
printf ">\u2584< Lower half\n"
printf ">\u2588< Full block\n"
printf ">\u258C< Left half\n"
printf ">\u2590< Right half\n"
echo ""

# Git 图标测试
echo "--- Nerd Font Icons ---"
printf ">\uE0A0< Git branch (Powerline)\n"
printf ">\uF113< Git branch (NF)\n"
printf ">\uF07C< Folder open\n"
printf ">\uF015< Home\n"
printf ">\uF120< Terminal\n"
echo ""

# p10k 常用字符测试
echo "--- p10k Common Characters ---"
echo "Simulated prompt:"
printf "\uE0B6 ~/path \uE0B0 master \uE0B0  \uE0B2 √ \uE0B2 12:00 \uE0B4\n"
echo ""
echo "If arrows look broken or misaligned, check:"
echo "1. Font has Powerline/Nerd Font glyphs"
echo "2. Run: p10k configure"
echo ""

# 宽度计算测试
echo "--- Width Calculation Test ---"
echo "These pairs should align if width=1:"
printf "A\uE0B0B\n"
printf "AXB\n"
echo ""
echo "These pairs should align if width=2:"
printf "A你B\n"
printf "A  B\n"
echo ""

echo "=== Test Complete ==="
