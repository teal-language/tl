local util = require("spec.util")

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
      local code = {}
      for i, p in ipairs(passes) do
         table.insert(code, "local x" .. i .. " = " .. p)
      end
      local input = table.concat(code, "\n")

      util.run_check(input)
   end)
end)
