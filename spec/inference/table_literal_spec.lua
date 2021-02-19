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

   it("directed inference produces correct results for incomplete records (regression test for #348)", util.check [[
      local record test_t
         a: number
         b: number
      end

      local _: {test_t} = {
         {
            a=1,
         },
         {
            a=1,
            b=2
         }
      }
   ]])
end)
