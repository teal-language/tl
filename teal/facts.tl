local tldebug = require("teal.debug")
local TL_DEBUG_FACTS = tldebug.TL_DEBUG_FACTS

local type errors = require("teal.errors")
local type Where = errors.Where

local types = require("teal.types")
local type InvalidType = types.InvalidType
local type Type = types.Type
local type TypeVarType = types.TypeVarType
local type UnionType = types.UnionType
local a_type = types.a_type
local show_type = types.show_type
local unite = types.unite

local type type_checker = require("teal.check.type_checker")
local type TypeChecker = type_checker.TypeChecker

local util = require("teal.util")
local sorted_keys = util.sorted_keys

local record facts
   enum FactType
      "is"     -- type-based type judgement (its negation implies the subtracted type)
      "=="     -- value-based type judgement (its negation does not imply a subtracted type negated)
      "not"    -- negation: type-based judgements subtract, value-based judgements prove nothing
      "and"    -- conjunction: type-based judgements intersect, any value-based judgement downgrades all
      "or"     -- disjunction: type-based judgements unite, any value-based judgement downgrades all
      "truthy" -- expression that is either truthy or a runtime error
   end

   interface Fact
      where self.fact

      fact: FactType
      w: Where
      no_infer: boolean
   end

   record TruthyFact
      is Fact
      where self.fact == "truthy"

      metamethod __call: function(Fact, Fact): TruthyFact
   end

   record NotFact
      is Fact
      where self.fact == "not"

      f1: Fact

      metamethod __call: function(Fact, Fact): NotFact
   end

   record AndFact
      is Fact
      where self.fact == "and"

      f1: Fact
      f2: Fact

      metamethod __call: function(Fact, Fact): AndFact
   end

   record OrFact
      is Fact
      where self.fact == "or"

      f1: Fact
      f2: Fact

      metamethod __call: function(Fact, Fact): OrFact
   end

   record EqFact
      is Fact
      where self.fact == "=="

      var: string
      typ: Type

      metamethod __call: function(Fact, Fact): EqFact
   end

   record IsFact
      is Fact
      where self.fact == "is"

      var: string
      typ: Type

      metamethod __call: function(Fact, Fact): IsFact
   end

   facts_and: function(w: Where, f1: Fact, f2: Fact): Fact
   facts_or: function(w: Where, f1: Fact, f2: Fact): Fact
   facts_not: function(w: Where, f1: Fact): Fact
   FACT_TRUTHY: TruthyFact

   record FactDatabase
      db: {Where: Fact}
   end

   eval_fact: function(ck: TypeChecker, f: Fact): {string:IsFact|EqFact}
end

local type Fact = facts.Fact
local type FactType = facts.FactType
local type IsFact = facts.IsFact
local type EqFact = facts.EqFact
local type AndFact = facts.AndFact
local type OrFact = facts.OrFact
local type NotFact = facts.NotFact
local type TruthyFact = facts.TruthyFact
local type FactDatabase = facts.FactDatabase

local IsFact_mt: metatable<IsFact> = {
   __tostring = function(f: IsFact): string
      return ("(%s is %s)"):format(f.var, show_type(f.typ))
   end
}

setmetatable(IsFact, {
   __call = function(_: IsFact, fact: Fact): IsFact
      fact.fact = "is"
      assert(fact.w)
      return setmetatable(fact as IsFact, IsFact_mt)
   end,
})

local EqFact_mt: metatable<EqFact> = {
   __tostring = function(f: EqFact): string
      return ("(%s == %s)"):format(f.var, show_type(f.typ))
   end
}

setmetatable(EqFact, {
   __call = function(_: EqFact, fact: Fact): EqFact
      fact.fact = "=="
      assert(fact.w)
      return setmetatable(fact as EqFact, EqFact_mt)
   end,
})

local TruthyFact_mt: metatable<TruthyFact> = {
   __tostring = function(_f: TruthyFact): string
      return "*"
   end
}

setmetatable(TruthyFact, {
   __call = function(_: TruthyFact, fact: Fact): TruthyFact
      fact.fact = "truthy"
      return setmetatable(fact as TruthyFact, TruthyFact_mt)
   end,
})

local NotFact_mt: metatable<NotFact> = {
   __tostring = function(f: NotFact): string
      return ("(not %s)"):format(tostring(f.f1))
   end
}

setmetatable(NotFact, {
   __call = function(_: NotFact, fact: Fact): NotFact
      fact.fact = "not"
      return setmetatable(fact as NotFact, NotFact_mt)
   end,
})

local AndFact_mt: metatable<AndFact> = {
   __tostring = function(f: AndFact): string
      return ("(%s and %s)"):format(tostring(f.f1), tostring(f.f2))
   end
}

