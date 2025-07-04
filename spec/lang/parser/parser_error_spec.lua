local tl = require("teal.api.v2")
local util = require("spec.util")

describe("parser errors", function()
   it("parse errors include filename", function ()
      local result = tl.check_string("local x 1", nil, "foo.tl")
      assert.same("foo.tl", result.syntax_errors[1].filename, "parse errors should contain .filename property")
   end)

   it("parse errors in a required package include filename of required file", function ()
      util.mock_io(finally, {
         ["bar.tl"] = [[
            local x 1
         ]],
      })

      local code = [[
         local bar = require "bar"
      ]]
      local result = tl.check_string(code, nil, "foo.tl")
      assert.is_not_nil(string.match(result.env.loaded["./bar.tl"].syntax_errors[1].filename, "bar.tl$"), "errors should contain .filename property")
   end)
end)
