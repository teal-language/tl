local tl = require("tl")

describe("tl.parse_program", function()
   it("returns a list of all require arguments", function()
      local tl_code = [[
         require("foo")
         require("foo.bar")
         local var = "hi"
         require(var)
         pcall(require, "baz")
      ]]

      local tks = assert(tl.lex(tl_code))
      local _, reqs = tl.parse_program(tks)
      assert.are.same({ "foo", "foo.bar", "baz" }, reqs)
   end)
end)
