local metamethods = {}





metamethods.unop_to_metamethod = {
   ["#"] = "__len",
   ["-"] = "__unm",
   ["~"] = "__bnot",
}

metamethods.binop_to_metamethod = {
   ["+"] = "__add",
   ["-"] = "__sub",
   ["*"] = "__mul",
   ["/"] = "__div",
   ["%"] = "__mod",
   ["^"] = "__pow",
   ["//"] = "__idiv",
   ["&"] = "__band",
   ["|"] = "__bor",
   ["~"] = "__bxor",
   ["<<"] = "__shl",
   [">>"] = "__shr",
   [".."] = "__concat",
   ["=="] = "__eq",
   ["<"] = "__lt",
   ["<="] = "__le",
   ["@index"] = "__index",
   ["is"] = "__is",
}

metamethods.flip_binop_to_metamethod = {
   [">"] = "__lt",
   [">="] = "__le",
}

return metamethods
