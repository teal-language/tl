--------------------------------------------------------------------------------
-- Compiler debugging
--------------------------------------------------------------------------------
local TL_DEBUG = os.getenv("TL_DEBUG")
local TL_DEBUG_FACTS = os.getenv("TL_DEBUG_FACTS")
local TL_DEBUG_MAXLINE = math.maxinteger

if TL_DEBUG_FACTS and not TL_DEBUG then
   TL_DEBUG="1"
end

if TL_DEBUG then
   local max <const> = assert(tonumber(TL_DEBUG), "TL_DEBUG was defined, but not a number")
   if max < 0 then
      TL_DEBUG_MAXLINE = math.tointeger(-max)
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
            io.stderr:write(name, " :: ", event as string, "\n")
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

