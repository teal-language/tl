#!/usr/bin/env bash

## ----------------------------------------
## Utilities
## ----------------------------------------

function for_all() {
   files="$1"
   where="$3"

   find "$where" -name "$files"
}

function strip_prefix_and_suffix() {
   local input="$1"
   local prefix="$2"
   local suffix="$3"

   local strip1="${input#"$prefix"}"
   local strip2="${strip1%"$suffix"}"
   echo "$strip2"
}

function restore_all_bak_files() {
   for_all '*.lua.bak' in _temp | while read -r luabak_file
   do
      local lua_file
      lua_file="$(strip_prefix_and_suffix "$luabak_file" "_temp/" ".bak")"
      cp "$luabak_file" "$lua_file"
   done
}

function move_all_lua1_to_err() {
   for_all '*.lua.1' in _temp | while read -r lua1_file
   do
      cp "$lua1_file" "$lua1_file.err"
   done
}

function remove_all_lua2() {
   for_all '*.lua.2' in _temp | while read -r lua2_file
   do
      rm "$lua2_file"
   done
}

## ----------------------------------------
## Build tasks
## ----------------------------------------

function move_all_lua1_to_lua() {
   for_all '*.lua.1' in _temp | while read -r lua1_file
   do
      local lua_file
      lua_file="$(strip_prefix_and_suffix "$lua1_file" "_temp/" ".1")"
      local luabak_file="_temp/$lua_file.bak"

      cp "$lua_file" "$luabak_file"
      cp "$lua1_file" "$lua_file"
   done
   exit 0
}

function restore_backup_and_fail() {
   restore_all_bak_files
   move_all_lua1_to_err
   remove_all_lua2
   exit 1
}

function diff_all_lua1_and_lua2() {
   for_all '*.lua.1' in _temp | while read -r lua1_file
   do
      local lua2_file
      lua2_file="$(strip_prefix_and_suffix "$lua1_file" "" ".1").2"

      diff "$lua1_file" "$lua2_file" || exit 1
   done
   exit 0
}

## ----------------------------------------
## Task launcher
## ----------------------------------------

task="$1"
shift

case "$task" in
"move_1_to_lua") move_all_lua1_to_lua ;;
"diff_1_and_2")  diff_all_lua1_and_lua2 ;;
"revert")        restore_backup_and_fail ;;
esac
