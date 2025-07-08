--------------------------------------------------------------------------------
-- tl warnings
--------------------------------------------------------------------------------

local type TlConfig = require("tlcli.tlconfig")
local teal = require("teal.init")

local function right_pad(str: string, wid: integer): string
   return (" "):rep(wid - #str) .. str
end

return function(tlconfig: TlConfig)
   local w = {}
   local longest = 0
   for warning, _ in pairs(teal.warning_set()) do
      if #warning > longest then
         longest = #warning
      end
      table.insert(w, warning)
   end
   table.sort(w)

   print("Compiler warnings:")
   for _, v in ipairs(w) do
      io.write(" ", right_pad(v, longest), " : ")
      local status = tlconfig._disabled_warnings_set[v] and "disabled"
         or tlconfig._warning_errors_set[v] and "promoted to error"
         or "enabled"
      print(status)
   end

   os.exit(0)
end
