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
      it("works with locals", util.check([[
         local myfinder = ("test").find
         local a, b, i1, s1: integer, integer, integer, string = myfinder("hello world", "()[()w](o)rld")
      ]]))
   end)

   describe("format", function()
      it("doesn't break inference (#975)", util.check([[
         local function do_the_test(y ?: integer)
            string.format('%d', y)
            string.format('%d', y or 0) -- shouldn't error
         end
      ]]))
      it("works with various specifiers", util.check([[
         local sfmt = string.format
         local s1: string = sfmt("%02A %a  %E %e %f %G %g %% %%", 1.1, 1.2, 1.3, 1.4, 1.4, 1.4, 1.4)
         local s2: string = sfmt("%5c  %3d %i %o %u %X %x %% %%", 11, 12, 13, 14, 14, 14, 14)
         local s3: string = sfmt('%s %s %s', 123, 123.5, "test")
         local s4: string = sfmt('%p %p %p %p', {}, "test", 5, io.input())
      ]]))
      it("fails with bad specifiers", util.check_type_error([[
         local sfmt = string.format
         local s1: string = sfmt("%e", "test")
         local s2: string = sfmt("%5c", 10.5)
      ]], {
         {
            msg = "argument 2: got string \"test\", expected number",
            y = 2,
         },
         {
            msg = "argument 2: got number, expected integer",
            y = 3,
         }
      }))
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
         local helloword, count: string, integer = s:gsub("()", "%1", 6)
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

      it("fails with unclosed patterns", util.check_type_error([[
         local a = ("test"):gsub("(", "")
         local b = ("test"):gsub("%", "")
         local c = ("test"):gsub(")(", "")
         local d = ("test"):gsub("%f[", "")
      ]], {
         {
            msg = "malformed pattern: 1 capture not closed",
            y = 1,
         },
         {
            msg = "malformed pattern: expected class",
            y = 2,
         },
         {
            msg = "malformed pattern: unexpected ')'",
            y = 3,
         },
         {
            msg = "malformed pattern: missing ']'",
            y = 4,
         },
      }))
   end)


   describe("pack", function()
      it("works with types", util.check([[
         local packed: string = string.pack("<!7XdLfz", 12345, 5.2, "testing")
         local a, b, c, next: integer, number, string, integer = string.unpack("<!7XdLfz", packed)
      ]]))
      it("errors with invalid types or arguments", util.check_type_error([[
         local packed: string = string.pack("<!7L", 4.5)
         local packed2: string = string.pack("<!7Xdf", "testing")
         local packed3: string = string.pack("<!7z", 5)
         local packed4: string = string.pack("", "test")
      ]], {
         {
            msg = "argument 2: got number, expected integer",
            y = 1,
         },
         {
            msg = "argument 2: got string \"testing\", expected number",
            y = 2,
         },
         {
            msg = "argument 2: got integer, expected string",
            y = 3,
         },
         {
            msg = "wrong number of arguments",
            y = 4,
         },
      }))
      it("works with constant strings", util.check([[
         -- <const> is required so that it gets recognised as a constant for string.pack and unpack
         local pstr <const> = "<!7XdLfz"
         local packed: string = string.pack(pstr, 12345, 5.2, "testing")
         local a, b, c, next: integer, number, string, integer = pstr:unpack(packed)
      ]]))
   end)
end)
