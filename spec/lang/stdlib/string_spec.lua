local util = require("spec.util")

describe("string", function()
   describe("literal", function()
      it("doesn't care about local string", util.check([[
         local string = "text"
         print(("%i"):format(42))
      ]]))
   end)

   describe("byte", function()
      it("can return multiple values", util.check([[
         local n1, n2 = ("hello"):byte(1, 2)
         print(n1 + n2)
      ]]))
   end)

   describe("char", function()
      it("can take multiple inputs", util.check([[
         print(string.char(104, 101, 108, 108, 111) .. "!")
      ]]))
   end)

   describe("match", function()
      it("can take an optional init position", util.check([[
         local s1: string = string.match("hello world", "world")
         local s2: string = string.match("hello world", "world", 2)
      ]]))
   end)

   describe("gsub", function()
      it("accepts a string, returns a string", util.check([[
         local s = "hello"
         local hi: string = s:gsub("ello", "i")
      ]]))

      it("accepts a string, returns a string and integer", util.check([[
         local s = "hello world"
         local wordword, count: string, integer = s:gsub("%w+", "word")
      ]]))

      it("accepts a string and integer, returns a string and integer", util.check([[
         local s = "hello world"
         local helloword, count: string, integer = s:gsub("%w+", "word", 6)
      ]]))

      it("accepts a map, returns a string and integer", util.check([[
         local s = "hello world"
         local map = {
            ["hello"] = "hola",
            ["world"] = "mundo",
         }
         local holamundo, count: string, integer = s:gsub("%w+", map)
      ]]))

      it("accepts a map and integer, returns a string and integer", util.check([[
         local s = "hello world"
         local map = {
            ["hello"] = "hola",
            ["world"] = "mundo",
         }
         local hellomundo, count: string, integer = s:gsub("%w+", map, 6)
      ]]))

      it("accepts a function to strings, returns a string", util.check([[
         local s = "hello world"
         local function f(x: string): string
            return x:upper()
         end
         local ret: string = s:gsub("%w+", f)
      ]]))

      it("accepts a function to integers, returns a string", util.check([[
         local s = "hello world"
         local function f(x: string): integer
            return #x
         end
         local ret: string = s:gsub("%w+", f)
      ]]))

      it("accepts a function to numbers, returns a string", util.check([[
         local s = "hello world"
         local function f(x: string): number
            return #x * 1.5
         end
         local ret: string = s:gsub("%w+", f)
      ]]))

      it("accepts a function that returns nothing", util.check([[
         local function parse_integers(s: string, i0: integer) : {integer}
             local t, p = {}, i0 or 1
             local function f(x: string)
                 t[p] = math.tointeger(x)
                 p = p + 1
             end
             s:gsub("[-%d]+", f)
             return t
         end
      ]]))
   end)

end)
