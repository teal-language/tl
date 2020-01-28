local tl = require("tl")
local util = require("spec.util")

local function unindent(code)
   return code:gsub("[ \t]+", " "):gsub("\n[ \t]+", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
end

describe("record method", function()
   it("valid declaration", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            if self.b then
               return #b == 3
            else
               return a > self.x
            end
         end
         local ok = r:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("nested declaration", function()
      local tokens = tl.lex([[
         local r = {
            z = {
               x = 2,
               b = true,
            },
         }
         function r.z:f(a: number, b: string): boolean
            if self.b then
               return #b == 3
            else
               return a > self.x
            end
         end
         local ok = r.z:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("nested declaration in {}", function()
      local tokens = tl.lex([[
         local r = {
            z = {},
         }
         function r.z:f(a: number, b: string): boolean
            return true
         end
         local ok = r.z:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("deep nested declaration", function()
      local tokens = tl.lex([[
         local r = {
            a = {
               b = {
                  x = true
               }
            },
         }
         function r.a.b:f(a: number, b: string): boolean
            return self.x
         end
         local ok = r.a.b:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("resolves self", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.invalid
         end
         local ok = r:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("invalid key 'invalid' in record 'self'", errors[1].msg, 1, true)
   end)

   it("resolves self but does not output it as an argument (#27)", function()
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local r = {
               x = 2,
               b = true,
            }
            function r:f(a: number, b: string): boolean
               return self.invalid
            end
            function r:g()
               return
            end
            local ok = r:f(3, "abc")
         ]],
      })
      local result, err = tl.process("foo.tl")
      local output = tl.pretty_print_ast(result.ast)
      assert.same(unindent[[
         local r = {
            ["x"] = 2,
            ["b"] = true,
         }
         function r:f(a, b)
            return self.invalid
         end
         function r:g()
            return
         end
         local ok = r:f(3, "abc")
      ]], unindent(output))
   end)

   it("catches invocation style", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.b
         end
         local ok = r.f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("invoked method as a regular function", errors[1].msg, 1, true)
   end)

   it("allows invocation when properly used with '.'", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.b
         end
         local ok = r.f(r, 3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("allows invocation when properly used with ':'", function()
      local tokens = tl.lex([[
         local r = {
            x = 2,
            b = true,
         }
         function r:f(a: number, b: string): boolean
            return self.b
         end
         local ok = r:f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
