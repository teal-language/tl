local util = require("spec.util")

describe("union declaration", function()
   it("declares a union", util.check([[
      local t: number | string
   ]]))

   it("declares a long union", util.check([[
      local t: number | string | boolean | function(number | string, {string | boolean}):{number | string:string | boolean}
   ]]))

   it("unions can be parethesized for readability", util.check([[
      -- with parentheses
      local params1: {string: (string | {string})}
      params1 = { key1 = 'val2', key2 = {'val2', 'val3'}}

      -- without parentheses
      local params2: {string: string | {string}}
      params2 = { key1 = 'val2', key2 = {'val2', 'val3'}}

      -- with extra parentheses
      local params3: {string: ((((string | {string}))))}
      params3 = { key1 = 'val2', key2 = {'val2', 'val3'}}
   ]]))

   it("unions can be declared nominally", util.check([[
      -- with parentheses
      local type P1 = (string | {string})
      local params1: {string:P1} = { key1 = 'val2', key2 = {'val2', 'val3'}}

      -- without parentheses
      local type P2 = string | {string}
      local params2: {string:P2} = { key1 = 'val2', key2 = {'val2', 'val3'}}

      -- with extra parentheses
      local type P3 = ((((string | {string}))))
      local params3: {string:P3} = { key1 = 'val2', key2 = {'val2', 'val3'}}
   ]]))

   it("can declare a union between number and integer", util.check([[
      local t: number | integer
      local u: number | string

      local function takes_integer(i: integer)
         print(i)
      end

      if t is integer then
         takes_integer(t)
      else
         u = t
      end
   ]]))

   it("cannot declare a union with an unknown type", util.check_type_error([[
      local function f(a: number | unknown_t)
      end
   ]], {
      { msg = "unknown type unknown_t" },
   }))

   it("cannot declare a union between multiple table types", util.check_type_error([[
      local t: number | {number} | {string:boolean}
   ]], {
      { msg = "cannot discriminate a union between multiple table types" },
   }))

   it("cannot declare a union between multiple tuple types", util.check_type_error([[
      local t: {number, number} | {string, number}
   ]], {
      { msg = "cannot discriminate a union between multiple table types" },
   }))

   it("cannot declare a union between multiple userdata types", util.check_type_error([[
      local record R1
         userdata
      end

      local record R2
         userdata
      end

      local t: R1 | R2
   ]], {
      { msg = "cannot discriminate a union between multiple userdata types" },
   }))

   it("can declare a union between one table and one userdata type", util.check([[
      local record R1
         userdata
      end

      local record R2
         x: number
      end

      local t: R1 | R2 | number
   ]]))

   it("cannot declare a union between multiple records", util.check_type_error([[
      local type R1 = record
         f: string
      end
      local type R2 = record
         g: string
      end
      local t: R1 | R2
   ]], {
      { msg = "cannot discriminate a union between multiple table types" },
   }))

   it("cannot declare a union between multiple userdata", util.check_type_error([[
      local record R
         is userdata
      end
      local t: userdata | R
   ]], {
      { msg = "cannot discriminate a union between multiple userdata types" },
   }))

   it("cannot declare a union between multiple records indirectly (#290)", util.check_type_error([[
      local record R<A, B>
         x: A | B
      end

      local r: R<number, string> = {}
      r.x = 1
      r.x = "hello"

      local oops: R<{number}, {string}> = {}
      oops.x = {1, 2, 3}
      oops.x = {"hello", "world"}
   ]], {
      { y = 9, msg = "cannot discriminate a union between multiple table types" },
   }))

   it("cannot declare a union between multiple records in a function in a field (#845)", util.check_type_error([[
      local record A<T>
         a: T
      end

      local record B<T>
         b: T
      end

      local record C<T>
         f: function<T>(A<T> | B<T>)
      end
   ]], {
      { y = 10, msg = "cannot discriminate a union between multiple table types" },
   }))

   it("cannot declare a union between multiple function types", util.check_type_error([[
      local t: function():(number) | function():(string)
   ]], {
      { msg = "cannot discriminate a union between multiple function types" },
   }))

   it("cannot declare a union between multiple function types", util.check_type_error([[
      local type F1 = function(): number
      local type F2 = function(): string
      local t: F1|F2
   ]], {
      { msg = "cannot discriminate a union between multiple function types" },
   }))

   it("collapses multiple emptytables on declaration", util.check([[
      local function count_sea_monsters(image: {string})
         local c, m, n = 0, {{}, {}}, 0
         for row = 1, #image - 2 do
            m[row + 2] = {}
         end
      end
   ]]))

   it("do not try to resolve validity of unions too early (regression test for #903)", util.check([[
      local interface A
         where true
      end

      local record D
         v: A | C
      end

      local interface C
         where true
      end

      local d: D

      local v = d.v
      if v is A then
      end
   ]]))

end)
