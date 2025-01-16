
local code = require("dit.code")
local tab_complete = require("dit.tab_complete")
local json = require("cjson")

local lfs = require("lfs")

local cfg = require("luarocks.core.cfg")
cfg.init()
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
fs.init()

local filename = dir.normalize(fs.absolute_name(buffer:filename()))
local filename_code = 0

local trace
local locals
local trace_at = 0

local function tracing_this_file(info)
   return info[1] == filename_code
end

local function load_trace()
   if lfs.attributes(filename .. ".trace") then
      local cbor = require("cbor")
      local fd = io.open(filename .. ".trace", "r")
      if fd then
         trace = cbor.decode(fd:read("*a"))
         fd:close()
      end
      for i, f in ipairs(trace.filenames) do
         if f == filename then
            filename_code = i
            break
         end
      end
      if trace then
         trace_at = 1
         for i, t in ipairs(trace.trace) do
            if tracing_this_file(t) then
               trace_at = i
               break
            end
         end
      end
   end
end

local lines
local last_line = 0
local commented_lines = {}
local controlled_change = false
local type_report

local function each_note(y, x)
   return coroutine.wrap(function()
      if not lines then return end
      local curr = lines[y]
      local line = buffer[y]
      if not curr then return end
      for _, note in ipairs(curr) do
         local fchar = note.column
         local lchar = fchar
         if note.name then
            lchar = fchar + #note.name - 1
         else
            while line[lchar+1]:match("[A-Za-z0-9_]") do
               lchar = lchar + 1
            end
         end
         if not x or (x >= fchar and x <= lchar) then
            coroutine.yield(note, fchar, lchar)
         end
      end
   end)
end

function highlight_line(line, y)
   local ret = {}
   for i = 1, #line do ret[i] = " " end
   
   if trace_at > 0 then
      local info = trace.trace[trace_at]
      if tracing_this_file(info) and info[2] == y then
         for i = 1, #line do ret[i] = "*" end
         return table.concat(ret)
      end
   end

   for note, fchar, lchar in each_note(y) do
      for i = fchar, lchar do
         if note.what == "error" then
            ret[i] = "*"
         elseif note.what == "warning" then
            if ret[i] ~= "*" then
               ret[i] = "S"
            end
         end
      end
   end
   if ret == nil then
      return ""
   end
   for i = 1, #ret do
      if not ret[i] then
         ret[i] = " "
      end
   end
   return table.concat(ret)
end

function on_change()
   if not controlled_change then
      lines = nil
   end
end

