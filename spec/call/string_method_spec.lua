local util = require("spec.util")

describe("string method call", function()
   describe("simple", function()
      it("pass", util.check [[
         print(("  "):rep(12))
      ]])

      it("fail", util.check_type_error([[
         print(("  "):rep("foo"))
      ]], {
         { msg = "argument 1: got string" },
      }))
   end)
   describe("with variable", function()
      it("pass", util.check [[
         local s = "a"
         s = s:gsub("a", "b") .. "!"
      ]])

      it("fail", util.check_type_error([[
         local s = "a"
         s = s:gsub(function() end) .. "!"
      ]], {
         { msg = "argument 1: got function" },
      }))
   end)
   describe("chained", function()
      it("pass", util.check [[
         print(("xy"):rep(12):sub(1,3))
      ]])

      it("fail", util.check_type_error([[
         print(("xy"):rep(12):subo(1,3))
      ]], {
         { msg = "invalid key 'subo' in type string" },
      }))
   end)
end)
