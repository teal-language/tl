#!/usr/bin/env lua

-- Little trick for running development versions:
-- when tl.lua and tl are in the same folder, prefer that tl.lua
do
   local script_path = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or "."
   local save_package_path = package.path
   package.path = script_path .. "/?.lua;" .. script_path .. "/?/init.lua;" .. package.path

   -- get the whole API into package.loaded
   require("teal")

   -- but otherwise don't pollute package.path inadvertedly
   package.path = save_package_path
end

require("tlcli.main")({...})
