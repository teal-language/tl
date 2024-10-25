local util = require("spec.util")

describe("function call", function()
   describe("results", function()
      it("should be adjusted down to 1 result in an expression list", util.check([[
         local function f(): string, number
         end
         local a, b = f(), "hi"
         a = "hey"
      ]]))

      it("can resolve type arguments based on expected type at use site (#512)", util.check([[
         local function get_foos<T>():{T}
            return {}
         end

         local foos:{integer} = get_foos()
         print(foos)
      ]]))
   end)

   describe("arguments", function()
      it("type variables from returns resolve for arguments (regression test for #838)", util.check([[
         local fcts: {integer:function(val: any, opt?: string): any}

         local function bar (val: number): number
            print(val)
            return val
         end

         local function bar2 (val: number, val2: string): number
            print(val, val2)
            return val
         end

         fcts = {  -- OK, with table constructor
            [11] = function (val: string): string
               print(val)
               return val
            end,
            [12] = function (val: string, val2: string): string
               print(val, val2)
               return val
            end,
            [21] = bar,
            [22] = bar2,
         }
         setmetatable(fcts, {
            __tostring = function(): string return 'fcts' end
         })

         fcts = setmetatable({  -- Ok, as an argument via type variable
            [11] = function (val: string): string
               print(val)
               return val
            end,
            [12] = function (val: string, val2: string): string
               print(val, val2)
               return val
            end,
            [21] = bar,
            [22] = bar2,
         }, {
            __tostring = function(): string return 'fcts' end
         })

         print(fcts)
      ]]))
   end)
end)
