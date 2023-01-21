local util = require("spec.util")

describe("string", function()

   describe("byte", function()
      it("can return multiple values", util.check([[
         local n1, n2 = ("hello"):byte(1, 2)
         print(n1 + n2)
      ]]))
   end)

   describe("char", function()
      it("can take multiple inputs", util.check([[
         print(string.char(104, 101, 108, 108, 111) .. "!")
      ]]))
   end)

   describe("match", function()
      it("can take an optional init position", util.check([[
         local s1: string = string.match("hello world", "world")
         local s2: string = string.match("hello world", "world", 2)
      ]]))
   end)

end)
