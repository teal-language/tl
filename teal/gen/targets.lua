local targets = {}







function targets.detect(override)
   local version = override or _VERSION
   if version == "Lua 5.1" or
      version == "Lua 5.2" then
      return "5.1"
   elseif version == "Lua 5.3" then
      return "5.3"
   elseif version == "Lua 5.4" then
      return "5.4"
   end
end

return targets
