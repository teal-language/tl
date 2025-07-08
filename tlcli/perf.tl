--------------------------------------------------------------------------------
-- Performance tricks
--------------------------------------------------------------------------------

local teal = require("teal.init")

-- This is loading an internal API, but this is a "lower-level hack",
-- not intended as regular use of the Teal API.
local lexer = require("teal.lexer")

local record Jit
   on: function()
   off: function()
end

global jit: Jit

local record perf
end

local tl_lex = lexer.lex
local turbo_is_on = false

function perf.turbo(on: boolean)
   if on then
      if jit then
         jit.off()
         lexer.lex = function(input: string, filename: string): {lexer.Token}, {teal.Error}
            jit.on()
            local r1, r2 = tl_lex(input, filename)
            jit.off()
            return r1, r2
         end
      end
      collectgarbage("stop")
   else
      if jit then
         jit.on()
         lexer.lex = tl_lex
      end
      collectgarbage("restart")
   end
   turbo_is_on = on
end

function perf.is_turbo_on(): boolean
   return turbo_is_on
end

function perf.check_collect(i: integer)
   if i % 50 == 0 then
      collectgarbage()
   end
end

return perf
