local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tldebug = require("teal.debug")
local TL_DEBUG_FACTS = tldebug.TL_DEBUG_FACTS




local types = require("teal.types")




local a_type = types.a_type
local show_type = types.show_type
local unite = types.unite




local util = require("teal.util")
local sorted_keys = util.sorted_keys

local facts = { TruthyFact = {}, NotFact = {}, AndFact = {}, OrFact = {}, EqFact = {}, IsFact = {}, FactDatabase = {} }























































































local IsFact = facts.IsFact
local EqFact = facts.EqFact
local AndFact = facts.AndFact
local OrFact = facts.OrFact
local NotFact = facts.NotFact
local TruthyFact = facts.TruthyFact
local FactDatabase = facts.FactDatabase

local IsFact_mt = {
   __tostring = function(f)
      return ("(%s is %s)"):format(f.var, show_type(f.typ))
   end,
}

setmetatable(IsFact, {
   __call = function(_, fact)
      fact.fact = "is"
      assert(fact.w)
      return setmetatable(fact, IsFact_mt)
   end,
})

local EqFact_mt = {
   __tostring = function(f)
      return ("(%s == %s)"):format(f.var, show_type(f.typ))
   end,
}

setmetatable(EqFact, {
   __call = function(_, fact)
      fact.fact = "=="
      assert(fact.w)
      return setmetatable(fact, EqFact_mt)
   end,
})

local TruthyFact_mt = {
   __tostring = function(_f)
      return "*"
   end,
}

setmetatable(TruthyFact, {
   __call = function(_, fact)
      fact.fact = "truthy"
      return setmetatable(fact, TruthyFact_mt)
   end,
})

local NotFact_mt = {
   __tostring = function(f)
      return ("(not %s)"):format(tostring(f.f1))
   end,
}

setmetatable(NotFact, {
   __call = function(_, fact)
      fact.fact = "not"
      return setmetatable(fact, NotFact_mt)
   end,
})

local AndFact_mt = {
   __tostring = function(f)
      return ("(%s and %s)"):format(tostring(f.f1), tostring(f.f2))
   end,
}

setmetatable(AndFact, {
   __call = function(_, fact)
      fact.fact = "and"
      return setmetatable(fact, AndFact_mt)
   end,
})

local OrFact_mt = {
   __tostring = function(f)
      return ("(%s or %s)"):format(tostring(f.f1), tostring(f.f2))
   end,
}

setmetatable(OrFact, {
   __call = function(_, fact)
      fact.fact = "or"
      return setmetatable(fact, OrFact_mt)
   end,
})


local FACT_TRUTHY = TruthyFact({})
facts.FACT_TRUTHY = FACT_TRUTHY

function facts.facts_and(w, f1, f2)
   if not f1 and not f2 then
      return
   end
   return AndFact({ f1 = f1, f2 = f2, w = w })
end

function facts.facts_or(w, f1, f2)
   return OrFact({ f1 = f1 or FACT_TRUTHY, f2 = f2 or FACT_TRUTHY, w = w })
end

function facts.facts_not(w, f1)
   if f1 then
      return NotFact({ f1 = f1, w = w })
   else
      return nil
   end
end


local function unite_types(w, t1, t2)
   return unite(w, { t2, t1 })
end


local function intersect_types(ck, w, t1, t2)
   if t2.typename == "union" then
      t1, t2 = t2, t1
   end
   if t1.typename == "union" then
      local out = {}
      for _, t in ipairs(t1.types) do
         if ck:is_a(t, t2) then
            table.insert(out, t)
         end
      end
      if #out > 0 then
         return unite(w, out)
      end
   end
   if ck:is_a(t1, t2) then
      return t1
   elseif ck:is_a(t2, t1) then
      return t2
   else
      return a_type(w, "nil", {})
   end
end

local function resolve_if_union(ck, t)
   local rt = ck:to_structural(t)
   if rt.typename == "union" then
      return rt
   end
   return t
end


local function subtract_types(ck, w, t1, t2)
   local typs = {}

   t1 = resolve_if_union(ck, t1)


   if not (t1.typename == "union") then
      return t1
   end

   t2 = resolve_if_union(ck, t2)
   local t2types = t2.typename == "union" and t2.types or { t2 }

   for _, at in ipairs(t1.types) do
      local not_present = true
      for _, bt in ipairs(t2types) do
         if ck:same_type(at, bt) then
            not_present = false
            break
         end
      end
      if not_present then
         table.insert(typs, at)
      end
   end

   if #typs == 0 then
      return a_type(w, "nil", {})
   end

   return unite(w, typs)
end

local eval_not
local not_facts
local or_facts
local and_facts

local function invalid_from(f)
   return IsFact({ fact = "is", var = f.var, typ = a_type(f.w, "invalid", {}), w = f.w })
end





not_facts = function(ck, fs)
   local ret = {}
   for var, f in pairs(fs) do
      local typ = ck:find_var_type(f.var, "check_only")

      if not typ then
         ret[var] = EqFact({ var = var, typ = a_type(f.w, "invalid", {}), w = f.w, no_infer = f.no_infer })
      elseif f.fact == "==" then

         ret[var] = EqFact({ var = var, typ = typ, w = f.w, no_infer = true })
      elseif typ.typename == "typevar" then
         assert(f.fact == "is")

         ret[var] = EqFact({ var = var, typ = typ, w = f.w, no_infer = true })
      elseif not ck:is_a(f.typ, typ) then
         assert(f.fact == "is")
         ck:add_warning("branch", f.w, f.var .. " (of type %s) can never be a %s", show_type(typ), show_type(f.typ))
         ret[var] = EqFact({ var = var, typ = a_type(f.w, "invalid", {}), w = f.w, no_infer = f.no_infer })
      else
         assert(f.fact == "is")
         ret[var] = IsFact({ var = var, typ = subtract_types(ck, f.w, typ, f.typ), w = f.w, no_infer = f.no_infer })
      end
   end
   return ret
