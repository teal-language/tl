local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local _tl_math_maxinteger = math.maxinteger or math.pow(2, 53); local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string


local tldebug = {}







function tldebug.write(...)
   io.stderr:write(...)
end

function tldebug.flush()
   io.stderr:flush()
end

tldebug.TL_DEBUG = os.getenv("TL_DEBUG")
tldebug.TL_DEBUG_FACTS = os.getenv("TL_DEBUG_FACTS")
tldebug.TL_DEBUG_MAXLINE = _tl_math_maxinteger

if tldebug.TL_DEBUG_FACTS and not tldebug.TL_DEBUG then
   tldebug.TL_DEBUG = "1"
end

if tldebug.TL_DEBUG then
   local max = assert(tonumber(tldebug.TL_DEBUG), "TL_DEBUG was defined, but not a number")
   if max < 0 then
      tldebug.TL_DEBUG_MAXLINE = math.tointeger(-max)
   elseif max > 1 then
      local count = 0
      local skip
      debug.sethook(function(event)
         if event == "call" or event == "tail call" or event == "return" then
            local info = debug.getinfo(2)

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
            tldebug.write(name, " :: ", event, "\n")
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







   local curr_indent = 0
   local curr_entry = nil
   local curr_y = 1

   local function loc(y, x)
      return (tostring(y) or "?") .. ":" .. (tostring(x) or "?")
   end

   function tldebug.indent_push(mark, y, x, fmt, ...)
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
         msg = fmt:format(...),
      }
   end

   function tldebug.indent_pop(mark, single, y, x, fmt, ...)
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
