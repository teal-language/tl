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

      it("cannot call on a bare string", util.check_syntax_error([[
         print("  ":rep("foo"))
      ]], {
         { msg = "cannot call a method on this expression" },
         { msg = "expected an expression" },
         { msg = "syntax error" },
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
      it("pass", util.gen([[

         print(("xy"):rep(12):sub(1,3))
         print(("%s"):format"%s":format(2))
         print(("%s b"):format"a":upper())
      ]], [[
         local _tl_compat53 = ((tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3) and require('compat53.module'); local string = _tl_compat53 and _tl_compat53.string or string
         print(("xy"):rep(12):sub(1,3))
         print(("%s"):format("%s"):format(2))
         print(("%s b"):format("a"):upper())
      ]]))

      it("fail", util.check_type_error([[
         print(("xy"):rep(12):subo(1,3))
      ]], {
         { msg = "invalid key 'subo' in type string" },
      }))
   end)
end)
