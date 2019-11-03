local tl = require("tl")

describe("typecheck errors", function()
   it("type errors include filename", function ()
      local tokens = tl.lex("local x: string = 1")
      local _, ast = tl.parse_program(tokens, {})
      local errors, unknowns = tl.type_check(ast, false, "foo.tl")
      assert.same("foo.tl", errors[1].filename, "type errors should contain .filename property")
   end)

   it("type errors in a required package include filename of required file", function ()
      local io_open = io.open
      io.open = function (filename, mode)
         if string.match(filename, "bar.tl$") then
            -- Return a stub file handle
            return {
               read = function (_, format)
                  if format == "*a" then
                     return "local x: string = 1"        -- Return fake bar.tl content
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
      local errors, unknowns = tl.type_check(ast, true, "foo.tl")
      assert.is_not_nil(string.match(errors[1].filename, "bar.tl$"), "type errors should contain .filename property")
   end)

   it("unknowns include filename", function ()
      local tokens = tl.lex("local x: string = b")
      local _, ast = tl.parse_program(tokens, {})
      local errors, unknowns = tl.type_check(ast, true, "foo.tl")
      assert.same("foo.tl", unknowns[1].filename, "unknowns should contain .filename property")
   end)

   it("unknowns in a required package include filename of required file", function ()
      local io_open = io.open
      io.open = function (filename, mode)
         if string.match(filename, "bar.tl$") then
            -- Return a stub file handle
            return {
               read = function (_, format)
                  if format == "*a" then
                     return "local x: string = b"        -- Return fake bar.tl content
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
      local errors, unknowns = tl.type_check(ast, true, "foo.tl")
      assert.is_not_nil(string.match(errors[1].filename, "bar.tl$"), "unknowns should contain .filename property")
   end)
end)
