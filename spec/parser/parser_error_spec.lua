local tl = require("tl")

describe("parser errors", function()
   it("parse errors include filename", function ()
      local tokens = tl.lex("local x 1")
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors, "foo.tl")
      assert.same("foo.tl", syntax_errors[1].filename, "parse errors should contain .filename property")
   end)

   it("parse errors in a required package include filename of required file", function ()
      local io_open = io.open
      finally(function() io.open = io_open end)
      io.open = function (filename, mode)
         if string.match(filename, "bar.tl$") then
            -- Return a stub file handle
            return {
               read = function (_, format)
                  if format == "*a" then
                     return "local x 1"                  -- Return fake bar.tl content
                  else
                     error("Not implemented!")  -- Implement other modes if needed
                  end
               end,
               close = function () end,
            }
         else
            return io_open(filename, mode)
         end
      end

      local tokens = tl.lex([[
         local bar = require "bar"
      ]])
      local _, ast = tl.parse_program(tokens, {}, "foo.tl")
      local result = {
         syntax_errors = {},
         type_errors = {},
         unknowns = {},
      }
      tl.type_check(ast, { lax = true, filename = "foo.tl" , result = result })
      assert.is_not_nil(string.match(result.syntax_errors[1].filename, "bar.tl$"), "type errors should contain .filename property")
   end)
end)
