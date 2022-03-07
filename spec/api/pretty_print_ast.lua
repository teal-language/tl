local tl = require("tl")
local util = require("spec.util")

describe("tl.pretty_print_ast", function()
   it("returns error for <close> attribute on non 5.4 target", function()
      local input = [[local x <close> = io.open("foobar", "r")]]
      local result = tl.process_string(input, false, tl.init_env(false, "off", "5.4"), "foo.tl")
      local output, err = tl.pretty_print_ast(result.ast, "5.3")

      assert.is_nil(output)
      assert.same({}, result.type_errors)
      assert.is_not_nil(result.gen_error)
      assert.match(result.gen_error, "<close> attribute")
   end)
end)