end

eval_not = function(ck, f)
   if not f then
      return {}
   elseif f.fact == "is" then
      return not_facts(ck, { [f.var] = f })
   elseif f.fact == "not" then
      return facts.eval_fact(ck, f.f1)
   elseif f.fact == "and" and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f.fact == "or" and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f.fact == "and" then
      return or_facts(ck, eval_not(ck, f.f1), eval_not(ck, f.f2))
   elseif f.fact == "or" then
      return and_facts(ck, eval_not(ck, f.f1), eval_not(ck, f.f2))
   else
      return not_facts(ck, facts.eval_fact(ck, f))
   end
end

or_facts = function(_ck, fs1, fs2)
   local ret = {}

   for var, f in pairs(fs2) do
      if fs1[var] then
         local united = unite_types(f.w, f.typ, fs1[var].typ)
         if fs1[var].fact == "is" and f.fact == "is" then
            ret[var] = IsFact({ var = var, typ = united, w = f.w })
         else
            ret[var] = EqFact({ var = var, typ = united, w = f.w })
         end
      end
   end

   return ret
end

and_facts = function(ck, fs1, fs2)
   local ret = {}
   local has = {}

   for var, f in pairs(fs1) do
      local rt
      local ctor = EqFact
      if fs2[var] then
         if fs2[var].fact == "is" and f.fact == "is" then
            ctor = IsFact
         end
         rt = intersect_types(ck, f.w, f.typ, fs2[var].typ)
      else
         rt = f.typ
      end
      local ff = ctor({ var = var, typ = rt, w = f.w, no_infer = f.no_infer })
      ret[var] = ff
      has[ff.fact] = true
   end

   for var, f in pairs(fs2) do
      if not fs1[var] then
         ret[var] = EqFact({ var = var, typ = f.typ, w = f.w, no_infer = f.no_infer })
         has["=="] = true
      end
   end

   if has["is"] and has["=="] then
      for _, f in pairs(ret) do
         f.fact = "=="
      end
   end

   return ret
end

function facts.eval_fact(ck, f)
   if not f then
      return {}
   elseif f.fact == "is" then
      local typ = ck:find_var_type(f.var, "check_only")
      if not typ then
         return { [f.var] = invalid_from(f) }
      end
      if not (typ.typename == "typevar") then
         if ck:is_a(typ, f.typ) then


            return { [f.var] = f }
         elseif not ck:is_a(f.typ, typ) then
            ck:add_error(f.w, f.var .. " (of type %s) can never be a %s", typ, f.typ)
            return { [f.var] = invalid_from(f) }
         end
      end
      return { [f.var] = f }
   elseif f.fact == "==" then
      return { [f.var] = f }
   elseif f.fact == "not" then
      return eval_not(ck, f.f1)
   elseif f.fact == "truthy" then
      return {}
   elseif f.fact == "and" and f.f2 and f.f2.fact == "truthy" then
      return facts.eval_fact(ck, f.f1)
   elseif f.fact == "or" and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f.fact == "and" then
      return and_facts(ck, facts.eval_fact(ck, f.f1), facts.eval_fact(ck, f.f2))
   elseif f.fact == "or" then
      return or_facts(ck, facts.eval_fact(ck, f.f1), facts.eval_fact(ck, f.f2))
   end
end

if TL_DEBUG_FACTS then
   local eval_indent = -1
   local real_eval_fact = facts.eval_fact
   facts.eval_fact = function(self, known)
      eval_indent = eval_indent + 1
      tldebug.write(("   "):rep(eval_indent))
      tldebug.write("eval fact: ", tostring(known), "\n")
      local fcts = real_eval_fact(self, known)
      if fcts then
         for _, k in ipairs(sorted_keys(fcts)) do
            local f = fcts[k]
            tldebug.write(("   "):rep(eval_indent), "=> ", tostring(f), "\n")
         end
      else
         tldebug.write(("   "):rep(eval_indent), "=> .\n")
      end
      tldebug.flush()
      eval_indent = eval_indent - 1
      return fcts
   end
end

function FactDatabase.new()
   local self = {
      db = {},
   }
   setmetatable(self, { __index = FactDatabase })
   return self
end

function FactDatabase:set_truthy(w)
   self.db[w] = FACT_TRUTHY
end

function FactDatabase:set_is(w, var, typ)
   self.db[w] = IsFact({ var = var, typ = typ, w = w })
end

function FactDatabase:set_eq(w, var, typ)
   self.db[w] = EqFact({ var = var, typ = typ, w = w })
end

function FactDatabase:set_or(w, e1, e2)
   self.db[w] = OrFact({ f1 = self.db[e1] or FACT_TRUTHY, f2 = self.db[e2] or FACT_TRUTHY, w = w })
end

function FactDatabase:set_not(w, e1)
   self.db[w] = facts.facts_not(w, self.db[e1])
end

function FactDatabase:set_and(w, e1, e2)
   self.db[w] = facts.facts_and(w, self.db[e1], self.db[e2])
end

function FactDatabase:set_from(w, from)
   if from then
      self.db[w] = self.db[from]
   end
end

function FactDatabase:unset(w)
   self.db[w] = nil
end

function FactDatabase:get(w)
   return self.db[w]
end

return facts
