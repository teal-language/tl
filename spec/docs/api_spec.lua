local function lines(script)
   local out = {}
   for i, line in ipairs(script) do
      table.insert(out, ("%d\t%s"):format(i, line))
   end
   return table.concat(out, "\n")
end

describe("API doc_nameation", function()
   it("works", function()
      local script = {}
      local doc_name = "docs/src/the_teal_api.md"
      local fd = io.open(doc_name)
      local store = false
      for line in fd:lines() do
         if store then
            if line:match("^```") then
               store = false
            else
               table.insert(script, line)
            end
         else
            if line:match("^```") then
               store = true
            end
         end
      end
      local script_text = table.concat(script, "\n")
      local code, err = load(script_text)
      assert(code, err)
      local pok, perr = pcall(code)
      assert(pok, "Error running code from " .. doc_name .."\n"..tostring(perr).."\n".."source:\n" .. lines(script))
   end)
end)
