-- Teal supports a simple form of generics that is
-- useful enough for dealing collections and algorithms that
-- operate over abstract data types. You can use type
-- variables wherever a type is used, and you can declare them
-- in both functions and records. Here's an example of a
-- generic function:

local function keys<K,V>(xs: {K:V}):{K}
  local ks = {}
  for k, v in pairs(xs) do
    table.insert(ks, k)
  end
  return ks
end

local s = keys({ a = 1, b = 2 }) -- s is {string}
