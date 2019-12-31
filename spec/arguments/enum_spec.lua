local tl = require("tl")

describe("enum argument", function()
   it("accepts a valid string", function()
      local tokens = tl.lex([[
         local Direction = enum
            "north"
            "south"
            "east"
            "west"
         end

         local function go(d: Direction)
            print("I am going " .. d .. "!") -- d works as a string!
         end

         go("west")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("rejects an invalid string", function()
      local tokens = tl.lex([[
         local Direction = enum
            "north"
            "south"
            "east"
            "west"
         end

         local function go(d: Direction)
            print("I am going " .. d .. "!") -- d works as a string!
         end

         go("rest")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("string \"rest\" is not a member of Direction", errors[1].msg)
   end)
end)
