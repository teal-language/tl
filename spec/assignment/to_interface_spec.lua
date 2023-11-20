local util = require("spec.util")

local scopes = {}
for _, fst in ipairs({"def", "var"}) do
   for _, snd in ipairs({"def", "var"}) do
      table.insert(scopes, "to outer " .. fst .. " with inner " .. snd)
      table.insert(scopes, "to inner " .. fst .. " with outer " .. snd)
   end
end

local assignments = {
   ["to outer def with inner var"] = "Outer = { field = { x = 42 } }", -- always fails (1)
   ["to outer def with inner def"] = "Outer = { Inner = { x = 42 } }", -- always fails (1)
   ["to outer var with inner var"] = "local v: Outer = { field = { x = 42 } }", -- always succeeds
   ["to outer var with inner def"] = "local v: Outer = { Inner = { x = 42 } }", -- always fails (2)
   ["to inner def with outer def"] = "Outer.Inner = { x = 42 }", -- always fails (3)
   ["to inner def with outer var"] = "local v: Outer = {}; v.Inner = { x = 42 }", -- always fails (3)
   ["to inner var with outer def"] = "Outer.field = { x = 42 }", -- succeeds in record only (4)
   ["to inner var with outer var"] = "local v: Outer = {}; v.field = { x = 42 }", -- always succeeds
}

describe("assignment", function()
   for _, outer in ipairs({"record", "interface"}) do
      for _, inner in ipairs({"record", "interface"}) do
         for _, scope in ipairs(scopes) do
            assert(assignments[scope])

            local err
            if scope:match("to outer def") then -- 1
               err = { { y = 6, msg = "cannot reassign a type" } }
            elseif scope:match("with inner def") then -- 2
               err = { { y = 6, msg = "cannot reassign a type" } }
            elseif scope:match("to inner def") then -- 3
               if outer == "interface" and scope:match("with outer def") then
                  err = { { y = 6, msg = "interfaces are abstract; consider using a concrete record" } }
               else
                  err = { { y = 6, msg = "cannot reassign a type" } }
               end
            elseif outer == "interface" and scope == "to inner var with outer def" then -- 4
               err = { { y = 6, msg = "interfaces are abstract; consider using a concrete record" } }
            else
               err = nil
            end

            it((err and "fails" or "succeeds") .. " with outer " .. outer .. " and inner " .. inner .. ", assignment " .. scope,
               (err and util.check_type_error or util.check)([[
                  local type Outer = ]] .. outer .. [[
                     type Inner = ]] .. inner .. [[
                        x: number
                     end
                     field: Inner
                  end

                  ]] .. assignments[scope] .. [[
               ]], err))
         end
      end
   end
end)
