local util = require("spec.util")

describe("array argument", function()
   it("catches error in array elements", util.check_type_error([[
      local function a(arg: {string})
         print(arg)
      end

      local function main()
         a({"a", 100})
         a(100)
      end
   ]], {
      { y = 6, msg = 'expected an array: at index 2: got integer, expected string' },
      { y = 7, msg = 'argument 1: got integer, expected {string}' },
   }))

   it("constructs type of complex array correctly - given explicit type (#111)", util.check([[
      local type MyRecord = record
         func: function<K, V>(t: {{K:V}}): {V}
      end

      local maps: {{string : number | string}} = {
         {id = 2},
         {otherkey = "hello"},
         {id = "yo"},
      }

      local x = MyRecord.func(maps)
   ]]))

   it("constructs type of complex array correctly - inferred from function return (#111)", util.check_type_error([[
      local type MyRecord = record
         func: function<K, V>(t: {{K:V}}): {V}
      end

      local good: {number | string} = MyRecord.func({
         {id = 2},
         {otherkey = "hello"},
         {id = "yo"},
      })

      local bad1: {string} = MyRecord.func({
         {id = 2},
         {otherkey = "hello"},
         {id = "yo"},
      })

      local bad2: {number} = MyRecord.func({
         {id = 2},
         {otherkey = "hello"},
         {id = "yo"},
      })
   ]], {
      { y = 12, msg = "in map value: got integer, expected string"},
      { y = 19, msg = 'in map value: got string "hello", expected number'},
      { y = 20, msg = 'in map value: got string "yo", expected number'},
   }))

end)
