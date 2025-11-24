local block = require("teal.block")

local record ReaderAPI
   type Block = block.Block
   type BlockLang = block.BlockLang

   BLOCK_INDEXES: {string : {string : integer}}
end

ReaderAPI.BLOCK_INDEXES = block.BLOCK_INDEXES

return ReaderAPI
