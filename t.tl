local macro struct!(rec: Statement)
    -- Pull the declared type name from the statement block
    local name = rec[1][1]

    -- Build a string node with the same text for __name
    local strname = block "string"
    strname.conststr = name.tk
    strname.tk = "\"" .. name.tk .. "\""

    -- Assemble output statements: original declaration + constructor method
    local out = block('statements')
    table.insert(out, rec)

    local ctor = ```
        function $name:create(x: integer, y: integer): self
            return setmetatable({ x = x, y = y }, { __index = self, __name = $strname })
        end
    ```
    
    -- `ctor` is a statements block; splice its contents
    for i = 1, #ctor do
        table.insert(out, ctor[i])
    end

    return out
end

struct!(local record Point
    x: integer
    y: integer
end)

local function nameof(x: any): string
    local mt = getmetatable(x)
    return (x is table and mt ~= nil and mt.__name) and mt.__name or type(x)
end

local a = Point:create(4, 2)

print(a.x, a.y, nameof(a))
