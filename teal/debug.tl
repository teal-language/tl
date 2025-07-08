--------------------------------------------------------------------------------
-- Compiler debugging
--------------------------------------------------------------------------------
local record tldebug
   TL_DEBUG: string
   TL_DEBUG_FACTS: string
   TL_DEBUG_MAXLINE: integer
   write: function(...: string|number)
   flush: function()
end

function tldebug.write(...: string|number)
   io.stderr:write(...)
end

function tldebug.flush()
   io.stderr:flush()
end

tldebug.TL_DEBUG = os.getenv("TL_DEBUG")
tldebug.TL_DEBUG_FACTS = os.getenv("TL_DEBUG_FACTS")
tldebug.TL_DEBUG_MAXLINE = math.maxinteger

if tldebug.TL_DEBUG_FACTS and not tldebug.TL_DEBUG then
   tldebug.TL_DEBUG="1"
end

if tldebug.TL_DEBUG then
   local max <const> = assert(tonumber(tldebug.TL_DEBUG), "TL_DEBUG was defined, but not a number")
   if max < 0 then
      tldebug.TL_DEBUG_MAXLINE = math.tointeger(-max)
   elseif max > 1 then
      local count = 0
      local skip: string
      debug.sethook(function(event: debug.HookEvent)
         if event == "call" or event == "tail call" or event == "return" then
            local info <const> = debug.getinfo(2)

            if skip then
               if info.name == skip and event == "return" then
                  skip = nil
               end
               return
            elseif (info.name or "?"):match("^tl_debug_") and event == "call" then
               skip = info.name
               return
            end

            local name = info.name or "<anon>", info.currentline > 0 and "@" .. info.currentline or ""
            tldebug.write(name, " :: ", event as string, "\n")
            tldebug.flush()
         else
            count = count + 100
            if count > max then
               error("Too many instructions")
            end
         end
      end, "cr", 100)
   end
end

do
   local record DebugEntry
      mark: string
      y: integer
      x: integer
      msg: string
   end

   local curr_indent = 0
   local curr_entry: DebugEntry = nil
   local curr_y = 1

   local function loc(y: integer, x: integer): string
      return (tostring(y) or "?") .. ":" .. (tostring(x) or "?")
   end

   function tldebug.indent_push(mark: string, y: integer, x: integer, fmt: string, ...: any)
      if curr_entry then
         if curr_entry.y and (curr_entry.y > curr_y) then
            tldebug.write("\n")
            curr_y = curr_entry.y
         end
         tldebug.write(("   "):rep(curr_indent) .. curr_entry.mark .. " " ..
                         loc(curr_entry.y, curr_entry.x) .. " " ..
                         curr_entry.msg .. "\n")
         tldebug.flush()
         curr_entry = nil
         curr_indent = curr_indent + 1
      end
      curr_entry = {
         mark = mark,
         y = y,
         x = x,
         msg = fmt:format(...)
      }
   end

   function tldebug.indent_pop(mark: string, single: string, y: integer, x: integer, fmt?: string, ...: any)
      if curr_entry then
         local msg = curr_entry.msg
         if fmt then
            msg = fmt:format(...)
         end
         if y and (y > curr_y) then
            tldebug.write("\n")
            curr_y = y
         end
         tldebug.write(("   "):rep(curr_indent) .. single .. " " .. loc(y, x) .. " " .. msg .. "\n")
         tldebug.flush()
         curr_entry = nil
      else
         curr_indent = curr_indent - 1
         if fmt then
            tldebug.write(("   "):rep(curr_indent) .. mark .. " " .. fmt:format(...) .. "\n")
            tldebug.flush()
         end
      end
   end
end

return tldebug


