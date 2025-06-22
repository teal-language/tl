local types = require("teal.types")
local type Where = types.Where
local type Type = types.Type
local show_type = types.show_type

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
end

local type Fact = facts.Fact
local type IsFact = facts.IsFact
local type EqFact = facts.EqFact
local type AndFact = facts.AndFact
local type OrFact = facts.OrFact
local type NotFact = facts.NotFact
local type TruthyFact = facts.TruthyFact

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

return facts
