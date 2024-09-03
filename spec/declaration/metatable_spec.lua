local util = require("spec.util")

describe("metatable declaration", function()
   it("checks metamethod declarations in record against a general contract", util.check_type_error([[
      local type Rec = record
         n: integer
         metamethod __sub: function(self: Rec, b: integer, wat: integer): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __add = function(self: Rec, b: Rec): Rec
            return { n = self.n + b.n }
         end,
      }

      local r: Rec = setmetatable({ n = 10 }, rec_mt)
      print((r - 3).n)
   ]], {
      { y = 3, x = 28, msg = "__sub does not follow metatable contract: got function(Rec, integer, integer): Rec, expected function<A, B, C>(A, B): C" },
      { y = 14, x = 16, msg = "wrong number of arguments" },
   }))

   it("checks metatable against metamethod declarations", util.check_type_error([[
      local type Rec = record
         n: integer
         metamethod __add: function(self: Rec, b: integer): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __add = function(self: Rec, b: Rec): Rec
            return { n = self.n + b.n }
         end,
      }

      local r: Rec = setmetatable({ n = 10 }, rec_mt)
      print((r + 9).n)
      print((9 + r).n)
   ]], {
      { y = 8, x = 41, msg = "in record field: __add: argument 2: got Rec, expected integer" },
      { y = 15, x = 14, msg = "argument 1: got integer, expected Rec" },
   }))

   it("checks non-method metamethods with self in any position", util.check_type_error([[
      local type Rec = record
         n: integer
         metamethod __mul: function(a: integer, b: Rec): integer
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __mul = function(a: integer, b: Rec): integer
            return a * b.n
         end,
      }

      local r: Rec = setmetatable({ n = 10 }, rec_mt)
      print((9 * r) + 3.0)
      print((r * 9) + 3.0)
   ]], {
      { y = 15, x = 14, msg = "argument 1: got Rec, expected integer" },
   }))

   it("checks metamethods with multiple entries of the type", util.check_type_error([[
      local type Rec = record
         n: integer
         metamethod __div: function(a: Rec, b: Rec): integer
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __div = function(a: Rec, b: Rec): integer
            return a.n // b.n
         end,
      }

      local r: Rec = setmetatable({ n = 10 }, rec_mt)
      print((r / 9) + 3.0)
      print((r / r) + 3.0)
   ]], {
      { y = 14, x = 18, msg = "argument 2: got integer, expected Rec" },
   }))

   it("checks metamethods with method-like self", util.check_type_error([[
      local type Rec = record
         n: integer
         metamethod __index: function(Rec, s: string): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __index = function(self: Rec, k: string): Rec
            return { n = #k }
         end,
      }

      local r: Rec = setmetatable({ n = 10 }, rec_mt)
      print(r["hello"])
      print(r[true])
   ]], {
      { y = 15, x = 15, msg = "argument 1: got boolean, expected string" },
   }))

   it("checks metamethods with method-like self (explicit self)", util.check_type_error([[
      local type Rec = record
         n: integer
         metamethod __index: function(self: Rec, s: string): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __index = function(r: Rec, k: string): Rec
            return { n = #k }
         end,
      }

      local r: Rec = setmetatable({ n = 10 }, rec_mt)
      print(r["hello"])
      print(r[true])
   ]], {
      { y = 15, x = 15, msg = "argument 1: got boolean, expected string" },
   }))

   it("checks metamethods with method-like self (other name)", util.check_type_error([[
      local type Rec = record
         n: integer
         metamethod __index: function(r: Rec, s: string): Rec
      end

      local rec_mt: metatable<Rec>
      rec_mt = {
         __index = function(r: Rec, k: string): Rec
            return { n = #k }
         end,
      }

      local r: Rec = setmetatable({ n = 10 }, rec_mt)
      print(r["hello"])
      print(r[true])
   ]], {
      { y = 15, x = 15, msg = "argument 1: got boolean, expected string" },
   }))

end)
