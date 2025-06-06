local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local _tl_math_maxinteger = math.maxinteger or math.pow(2, 53); local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string


local TL_DEBUG = os.getenv("TL_DEBUG")
local TL_DEBUG_FACTS = os.getenv("TL_DEBUG_FACTS")
local TL_DEBUG_MAXLINE = _tl_math_maxinteger

if TL_DEBUG_FACTS and not TL_DEBUG then
   TL_DEBUG = "1"
end

if TL_DEBUG then
   local max = assert(tonumber(TL_DEBUG), "TL_DEBUG was defined, but not a number")
   if max < 0 then
      TL_DEBUG_MAXLINE = math.tointeger(-max)
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
            io.stderr:write(name, " :: ", event, "\n")
            io.stderr:flush()
         else
            count = count + 100
            if count > max then
               error("Too many instructions")
            end
         end
      end, "cr", 100)
   end
end

return {
   TL_DEBUG = TL_DEBUG,
   TL_DEBUG_FACTS = TL_DEBUG_FACTS,
   TL_DEBUG_MAXLINE = TL_DEBUG_MAXLINE,
}
