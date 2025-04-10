local util = require("spec.util")

describe("string", function()

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
      it("can match with position captures", util.check([[
         local i1, s1: integer, string = string.match("hello world", "()w(o)rld")
      ]]))
   end)

   describe("find", function()
      it("can take an optional init position", util.check([[
         local a, b: integer, integer = string.find("hello world", "world")
         local a2, b2: integer, integer = string.find("hello world", "world", 2)
      ]]))
      it("accepts plain patterns", util.check([[
         local a, b: integer, integer = string.find("hello world", "wor[ld", 1, true)
      ]]))
      it("can find with position captures", util.check([[
         local a, b, i1, s1: integer, integer, integer, string = string.find("hello world", "()[()w](o)rld")
      ]]))
   end)

   describe("format", function()
      it("works with various specifiers", util.check([[
         local s1: string = string.format("%02A %a  %E %e %f %G %g %% %%", 1.1, 1.2, 1.3, 1.4, 1.4, 1.4, 1.4)
         local s2: string = string.format("%5c  %3d %i %o %u %X %x %% %%", 11, 12, 13, 14, 14, 14, 14)
         local s3: string = string.format('%s %s %s', 123, 123.5, "test")
         local s4: string = string.format('%p %p %p %p', {}, "test", 5, io.input())
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

      it("accepts a map with integers, returns a string and integer", util.check([[
         local s = "hello world"
         local map: {integer:string} = {
            [1] = "hola",
            [2] = "mundo",
         }
         local holamundo, count: string, integer = s:gsub("()", map)
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

      it("captures integer positions, returns a string", util.check([[
         local s = "hello world"
         local function f(a: integer, b: string): string
            return '[' .. a .. ']' .. b
         end
         local ret: string = s:gsub("()(%w+)", f)
      ]]))
   end)

end)
