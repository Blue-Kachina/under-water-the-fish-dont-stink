#!/bin/bash
cd /d/Dev/GameDev/under-water-the-fish-dont-stink
G="/c/Users/Admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
name=$1; extra=$2; to=${3:-240}
if [ -f tests/$name.tscn ]; then target=res://tests/$name.tscn; else target=res://tests/$name.gd; fi
timeout $to "$G" --headless $extra --path . $target > logs/new_hunters/final/$name.log 2>&1
ec=$?
f=$(grep -ciE "FAIL" logs/new_hunters/final/$name.log); se=$(grep -c "SCRIPT ERROR" logs/new_hunters/final/$name.log)
echo "$name exit=$ec faillines=$f scripterr=$se" >> logs/new_hunters/final/_summary.txt
