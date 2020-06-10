local tl = require("tl")

math.randomseed(os.time())

describe("lexer", function()

   local function gen_all_passes(out, prefix, parts, psign, powers)
      local passes = {}
      for _, p in ipairs(parts) do
         table.insert(passes, p)
      end
      for _, p in ipairs(parts) do
         table.insert(passes, "." .. p)
      end
      for _, a in ipairs(parts) do
         for _, b in ipairs(parts) do
            table.insert(passes, a .. "." .. b)
         end
      end
      for _, a in ipairs(passes) do
         table.insert(out, prefix .. a)
         for _, b in ipairs(powers) do
            table.insert(out, prefix .. a .. psign .. b)
            table.insert(out, prefix .. a .. psign .. "-" .. b)
            table.insert(out, prefix .. a .. psign .. "+" .. b)
         end
      end
   end

   local dec = "0123456789"
   local hex = "0123456789abcdefABCDEF"

   local function r(l, min, max)
      local out = {}
      for _ = 1, math.random(max - min + 1) + min - 1 do
         local x = math.random(#l)
         table.insert(out, l:sub(x, x))
      end
      return table.concat(out)
   end

   local decs = { "0", "0" .. r(dec, 1, 3), "1", r(dec, 1, 3) }
   local hexs = { "0", "0" .. r(hex, 1, 3), "1", r(hex, 1, 3) }

   local passes = {}
   gen_all_passes(passes, "",   decs, "e", decs)
   gen_all_passes(passes, "",   decs, "E", decs)
   gen_all_passes(passes, "0x", hexs, "p", decs)
   gen_all_passes(passes, "0x", hexs, "P", decs)
   gen_all_passes(passes, "0X", hexs, "p", decs)
   gen_all_passes(passes, "0X", hexs, "P", decs)

   it("accepts valid literals", function()
      local syntax_errors = {}
      local code = {}
      for i, p in ipairs(passes) do
         table.insert(code, "local x" .. i .. " = " .. p)
      end
      local input = table.concat(code, "\n")

      local tokens = tl.lex(input)
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("lexes luajit binary literals", function()
      local syntax_errors = {}
      local tokens = tl.lex("0b1001001")
      assert.same(1, #tokens)
      assert.same("number", tokens[1].kind)
   end)

   it("lexes luajit integer number suffixes", function()
      local syntax_errors = {}
      local tokens = tl.lex("100ll 100lL 100UlL 100ull")
      assert.same(4, #tokens)
      for i = 1, 4 do
         assert.same("number", tokens[i].kind)
      end
   end)

   it("lexes luajit complex number suffix", function()
      local syntax_errors = {}
      local tokens = tl.lex("100i")
      assert.same(1, #tokens)
      assert.same("number", tokens[1].kind)
   end)
end)
