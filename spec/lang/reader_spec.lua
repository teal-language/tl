local reader = require("teal.reader")
local assert = require("luassert")

function strip_locations(t)
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

   it("parses a record type declaration", function()
      local input = [[
         local record Point
            x: number
            y: number
         end
      ]]
      local result = r(input)
      assert.same({}, result.errors)
      assert.is_not_nil(result.ast)
      if result.ast and result.ast[1] and result.ast[1][1] then
         assert.same("local_type", result.ast[1].kind)
         assert.same("record", result.ast[1][1].kind)
      end
   end)

   it("parses an enum type declaration", function()
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
      if result.ast and result.ast[1] and result.ast[1][1] then
         assert.same("local_type", result.ast[1].kind)
         assert.same("enum", result.ast[1][1].kind)
      end
   end)

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
end)
