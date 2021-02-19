local util = require("spec.util")

describe("bidirectional inference for table literals", function()
   it("declaration directs inference of table (regression test for #375)", util.check_type_error([[
      local record Container
         enum TypeEnum
            "number"
         end
         type: TypeEnum
      end

      local x: {Container} = {
         { type = 'number' },
         { type = 'who'    },
      }
      print(x)
   ]], {
      { msg = "in record field: type: string 'who' is not a member of enum" },
   }))
end)
