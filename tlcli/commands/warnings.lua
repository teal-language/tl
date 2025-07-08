local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table




local teal = require("teal.init")

local function right_pad(str, wid)
   return (" "):rep(wid - #str) .. str
end

return function(tlconfig)
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
      local status = tlconfig._disabled_warnings_set[v] and "disabled" or
      tlconfig._warning_errors_set[v] and "promoted to error" or
      "enabled"
      print(status)
   end

   os.exit(0)
end