setmetatable(AndFact, {
   __call = function(_: AndFact, fact: Fact): AndFact
      fact.fact = "and"
      return setmetatable(fact as AndFact, AndFact_mt)
   end,
})

local OrFact_mt: metatable<OrFact> = {
   __tostring = function(f: OrFact): string
      return ("(%s or %s)"):format(tostring(f.f1), tostring(f.f2))
   end
}

setmetatable(OrFact, {
   __call = function(_: OrFact, fact: Fact): OrFact
      fact.fact = "or"
      return setmetatable(fact as OrFact, OrFact_mt)
   end,
})

-- Inference engine for 'is' operator
local FACT_TRUTHY = TruthyFact {}
facts.FACT_TRUTHY = FACT_TRUTHY

function facts.facts_and(w: Where, f1: Fact, f2: Fact): Fact
   if not f1 and not f2 then
      return
   end
   return AndFact { f1 = f1, f2 = f2, w = w }
end

function facts.facts_or(w: Where, f1: Fact, f2: Fact): Fact
   return OrFact({ f1 = f1 or FACT_TRUTHY, f2 = f2 or FACT_TRUTHY, w = w })
end

function facts.facts_not(w: Where, f1: Fact): Fact
   if f1 then
      return NotFact { f1 = f1, w = w }
   else
      return nil
   end
end

-- t1 ∪ t2
local function unite_types(w: Where, t1: Type, t2: Type): Type, string
   return unite(w, {t2, t1})
end

-- t1 ∩ t2
local function intersect_types(ck: TypeChecker, w: Where, t1: Type, t2: Type): Type, string
   if t2 is UnionType then
      t1, t2 = t2, t1
   end
   if t1 is UnionType then
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
      return a_type(w, "nil", {}) -- because of implicit nil in all unions
   end
end

local function resolve_if_union(ck: TypeChecker, t: Type): Type
   local rt = ck:to_structural(t)
   if rt is UnionType then
      return rt
   end
   return t
end

-- t1 - t2
local function subtract_types(ck: TypeChecker, w: Where, t1: Type, t2: Type): Type
   local typs: {Type} = {}

   t1 = resolve_if_union(ck, t1)

   -- poly are not first-class, so we don't handle them here
   if not t1 is UnionType then
      return t1
   end

   t2 = resolve_if_union(ck, t2)
   local t2types = t2 is UnionType and t2.types or { t2 }

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
      return a_type(w, "nil", {}) -- because of implicit nil in all unions
   end

   return unite(w, typs)
end

