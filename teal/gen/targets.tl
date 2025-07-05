local record targets
   enum GenTarget
      "5.1"
      "5.3"
      "5.4"
   end
end

function targets.detect(override?: string): targets.GenTarget
   local version = override or _VERSION
   if version == "Lua 5.1"
      or version == "Lua 5.2" then
      return "5.1"
   elseif version == "Lua 5.3" then
      return "5.3"
   elseif version == "Lua 5.4" then
      return "5.4"
   end
end

return targets
