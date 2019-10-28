local tl = require("tl")

describe("parser", function()
   it("parse errors include filename", function ()
      local tokens = tl.lex("local x 1")
      local syntax_errors = {}
      local i, program = tl.parse_program(tokens, syntax_errors, "foo.tl")
      assert.same("foo.tl", syntax_errors[1].filename, "parse errors should contain .filename property")
   end)
end)
