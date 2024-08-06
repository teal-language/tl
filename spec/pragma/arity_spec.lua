local util = require("spec.util")

describe("pragma arity", function()
   describe("on", function()
      it("rejects function calls with missing arguments", util.check_type_error([[
         --#pragma arity on

         local function f(x: integer, y: integer)
            print(x + y)
         end

         print(f(10))
      ]], {
         { msg = "wrong number of arguments (given 1, expects 2)" }
      }))

      it("accepts optional arguments", util.check([[
         --#pragma arity on

         local function f(x: integer, y?: integer)
            print(x + (y or 20))
         end

         print(f(10))
      ]]))
   end)

   describe("off", function()
      it("accepts function calls with missing arguments", util.check([[
         --#pragma arity off

         local function f(x: integer, y: integer)
            print(x + (y or 20))
         end

         print(f(10))
      ]]))

      it("ignores optional argument annotations", util.check([[
         --#pragma arity off

         local function f(x: integer, y?: integer)
            print(x + y)
         end

         print(f(10))
      ]]))
   end)

   describe("no propagation from required module upwards:", function()
      it("on then off, with error in 'on'", function()
         util.mock_io(finally, {
            ["r.tl"] = [[
               --#pragma arity off
               local function f(x: integer, y: integer, z: integer)
                  print(x + (y or 20))
               end
               print(f(10))
            ]]
         })
         util.check_type_error([[
            --#pragma arity on

            local function f(x: integer, y: integer)
               print(x + y)
            end

            print(f(10))

            local r = require("r")

            local function g(x: integer, y: integer, z: integer, w: integer)
               print(x + y)
            end

            print(g(10, 20))
         ]], {
            { filename = "foo.tl", y = 7, msg = "wrong number of arguments (given 1, expects 2)" },
            { filename = "foo.tl", y = 15, msg = "wrong number of arguments (given 2, expects 4)" },
         })()
      end)

      it("on then on, with errors in both", function()
         util.mock_io(finally, {
            ["r.tl"] = [[
               --#pragma arity on
               local function f(x: integer, y: integer, z: integer)
                  print(x + (y or 20))
               end
               print(f(10))
            ]]
         })
         util.check_type_error([[
            --#pragma arity on

            local function f(x: integer, y: integer)
               print(x + y)
            end

            print(f(10))

            local r = require("r")

            local function g(x: integer, y: integer, z: integer, w: integer)
               print(x + y)
            end

            print(g(10, 20))
         ]], {
            { filename = "r.tl", y = 5, msg = "wrong number of arguments (given 1, expects 3)" },
            { filename = "foo.tl", y = 7, msg = "wrong number of arguments (given 1, expects 2)" },
            { filename = "foo.tl", y = 15, msg = "wrong number of arguments (given 2, expects 4)" },
         })()
      end)

      it("off then on, with error in 'on'", function()
         util.mock_io(finally, {
            ["r.tl"] = [[
               --#pragma arity on

               local function f(x: integer, y: integer)
                  print(x + y)
               end

               print(f(10))
            ]]
         })
         util.check_type_error([[
            --#pragma arity off

            local r = require("r")

            local function f(x: integer, y: integer)
               print(x + y)
            end

            print(f(10))
         ]], {
            { y = 7, filename = "r.tl", msg = "wrong number of arguments (given 1, expects 2)" }
         })()
      end)
   end)

   describe("does propagate downwards into required module:", function()
      it("can trigger errors in required modules", function()
         util.mock_io(finally, {
            ["r.tl"] = [[
               local function f(x: integer, y: integer, z: integer)
                  print(x + (y or 20))
               end
               print(f(10))

               return {
                  f = f
               }
            ]]
         })
         util.check_type_error([[
            --#pragma arity on

            local function f(x: integer, y: integer)
               print(x + y)
            end

            print(f(10))

            local r = require("r")

            local function g(x: integer, y: integer, z: integer, w: integer)
               print(x + y)
            end

            print(g(10, 20))

            r.f(10)
         ]], {
            { filename = "r.tl", y = 4, msg = "wrong number of arguments (given 1, expects 3)" },
            { filename = "foo.tl", y = 7, msg = "wrong number of arguments (given 1, expects 2)" },
            { filename = "foo.tl", y = 15, msg = "wrong number of arguments (given 2, expects 4)" },
            { filename = "foo.tl", y = 17, msg = "wrong number of arguments (given 1, expects 3)" },
         })()
      end)

      it("can be used to load modules with different settings", function()
         util.mock_io(finally, {
            ["r.tl"] = [[
               local function f(x: integer, y: integer, z: integer)
                  print(x + (y or 20))
               end
               print(f(10))

               return {
                  f = f
               }
            ]]
         })
         util.check_type_error([[
            --#pragma arity on

            local function f(x: integer, y: integer)
               print(x + y)
            end

            print(f(10))

            --#pragma arity off
            local r = require("r")
            --#pragma arity on

            local function g(x: integer, y: integer, z: integer, w: integer)
               print(x + y)
            end

            print(g(10, 20))

            r.f(10) -- no error here!
         ]], {
            { filename = "foo.tl", y = 7, msg = "wrong number of arguments (given 1, expects 2)" },
            { filename = "foo.tl", y = 17, msg = "wrong number of arguments (given 2, expects 4)" },
         })()
      end)
   end)

   describe("invalid", function()
      it("rejects invalid value", util.check_type_error([[
         --#pragma arity invalid_value

         local function f(x: integer, y?: integer)
            print(x + y)
         end

         print(f(10))
      ]], {
         { y = 1, msg = "invalid value for pragma 'arity': invalid_value" }
      }))
   end)
end)
