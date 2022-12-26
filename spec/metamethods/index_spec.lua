local util = require("spec.util")

describe("metamethod __index", function()
   it("can be set on a record", util.check [[
      local type Rec = record
         x: number
         metamethod __index: function(Rec, string): string
      end

      local rec_mt: metatable<Rec> = {
         __index = function(self: Rec, s: string, n: number): string
            return tostring(self.x + n) .. s
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r["!!!"])
   ]])

   it("can be used on a record prototype", util.check [[
      local record A
         value: number
         metamethod __index: function(A, number): A
      end
      local A_mt: metatable<A>
      A_mt = {
         __index = function(a: A, v: number): A
            return setmetatable({value = v} as A, A_mt)
         end
      }

      local inst = A[2]
      print(inst.value)
   ]])

   it("can type check arguments", util.check_type_error([[
      local type Rec = record
         x: number
         metamethod __index: function(Rec, number): string
      end

      local rec_mt: metatable<Rec> = {
         __index = function(self: Rec, n: number): string
            return tostring(self.x + n)
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r[r])
   ]], {
      { msg = "argument 2: got Rec, expected number" },
   }))

   it("cannot be typechecked if the metamethod is not defined in the record", util.check_type_error([[
      local type Rec = record
         x: number
      end

      local rec_mt: metatable<Rec> = {
         __index = function(self: Rec, s: string): string
            return tostring(self.x) .. s
         end
      }

      -- this is not sufficient to tell the compiler that r supports __index,
      -- because setmetatable is a dynamic operation.
      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r["!!!"])
   ]], {
      { msg = "invalid key '!!!' in record 'r' of type Rec" }
   }))

   it("can use the record prototype in setmetatable and types flow through correctly", util.check [[
      local record mymod
        metamethod __index: function(mymod, string): string
      end

      function mymod.myfunc(s: string):string
         return "Hello, " .. s .. "!"
      end

      return setmetatable(mymod, {
        __index = function(_: mymod, s: string): string
          return mymod.myfunc(s)
        end
      })
   ]])

   it("can use nested record prototypes in setmetatable and types flow through correctly", util.check [[
      local record Rec
         record Type
            x: number
            y: number
            metamethod __index: function(Rec.Type, string): number
         end
         metamethod __call: function(Rec, number, number): Rec.Type
      end

      local Rec_instance_mt = {
         __index = function(self: Rec.Type, v: string): number
            if v == "X" then
               return self.x
            else
               return self.y
            end
         end
      }

      local Rec_class_mt = {
         __call = function(_: Rec, x, y): Rec.Type
            return setmetatable({ x = x, y = y } as Rec.Type, Rec_instance_mt)
         end
      }

      setmetatable(Rec, Rec_class_mt)

      local a = Rec(10, 20)
      local b = Rec(1, 2)
      print(a["X"] + b["Y"])

      local function f(_t: Rec)
      end

      f(Rec)
   ]])

   it("can simulate reading a map using __index", util.check [[
      local record R
         metamethod __index: function(R, string): number
         foo: string
         bar: boolean
      end

      local r: R = {}
      r.foo = "hello"
      r.bar = true
      print(123 + r["wat"] + r["yep"]) -- these get resolved by __index
      print(123 + r.wat + r.hello) -- these get resolved by __index too
   ]])

   -- this is failing because the definition and implementations are not being cross-checked
   -- this causes the test to output an error on line 15, because the call doesn't match the
   -- metamethod definition inside Rec.
   pending("record definition and implementations must match their types", util.check_type_error([[
      local type Rec = record
         x: number
         metamethod __index: function(Rec, number): string
      end

      local rec_mt: metatable<Rec> = {
         __index = function(self: Rec, s: string): string
            return tostring(self.x) .. s
         end
      }

      local r = setmetatable({} as Rec, rec_mt)

      r.x = 12
      print(r["!!!"])
   ]], {
      { y = 7, msg = "in assignment: argument 2: got string, expected number" }
   }))
end)
