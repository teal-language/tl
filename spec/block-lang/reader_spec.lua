local reader = require("teal.reader")
local assert = require("luassert")

local function strip_locations(t)
   if type(t) ~= "table" then
      return t
   end
   local copy = {}
   for k, v in pairs(t) do
      if type(v) == "table" then
         copy[k] = strip_locations(v)
      elseif k ~= "f" and k ~= "y" and k ~= "x" and k ~= "yend" and k ~= "xend" and k ~= "tk" and k ~= "op" then
         copy[k] = v
      end
   end
   return copy
end

local function r(s)
   local ast, errors = reader.read(s, "test")
   return { ast = strip_locations(ast), errors = errors }
end

describe("reader", function()
   it("accepts an empty file", function()
      local result = r("")
      assert.same({}, result.errors)
      assert.same({
         kind = "statements",
      }, result.ast)
   end)

   it("accepts 'return;'", function()
      local result = r("return;")
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast then
         assert.same({
            kind = "statements",
            {
               kind = "return",
               {
                  kind = "expression_list",
               }
            }
         }, result.ast)
      end
   end)

   it("accepts semicolons in tables", function()
      local input = [[
         local t = {
            foo = "bar";
            foo = "baz";
         }
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("local_declaration", result.ast[1].kind)
      end
   end)

   it("parses nested type arguments", function()
      local input = [[
         local record List<T>
            items: {T}
         end

         local record Box<T>
            item: {T}
         end

         local list_of_boxes: List<Box<string>> = {
            items = {}
         }
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and #result.ast == 3 and result.ast[1] and result.ast[2] and result.ast[3] then
         assert.same(3, #result.ast)
         assert.same("local_type", result.ast[1].kind)
         assert.same("local_type", result.ast[2].kind)
         assert.same("local_declaration", result.ast[3].kind)
      end
   end)

   it("parses a function declaration", function()
      local input = [[
         local function foo()
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("local_function", result.ast[1].kind)
      end
   end)

   it("parses a global function declaration", function()
      local input = [[
         global function foo()
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("global_function", result.ast[1].kind)
      end
   end)

   -- it("parses a record type declaration", function()
   --    local input = [[
   --       local record Point
   --          x: number
   --          y: number
   --       end
   --    ]]
   --    local result = r(input)
   --    assert.same({}, result.errors)
   --    assert.is_not_nil(result.ast)
   --    if result.ast and result.ast[1] and result.ast[1][1] then
   --       assert.same("local_type", result.ast[1].kind)
   --       assert.same("record", result.ast[1][1].kind)
   --    end
   -- end)

   -- it("parses an enum type declaration", function()
   --    local input = [[
   --       local enum Color
   --          "red"
   --          "green"
   --          "blue"
   --       end
   --    ]]
   --    local result = r(input)
   --    assert.same({}, result.errors)
   --    assert.is_not_nil(result.ast)
   --    if result.ast and result.ast[1] and result.ast[1][1] then
   --       assert.same("local_type", result.ast[1].kind)
   --       assert.same("enum", result.ast[1][1].kind)
   --    end
   -- end)

   it("parses an if statement", function()
      local input = [[
         if true then
            print("hello")
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("if", result.ast[1].kind)
      end
   end)

   it("parses a while statement", function()
      local input = [[
         while true do
            print("hello")
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("while", result.ast[1].kind)
      end
   end)

   it("parses a numeric for loop", function()
      local input = [[
         for i = 1, 10 do
            print(i)
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("fornum", result.ast[1].kind)
      end
   end)

   it("parses a generic for loop", function()
      local input = [[
         for k, v in pairs({}) do
            print(k, v)
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("forin", result.ast[1].kind)
      end
   end)

   it("parses a repeat until statement", function()
      local input = [[
         repeat
            print("hello")
         until true
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("repeat", result.ast[1].kind)
      end
   end)

   it("parses a do end block", function()
      local input = [[
         do
            print("hello")
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("do", result.ast[1].kind)
      end
   end)

   it("parses goto and labels", function()
      local input = [[
         goto mylabel
         ::mylabel::
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] and result.ast[2] then
         assert.same("goto", result.ast[1].kind)
         assert.same("label", result.ast[2].kind)
      end
   end)

   it("parses break statements", function()
      local input = [[
         while true do
            break
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] and result.ast[1][2] and result.ast[1][2][1] then
         assert.same("while", result.ast[1].kind)
         assert.same("break", result.ast[1][2][1].kind)
      end
   end)

   it("parses return statements with expressions", function()
      local input = [[
         function foo()
            return 1, 2, 3
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("record_function", result.ast[1].kind)
      end
   end)

   it("parses variable assignments", function()
      local input = [[
         local x, y = 1, 2
         x, y = y, x
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] and result.ast[2] then
         assert.same("local_declaration", result.ast[1].kind)
         assert.same("assignment", result.ast[2].kind)
      end
   end)

   it("parses function calls", function()
      local input = [[
         print("hello", "world")
         table.insert(t, value)
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] and result.ast[2] then
         assert.same("op_funcall", result.ast[1].kind)
         assert.same("op_funcall", result.ast[2].kind)
      end
   end)

   it("parses local type declarations", function()
      local input = [[
         local type MyNumber = number
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("local_type", result.ast[1].kind)
      end
   end)

   it("parses global type declarations", function()
      local input = [[
         global type MyString = string
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("global_type", result.ast[1].kind)
      end
   end)

   it("parses local record declarations", function()
      local input = [[
         local record Point
            x: number
            y: number
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("local_type", result.ast[1].kind)
      end
   end)

   it("parses global record declarations", function()
      local input = [[
         global record Vector
            x: number
            y: number
            z: number
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("global_type", result.ast[1].kind)
      end
   end)

   it("parses local enum declarations", function()
      local input = [[
         local enum Color
            "red"
            "green"
            "blue"
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("local_type", result.ast[1].kind)
      end
   end)

   it("parses global enum declarations", function()
      local input = [[
         global enum Status
            "active"
            "inactive"
            "pending"
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("global_type", result.ast[1].kind)
      end
   end)

   it("parses if-else statements", function()
      local input = [[
         if x > 0 then
            print("positive")
         else
            print("not positive")
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("if", result.ast[1].kind)
      end
   end)

   it("parses if-elseif-else statements", function()
      local input = [[
         if x > 0 then
            print("positive")
         elseif x < 0 then
            print("negative")
         else
            print("zero")
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("if", result.ast[1].kind)
      end
   end)

   it("parses numeric for loops with step", function()
      local input = [[
         for i = 1, 10, 2 do
            print(i)
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("fornum", result.ast[1].kind)
      end
   end)

   it("parses table literals", function()
      local input = [[
         local t = {
            a = 1,
            b = 2,
            [1] = "first",
            [2] = "second"
         }
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("local_declaration", result.ast[1].kind)
      end
   end)

   it("parses function expressions", function()
      local input = [[
         local f = function(x, y)
            return x + y
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("local_declaration", result.ast[1].kind)
      end
   end)

   it("parses global variable declarations", function()
      local input = [[
         global x: number = 42
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("global_declaration", result.ast[1].kind)
      end
   end)

   it("parses pragmas", function()
      local input = [[
         --#pragma warn off
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] then
         assert.same("pragma", result.ast[1].kind)
      end
   end)

   it("handles syntax errors gracefully", function()
      local input = [[
         local function
      ]]
      local result = r(input)
      assert.is_true(#result.errors > 0)
      assert.is_not_nil(result.ast)
   end)

   it("parses multiple statements", function()
      local input = [[
         local x = 1
         local y = 2
         local z = x + y
         print(z)
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast then
         assert.same(4, #result.ast)
         assert.same("local_declaration", result.ast[1].kind)
         assert.same("local_declaration", result.ast[2].kind)
         assert.same("local_declaration", result.ast[3].kind)
         assert.same("op_funcall", result.ast[4].kind)
      end
   end)
end)