function on_save(filename)
   local pd = io.popen("tl types " .. filename .. " 2>&1")
   lines = {}
   local state = "start"
   local buf = {}
   last_line = 0
   for line in pd:lines() do
      if state == "start" then
         if line == "" then
            state = "skip"
         elseif line:match("^========") then
            state = "error"
         else
            state = "json"
         end
      elseif state == "error" then
         if line == "" then
            state = "skip"
         elseif line:match("^%d+ warning") then
            state = "warning"
         end
      elseif state == "warning" then
         if line == "" then
            state = "skip"
         elseif line:match("^========") then
            state = "error"
         end
      end
      
      if state == "json" then
         table.insert(buf, line)
      elseif state == "skip" then
         state = "json"
      elseif state == "error" or state == "warning" then
         local file, y, x, err = line:match("([^:]*):(%d*):(%d*): (.*)")
         if file and filename:sub(-#file) == file then
            y = tonumber(y)
            x = tonumber(x)
            lines[y] = lines[y] or {}
            table.insert(lines[y], {
               column = x,
               text = err,
               what = state,
            })
            if y > last_line then
               last_line = y
            end
         end
      end
   end
   if #buf > 0 then
      local input = table.concat(buf)
      local pok, data = pcall(json.decode, input)
      if not pok then
         error("Error decoding JSON: " .. data .. "\n" .. input:sub(1, 100))
      else
         type_report = data
      end
   end
   pd:close()
end

function highlight_file(filename)
   on_save(filename)
end

local function type_at(px, py)
   if not type_report then
      return
   end
   local ty = type_report.by_pos[buffer:filename()][tostring(py)]
   if not ty then
      return
   end
   local xs = {}
   local ts = {}
   for x, t in pairs(ty) do
      x = tonumber(x)
      xs[#xs + 1] = math.floor(x)
      ts[x] = math.floor(t)
   end
   table.sort(xs)

   for i = #xs, 1, -1 do
      local x = xs[i]
      if px >= x then
         return type_report.types[tostring(ts[x])]
      end
   end
end

function on_alt(key)
   if key == 'L' then
      local filename = buffer:filename()
      local x, y = buffer:xy()
      local page = tabs:open(filename:gsub("%.tl$", ".lua"))
      tabs:set_page(page)
      tabs:get_buffer(page):go_to(x, y)
   end
end

function on_ctrl(key)
   if key == '_' then
      controlled_change = true
      code.comment_block("--", "%-%-", lines, commented_lines)
      controlled_change = false
   elseif key == "N" then
      if not lines then
         return
      end
      local x, y = buffer:xy()
      if lines[y] then
         for _, note in ipairs(lines[y]) do
            if note.column > x then
               buffer:go_to(note.column, y)
               return
            end
         end
      end
      for line = y+1, last_line do
         if lines[line] then
            buffer:go_to(lines[line][1].column, line)
            return
         end
      end
   elseif key == "D" then
      local x, y = buffer:xy()
      local t = type_at(x, y)
      if t and t.x then
         local tx, ty = t.x, t.y
         if tx == x and ty == y then
            local name = buffer[ty]:match("local%s*([A-Za-z_][A-Za-z0-9_]*)%s*:")
            if not name then
               name = buffer[ty]:match("global%s*([A-Za-z_][A-Za-z0-9_]*)%s*:")
            end
            if not name then
               return true
            end
            local l = y + 1
            while true do
               local line = buffer[l]
               if not line then
                  return true
               end
               local found = line:match("^%s*()" .. name .. "%s*=%s*")
               if found then
                  tx = found
                  ty = l
                  break
               end
               l = l + 1
            end
         end

         tabs:mark_jump()
         if t.file and t.file ~= buffer:filename() then
            local page = tabs:open(t.file)
            tabs:set_page(page)
         end
         if tx then
            buffer:go_to(tx, ty)
         end
      end
   end
   return true
end

local function show_trace_location()
   if trace_at > 0 then
      local info = trace.trace[trace_at]
      if not info then
         return
      end
      local out = {}
      table.insert(out, "#: " .. trace_at)
      table.insert(out, "filename: " .. trace.filenames[info[1]])
      table.insert(out, "line: " .. info[2])
      buffer:go_to(1, info[2])
      locals = {}
      for k, v in pairs(info[3]) do
         locals[trace.strings[k]] = trace.strings[v]
      end
      buffer:draw_popup(out)
   end
end

local function trace_forward(y)
   local found
   for i = trace_at + 1, #trace.trace do
      local t = trace.trace[i]
      if tracing_this_file(t) and ((not y) or t[2] == y) then
         found = i
         break
      end
   end
   if not found then
      for i = 1, trace_at - 1 do
         local t = trace.trace[i]
         if tracing_this_file(t) and ((not y) or t[2] == y) then
            found = i
            break
         end
      end
   end
   if found then
      trace_at = found
   end
end

local function trace_backward(y)
   local found
   for i = trace_at - 1, 1, -1 do
      local t = trace.trace[i]
      if tracing_this_file(t) and ((not y) or t[2] == y) then
         found = i
         break
      end
   end
   if not found then
      for i = #trace.trace, trace_at + 1, -1 do
         local t = trace.trace[i]
         if tracing_this_file(t) and ((not y) or t[2] == y) then
            found = i
            break
         end
      end
   end
   if found then
      trace_at = found
   end
end

local key_handlers = {
   ["F1"] = function()
      if not trace then
         load_trace()
      end

      trace_backward()
      show_trace_location()
   end,
   ["F2"] = function()
      if not trace then
         load_trace()
      end
      
      local x, y = buffer:xy()
      trace_forward(y)

      show_trace_location()
   end,
   ["F12"] = function()
      if not trace then
         load_trace()
      end

      -- search trace history backwards for current line
      local x, y = buffer:xy()
      trace_backward(y)

      show_trace_location()
   end,
   ["F4"] = function()
      if not trace then
         load_trace()
      end

      trace_forward()
      show_trace_location()
   end,
   -- ["F3"] = find,
   -- ["F5"] = multiple_cursors,
   ["F7"] = code.expand_selection,
   -- ["F8"] = delete_line,
   ["F9"] = code.pick_merge_conflict_branch,
   -- ["F10"] = quit
   -- ["F12"] = debug_keyboard_codes,
}

function on_fkey(key)
   if key_handlers[key] then
      key_handlers[key]()
   end
end

function on_key(code)
   local handled = false

   local selection, startx, starty, stopx, stopy = buffer:selection()
   if selection == "" then
      if code == 13 then
         local x, y = buffer:xy()
         local line = buffer[y]
         if line:sub(1, x - 1):match("^%s*$") and line:sub(x):match("^[^%s]") then
            buffer:begin_undo()
            buffer:emit("\n")
            buffer:go_to(x, y, false)
            buffer:end_undo()
            handled = true
         end
      elseif code == 330 then
         local x, y = buffer:xy()
         local line = buffer[y]
         local nextline = buffer[y+1]
         if x == #line + 1 and line:match("^%s*$") and nextline:match("^"..line) then
            buffer:begin_undo()
            buffer:select(x, y, x, y + 1)
            buffer:emit("\8")
            buffer:end_undo()
            handled = true
         end
      end
   end
   local tab_handled = false
   if not handled and starty == stopy then
      tab_handled = tab_complete.on_key(code)
   end
   return tab_handled or handled
end

function after_key(code)
   local x, y = buffer:xy()

   local out
   
   for note in each_note(y, x) do
      out = out or {}
      table.insert(out, note.text)
   end
   
   if not out then
      local t = type_at(x, y)
      if t then
         out = out or {}
         table.insert(out, t.str)
      end
   end
   
   if trace then
      local tk = buffer:token()
      out = out or {}
      if locals[tk] then
         table.insert(out, "= " .. locals[tk])
      end
   end
   
   if out then
      buffer:draw_popup(out) -- lines[y][x].description)
   end
end
