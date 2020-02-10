local util = require("spec.util")

describe("string", function()
   util.init(it)

   describe("byte", function()
      util.check("can return multiple values", [[
         local n1, n2 = ("hello"):byte(1, 2)
         print(n1 + n2)
      ]])
   end)

   describe("char", function()
      util.check("can take multiple intputs", [[
         print(string.char(104, 101, 108, 108, 111) .. "!")
      ]])
   end)

end)
