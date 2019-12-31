local tl = require("tl")

describe("empty table without type annotation", function()
   it("has its type determined by its first use", function()
      local tokens = tl.lex([[
         local t = {}
         for i = 1, 10 do
            t[i] = i * 10
         end

         t.foo = "bar"
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.match("cannot index something that is not a record: {number}", errors[1].msg, 1, true)
   end)

   it("has its type determined by its first reassignment", function()
      local tokens = tl.lex([[
         local function return_arr(): {number}
            local t = {}
            local arr = {1,2,3}
            if 2 < 3 then
               t = arr
            end
            return t
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.same({}, errors)
   end)

   it("cannot be reassigned to a non-table", function()
      local tokens = tl.lex([[
         local function return_arr(): {number}
            local t = {}
            local arr = {1,2,3}
            if 2 < 3 then
               t = 12
            end
            return t
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.match("assigning number to a variable declared with {}", errors[1].msg, 1, true)
   end)

   it("preserves provenance information", function()
      local tokens = tl.lex([[
         local function return_arr(): {number}
            local t = {}
            local arr = {1,2,3}
            if 2 < 3 then
               t = arr
            end
            t.foo = "bar"
            return t
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.match("cannot index something that is not a record: {number} (inferred at test.lua:5:", errors[1].msg, 1, true)
   end)
end)
