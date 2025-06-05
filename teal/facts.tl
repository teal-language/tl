local types = require("teal.types")
local type Where = types.Where
local type Type = types.Type

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

return facts
