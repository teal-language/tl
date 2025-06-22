local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local string = _tl_compat and _tl_compat.string or string; local types = require("teal.types")


local show_type = types.show_type

local facts = { TruthyFact = {}, NotFact = {}, AndFact = {}, OrFact = {}, EqFact = {}, IsFact = {} }











































































local IsFact = facts.IsFact
local EqFact = facts.EqFact
local AndFact = facts.AndFact
local OrFact = facts.OrFact
local NotFact = facts.NotFact
local TruthyFact = facts.TruthyFact

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

return facts
