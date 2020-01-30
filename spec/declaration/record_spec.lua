local tl = require("tl")

describe("record", function()
   it("can overload functions", function()
      local tokens = tl.lex([[
         global love_graphics = record
            print: function(text: string, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky:number)
            print: function(coloredtext: {any}, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky:number)
         end

         global love = record
            graphics: love_graphics
         end

         function main()
            love.graphics.print("Hello world", 100, 100)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("cannot overload other things", function()
      local tokens = tl.lex([[
         global love_graphics = record
            print: number
            print: string
         end
      ]])
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same("attempt to redeclare field 'print' (only functions can be overloaded)", syntax_errors[1].msg)
   end)

end)
