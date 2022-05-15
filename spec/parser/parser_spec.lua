local tl = require("tl")

local function strip_typeids(t)
   local copy = {}
   for k,v in pairs(t) do
      if type(v) == "table" then
         copy[k] = strip_typeids(v)
      elseif k ~= "typeid" then
         copy[k] = v
      end
   end
   return copy
end

describe("parser", function()
   it("accepts an empty file (regression test for #43)", function ()
      local result = tl.process_string("")
      assert.same({}, result.syntax_errors)
      assert.same({
         kind = "statements",
         tk = "$EOF$",
         type = {
            typename = "none",
         },
         x = 1,
         y = 1,
         xend = 5,
         yend = 1,
      }, strip_typeids(result.ast))
   end)

   it("accepts 'return;' (regression test for #52)", function ()
      local result = tl.process_string("return;")
      assert.same({}, result.syntax_errors)
      assert.same(1, #result.ast)
      assert.same("return", result.ast[1].kind)
   end)

   it("accepts semicolons in tables (regression test for #54)", function ()
      local result = tl.process_string([[
         local t = {
            foo = "bar";
            foo = "baz";
         }
      ]])
      assert.same({}, result.syntax_errors)
      assert.same(1, #result.ast)
      assert.same("local_declaration", result.ast[1].kind)

      local result2 = tl.process_string([[
         local t = {
            foo = "bar",
            foo = "baz",
         }
      ]])
      assert.same({}, result2.syntax_errors)
      assert.same(1, #result2.ast)
      assert.same(strip_typeids(result.ast), strip_typeids(result2.ast))
   end)

   it("records the fact that a table item has implicit key", function ()
      local result = tl.process_string("return { ... }")
      assert.same({}, result.syntax_errors)
      assert.same("statements", result.ast.kind)
      assert.same("return", result.ast[1].kind)
      assert.same("table_literal", result.ast[1].exps[1].kind)
      assert.same("table_item", result.ast[1].exps[1][1].kind)
      assert.same("implicit", result.ast[1].exps[1][1].key_parsed)
   end)
end)
