local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local common = require("tlcli.common")
local perf = require("tlcli.perf")
local reader = require("teal.reader")
local block = require("teal.block")








local empty_index_map = {}






local json_special_codes = "[%z\1-\31\34\92]"
if not ("\0"):match("%z") then
   json_special_codes = "[\0-\31\34\92]"
end

local function json_escape(s)
   return "\\u" .. string.format("%04x", s:byte())
end

local function load_input(filename)
   if filename == "-" then
      local data = io.read("*a")
      if not data then
         return nil, "could not read stdin"
      end
      return { code = data, filename = "<stdin>" }, nil
   end

   local fd, err = io.open(filename, "rb")
   if not fd then
      return nil, err
   end

   local content = fd:read("*a")
   fd:close()

   if not content then
      return nil, "could not read " .. filename
   end

   return { code = content, filename = filename }, nil
end

local function map_for_kind(kind)
   local map = block.BLOCK_INDEXES[kind:upper()]
   if map then
      return map
   end
   if kind:sub(1, 3) == "op_" then
      return block.BLOCK_INDEXES.OP
   end
   return empty_index_map
end

local function child_indexes(bl)
   local indexes = {}
   local arr = bl
   for idx, _ in pairs(arr) do
      if math.type(idx) == "integer" then
         indexes[idx] = true
      end
   end

   local map = map_for_kind(bl.kind)
   for _, pos in pairs(map) do
      local numeric_pos = pos
      indexes[numeric_pos] = true
   end

   local ordered = {}
   for idx, _ in pairs(indexes) do
      table.insert(ordered, idx)
   end
   table.sort(ordered)
   return ordered
end

local function edge_name(kind, idx)
   local map = map_for_kind(kind)
   for name, pos in pairs(map) do
      local label = name
      local numeric_pos = pos
      if numeric_pos == idx then
         return label
      end
   end
   return tostring(idx)
end

local function write_json_string(fd, value)
   fd:write('"', value:gsub(json_special_codes, json_escape), '"')
end

local function print_errors(errs, fallback_name)
   for _, err in ipairs(errs) do
      local fname = err.filename or fallback_name
      common.printerr(string.format("%s:%d:%d: %s", fname, err.y, err.x, err.msg))
   end
end

local function write_json_block(fd, bl, indent)
   local next_indent = indent .. "  "
   fd:write(indent, "{\n")

   local entries = {}
   table.insert(entries, { key = "\"kind\"", val = function() write_json_string(fd, bl.kind) end })
   table.insert(entries, { key = "\"tk\"", val = function() write_json_string(fd, bl.tk) end })
   if bl.f then
      table.insert(entries, { key = "\"f\"", val = function() write_json_string(fd, bl.f) end })
   end
   if bl.y then table.insert(entries, { key = "\"y\"", val = function() fd:write(tostring(bl.y)) end }) end
   if bl.x then table.insert(entries, { key = "\"x\"", val = function() fd:write(tostring(bl.x)) end }) end
   if bl.yend then table.insert(entries, { key = "\"yend\"", val = function() fd:write(tostring(bl.yend)) end }) end
   if bl.xend then table.insert(entries, { key = "\"xend\"", val = function() fd:write(tostring(bl.xend)) end }) end
   if bl.is_longstring then
      table.insert(entries, { key = "\"is_longstring\"", val = function() fd:write("true") end })
   end

   local arr = bl
   for _, idx in ipairs(child_indexes(bl)) do
      local child = arr[idx]
      local name = edge_name(bl.kind, idx)
      local key_repr = string.format("%q", name)
      local idx_key = string.format("%q", tostring(idx))

      table.insert(entries, { key = idx_key, val = function()
         if child then
            write_json_block(fd, child, next_indent .. "  ")
         else
            fd:write("null")
         end
      end, })

      table.insert(entries, { key = key_repr, val = function()
         if child then
            write_json_block(fd, child, next_indent .. "  ")
         else
            fd:write("null")
         end
      end, })
   end

   for i, entry in ipairs(entries) do
      fd:write(next_indent, entry.key, ": ")
      entry.val()
      if i < #entries then
         fd:write(",")
      end
      fd:write("\n")
   end

   fd:write(indent, "}")
end

local function write_lua_block(fd, bl, indent)
   local next_indent = indent .. "  "
   fd:write(indent, "{\n")

   local lines = {}
   local function add_line(key_repr, value_writer)
      table.insert(lines, function()
         fd:write(next_indent, key_repr, " = ")
         value_writer()
      end)
   end

   add_line("kind", function() fd:write(string.format("%q", bl.kind)) end)
   if bl.tk then add_line("tk", function() fd:write(string.format("%q", bl.tk)) end) end
   if bl.f then add_line("f", function() fd:write(string.format("%q", bl.f)) end) end
   if bl.y then add_line("y", function() fd:write(tostring(bl.y)) end) end
   if bl.x then add_line("x", function() fd:write(tostring(bl.x)) end) end
   if bl.yend then add_line("yend", function() fd:write(tostring(bl.yend)) end) end
   if bl.xend then add_line("xend", function() fd:write(tostring(bl.xend)) end) end
   if bl.is_longstring then add_line("is_longstring", function() fd:write("true") end) end

   local arr = bl
   for _, idx in ipairs(child_indexes(bl)) do
      local child = arr[idx]
      local name = edge_name(bl.kind, idx)
      local function write_child()
         if child then
            write_lua_block(fd, child, next_indent .. "  ")
         else
            fd:write("nil")
         end
      end

      add_line("[" .. tostring(idx) .. "]", write_child)
      add_line("[" .. string.format("%q", name) .. "]", write_child)
   end

   for i, writer in ipairs(lines) do
      writer()
      if i < #lines then
         fd:write(",")
      end
      fd:write("\n")
   end

   fd:write(indent, "}")
end

local function first_file_arg(file_arg)
   if type(file_arg) == "table" then
      return file_arg[1]
   end
   return file_arg
end

return function(tlconfig, args)
   perf.turbo(true)
   tlconfig["quiet"] = true
   tlconfig["gen_compat"] = "off"

   local filename = first_file_arg(args["file"])
   local input, open_err = load_input(filename)
   if not input then
      common.die(open_err or "failed to read input")
   end

   local block_ast, errs = reader.read(input.code, input.filename)
   if errs and #errs > 0 then
      print_errors(errs, input.filename)
      os.exit(1)
   end

   if args["dump_format"] == "json" then
      write_json_block(io.stdout, block_ast, "")
   else
      write_lua_block(io.stdout, block_ast, "")
   end

   io.stdout:write("\n")
   os.exit(0)
end
