local util = require("spec.util")

describe("assignment to function", function()
   it("does not crash when using plain function definitions", util.check([[
      local my_load: function(string, ? string, ? string, ? table): (function, string)

      local function run_file()
         local chunk: function(any):(any)
         chunk = my_load("")
      end
   ]]))
end)
