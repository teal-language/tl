local util = require("spec.util")

describe("#", function()
   it("returns an integer when used on array", util.check[[
      local x: integer = #({1, 2, 3})
   ]])
   it("returns an integer when used on tuple", util.check[[
      local x: integer = #({1, "hi"})
   ]])

   it("the map size is always zero", util.check_type_error([[
       local x: {string:string} = {a="a", b="b", c="c"}
       print(#x)
   ]], {
      { y=2, msg = "use # operator on this map will always get 0" }
   }))
   it("the map size may be wrong", util.check_warnings([[
       local x: {integer:string} = {[1]="a", [2]="b", [4]="c"}
       print(#x)
   ]], {
      { y=2, msg = "use # operator on map with number key type may get unexpected result" }
   }))
end)
