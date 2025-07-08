



local teal = require("teal.init")



local lexer = require("teal.lexer")








local perf = {}


local tl_lex = lexer.lex
local turbo_is_on = false

function perf.turbo(on)
   if on then
      if jit then
         jit.off()
         lexer.lex = function(input, filename)
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

function perf.is_turbo_on()
   return turbo_is_on
end

function perf.check_collect(i)
   if i % 50 == 0 then
      collectgarbage()
   end
end

return perf