local eval_not: function(TypeChecker, f: Fact): {string:IsFact|EqFact}
local not_facts: function(TypeChecker, fs: {string:IsFact|EqFact}): {string:IsFact|EqFact}
local or_facts: function(TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
local and_facts: function(TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}

local function invalid_from(f: IsFact): IsFact
   return IsFact { fact = "is", var = f.var, typ = a_type(f.w, "invalid", {}), w = f.w }
end

local macroexp an_invalid(w: Where): InvalidType
   return a_type(w, "invalid", {} as InvalidType)
end

not_facts = function(ck: TypeChecker, fs: {string:IsFact|EqFact}): {string:IsFact|EqFact}
   local ret: {string:IsFact|EqFact} = {}
   for var, f in pairs(fs) do
      local typ = ck:find_var_type(f.var, "check_only")

      if not typ then
         ret[var] = EqFact { var = var, typ = an_invalid(f.w), w = f.w, no_infer = f.no_infer }
      elseif f is EqFact then
         -- nothing is known from negation of equality; widen back
         ret[var] = EqFact { var = var, typ = typ, w = f.w, no_infer = true }
      elseif typ is TypeVarType then
         assert(f.fact == "is")
         -- nothing is known from negation on typeargs; widen back
         ret[var] = EqFact { var = var, typ = typ, w = f.w, no_infer = true }
      elseif not ck:is_a(f.typ, typ) then
         assert(f.fact == "is")
         ck:add_warning("branch", f.w, f.var .. " (of type %s) can never be a %s", show_type(typ), show_type(f.typ))
         ret[var] = EqFact { var = var, typ = an_invalid(f.w), w = f.w, no_infer = f.no_infer }
      else
         assert(f.fact == "is")
         ret[var] = IsFact { var = var, typ = subtract_types(ck, f.w, typ, f.typ), w = f.w, no_infer = f.no_infer }
      end
   end
   return ret
end

eval_not = function(ck: TypeChecker, f: Fact): {string:IsFact|EqFact}
   if not f then
      return {}
   elseif f is IsFact then
      return not_facts(ck, {[f.var] = f})
   elseif f is NotFact then
      return facts.eval_fact(ck, f.f1)
   elseif f is AndFact and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f is OrFact and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f is AndFact then
      return or_facts(ck, eval_not(ck, f.f1), eval_not(ck, f.f2))
   elseif f is OrFact then
      return and_facts(ck, eval_not(ck, f.f1), eval_not(ck, f.f2))
   else
      return not_facts(ck, facts.eval_fact(ck, f))
   end
end

or_facts = function(_ck: TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
   local ret: {string:IsFact|EqFact} = {}

   for var, f in pairs(fs2) do
      if fs1[var] then
         local united = unite_types(f.w, f.typ, fs1[var].typ)
         if fs1[var].fact == "is" and f.fact == "is" then
            ret[var] = IsFact { var = var, typ = united, w = f.w }
         else
            ret[var] = EqFact { var = var, typ = united, w = f.w }
         end
      end
   end

   return ret
end

and_facts = function(ck: TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
   local ret: {string:IsFact|EqFact} = {}
   local has: {FactType:boolean} = {}

   for var, f in pairs(fs1) do
      local rt: Type
      local ctor: IsFact | EqFact = EqFact
      if fs2[var] then
         if fs2[var].fact == "is" and f.fact == "is" then
            ctor = IsFact
         end
         rt = intersect_types(ck, f.w, f.typ, fs2[var].typ)
      else
         rt = f.typ
      end
      local ff = ctor { var = var, typ = rt, w = f.w, no_infer = f.no_infer }
      ret[var] = ff
      has[ff.fact] = true
   end

   for var, f in pairs(fs2) do
      if not fs1[var] then
         ret[var] = EqFact { var = var, typ = f.typ, w = f.w, no_infer = f.no_infer }
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

function facts.eval_fact(ck: TypeChecker, f: Fact): {string:IsFact|EqFact}
   if not f then
      return {}
   elseif f is IsFact then
      local typ = ck:find_var_type(f.var, "check_only")
      if not typ then
         return { [f.var] = invalid_from(f) }
      end
      if not typ is TypeVarType then
         if ck:is_a(typ, f.typ) then
            -- drop this warning because of implicit nil in all unions
            -- ck.errs:add_warning("branch", f.w, f.var .. " (of type %s) is always a %s", show_type(typ), show_type(f.typ))
            return { [f.var] = f }
         elseif not ck:is_a(f.typ, typ) then
            ck:add_error(f.w, f.var .. " (of type %s) can never be a %s", typ, f.typ)
            return { [f.var] = invalid_from(f) }
         end
      end
      return { [f.var] = f }
   elseif f is EqFact then
      return { [f.var] = f }
   elseif f is NotFact then
      return eval_not(ck, f.f1)
   elseif f is TruthyFact then
      return {}
   elseif f is AndFact and f.f2 and f.f2.fact == "truthy" then
      return facts.eval_fact(ck, f.f1)
   elseif f is OrFact and f.f2 and f.f2.fact == "truthy" then
      return eval_not(ck, f.f1)
   elseif f is AndFact then
      return and_facts(ck, facts.eval_fact(ck, f.f1), facts.eval_fact(ck, f.f2))
   elseif f is OrFact then
      return or_facts(ck, facts.eval_fact(ck, f.f1), facts.eval_fact(ck, f.f2))
   end
end

if TL_DEBUG_FACTS then
   local eval_indent = -1
   local real_eval_fact = facts.eval_fact
   facts.eval_fact = function(self: TypeChecker, known: Fact): {string: IsFact|EqFact}
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

function FactDatabase.new(): FactDatabase
   local self = {
      db = {}
   }
   setmetatable(self, { __index = FactDatabase })
   return self
end

function FactDatabase:set_truthy(w: Where)
   self.db[w] = FACT_TRUTHY
end

function FactDatabase:set_is(w: Where, var: string, typ: Type)
   self.db[w] = IsFact { var = var, typ = typ, w = w }
end

function FactDatabase:set_eq(w: Where, var: string, typ: Type)
   self.db[w] = EqFact { var = var, typ = typ, w = w }
end

function FactDatabase:set_or(w: Where, e1: Where, e2: Where)
   self.db[w] = OrFact { f1 = self.db[e1] or FACT_TRUTHY, f2 = self.db[e2] or FACT_TRUTHY, w = w }
end

function FactDatabase:set_not(w: Where, e1: Where)
   self.db[w] = facts.facts_not(w, self.db[e1])
end

function FactDatabase:set_and(w: Where, e1: Where, e2: Where)
   self.db[w] = facts.facts_and(w, self.db[e1], self.db[e2])
end

function FactDatabase:set_from(w: Where, from: Where)
   if from then
      self.db[w] = self.db[from]
   end
end

function FactDatabase:unset(w: Where)
   self.db[w] = nil
end

function FactDatabase:get(w: Where): Fact
   return self.db[w]
end

return facts
