local util = require("spec.util")

describe("assignment to function", function()
   it("does not crash when using plain function definitions", util.check([[
      local my_load: function(string, ? string, ? string, ? table): (function, string)

      local function run_file()
         local chunk: function(any):(any)
         chunk = my_load("")
      end
   ]]))

   it("bivariant type checking for functions with optional arguments (regression test for #827)", util.check([[
      local fcts: {string:function(val: any, opt?: string)}

      fcts['foo'] = function (val: string)
          print(val)
      end

      fcts['foo2'] = function (val: string, val2: string)  --  in assignment: incompatible number of arguments: got 2 (string, string), expected at least 1 and at most 2 (<any type>, string)
          print(val, val2)
      end

      fcts['bar'] = function (val: number)
          print(val)
      end

      fcts['bar2'] = function (val: number, val2: string)  -- in assignment: incompatible number of arguments: got 2 (number, string), expected at least 1 and at most 2 (<any type>, string)
          print(val, val2)
      end
   ]]))

   it("bivariant type checking for functions with missing arguments (regression test for #827)", util.check([[
      local fcts2: {string:function(val: any, val2: string)}

      fcts2['foo'] = function (val: string)
          print(val)
      end

      fcts2['foo2'] = function (val: string, val2: string)
          print(val, val2)
      end

      fcts2['bar'] = function (val: number)
          print(val)
      end

      fcts2['bar2'] = function (val: number, val2: string)
          print(val, val2)
      end
   ]]))

end)
