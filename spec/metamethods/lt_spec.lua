local util = require("spec.util")

describe("binary metamethod __lt using <", function()
   it("can be set on a record", util.check([[
      local type Rec = record
         x: number
         metamethod __call: function(Rec, string, number): string
         metamethod __lt: function(Rec, Rec): boolean
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __call = function(self: Rec, s: string, n: number): string
            return tostring(self.x + n) .. s
         end,
         __lt = function(a: Rec, b: Rec): boolean
            return a.x < b.x
         end
      }

      local r = setmetatable({ x = 10 } as Rec, rec_mt)
      local s = setmetatable({ x = 20 } as Rec, rec_mt)

      if r < s then
         print("yes")
      end
   ]]))

   it("can be used on a record prototype", util.check([[
      local record A
         value: number
         metamethod __call: function(A, number): A
         metamethod __lt: function(A, A): boolean
      end
      local A_mt: metatable<A>
      A_mt = {
         __call = function(a: A, v: number): A
            return setmetatable({value = v} as A, A_mt)
         end,
         __lt = function(a: A, b: A): boolean
            return a.value < b.value
         end,
      }

      A.value = 10
      if A < A then
         print("wat!?")
      end
   ]]))

   it("can be used via the second argument", util.check([[
      local type Rec = record
         x: number
         metamethod __lt: function(number, Rec): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __lt = function(a: number, b: Rec): boolean
            return a < b.x
         end
      }

      local s = setmetatable({ y = 20 } as Rec, rec_mt)

      if 10 < s then
         print("yes")
      end
   ]]))

   it("preserves nominal type checking when resolving metamethods for operators", util.check_type_error([[
      local type Temperature = record
         n: number
         metamethod __lt: function(t1: Temperature, t2: Temperature): boolean
      end

      local type Date = record
         n: number
         metamethod __lt: function(t1: Date, t2: Date): boolean
      end

      local temp2: Temperature = { n = 45 }
      local birthday2 : Date = { n = 34 }

      setmetatable(temp2, {
         __lt = function(t1: Temperature, t2: Temperature): boolean
            return t1.n < t2.n
         end,
      })

      setmetatable(birthday2, {
         __lt = function(t1: Date, t2: Date): boolean
            return t1.n < t2.n
         end,
      })

      if temp2 < birthday2 then
         print("wat")
      end
   ]], {
      { y = 26, msg = "Date is not a Temperature" },
   }))
end)

describe("binary metamethod __lt using >", function()
   it("can be set on a record", util.check([[
      local type Rec = record
         x: number
         metamethod __call: function(Rec, string, number): string
         metamethod __lt: function(Rec, Rec): boolean
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __call = function(self: Rec, s: string, n: number): string
            return tostring(self.x + n) .. s
         end,
         __lt = function(a: Rec, b: Rec): boolean
            return a.x < b.x
         end
      }

      local r = setmetatable({ x = 10 } as Rec, rec_mt)
      local s = setmetatable({ x = 20 } as Rec, rec_mt)

      if s > r then
         print("yes")
      end
   ]]))

   it("can be used on a record prototype", util.check([[
      local record A
         value: number
         metamethod __call: function(A, number): A
         metamethod __lt: function(A, A): boolean
      end
      local A_mt: metatable<A>
      A_mt = {
         __call = function(a: A, v: number): A
            return setmetatable({value = v} as A, A_mt)
         end,
         __lt = function(a: A, b: A): boolean
            return a.value < b.value
         end,
      }

      A.value = 10
      if A > A then
         print("wat!?")
      end
   ]]))

   it("can be used via the second argument", util.check([[
      local type Rec = record
         x: number
         metamethod __lt: function(number, Rec): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __lt = function(a: number, b: Rec): boolean
            return a < b.x
         end
      }

      local s = setmetatable({ y = 20 } as Rec, rec_mt)

      if s > 10 then
         print("yes")
      end
   ]]))

   it("preserves nominal type checking when resolving metamethods for operators", util.check_type_error([[
      local type Temperature = record
         n: number
         metamethod __lt: function(t1: Temperature, t2: Temperature): boolean
      end

      local type Date = record
         n: number
         metamethod __lt: function(t1: Date, t2: Date): boolean
      end

      local temp2: Temperature = { n = 45 }
      local birthday2 : Date = { n = 34 }

      setmetatable(temp2, {
         __lt = function(t1: Temperature, t2: Temperature): boolean
            return t1.n < t2.n
         end,
      })

      setmetatable(birthday2, {
         __lt = function(t1: Date, t2: Date): boolean
            return t1.n < t2.n
         end,
      })

      if birthday2 > temp2 then
         print("wat")
      end
   ]], {
      { y = 26, msg = "Date is not a Temperature" },
   }))
end)
