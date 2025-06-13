local reader = require("teal.reader")

local program = [[
print "hello 2"

do
    print "hello 2"
end

print "hello 3"
]]

local blk, err = reader.read(program, "test")

local function prettyprint(blk: reader.Block)
    local function pp(i: integer, node: reader.Block, ident: string)
        print(string.format("%s[%d] = <%s>", ident, i, tostring(node)))
        for i, child in ipairs(node) do
            pp(i, child, ident.."  ")
        end
    end

    pp(1, blk, "")
    print()
end
prettyprint(blk)
if err or #err > 0 then
    print("Error reading program:")
    for _, e in ipairs(err) do
        print(e)
    end
    return
end

