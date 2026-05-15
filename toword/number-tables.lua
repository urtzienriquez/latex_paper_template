-- number-tables.lua
-- Prepends "Table N: " to each table caption

local tbl_num = 0

function Table(tbl)
  tbl_num = tbl_num + 1
  
  -- Check if table has a caption
  if tbl.caption and tbl.caption.long then
    local prefix = pandoc.Str("Table " .. tbl_num .. ": ")
    
    -- Add prefix to the first block's content
    for _, block in ipairs(tbl.caption.long) do
      if block.content then
        table.insert(block.content, 1, prefix)
        break
      end
    end
  end
  
  return tbl
end
