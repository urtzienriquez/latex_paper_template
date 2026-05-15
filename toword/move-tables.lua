-- move-tables.lua
-- Lua filter to move all tables to the end of the document
-- Captions appear first, then tables with labels
-- Usage: pandoc input.tex -o output.docx --lua-filter=move-tables.lua

local tables = {}
local table_counter = 0

-- Collect tables and remove them from the text
function Table(tbl)
  table_counter = table_counter + 1
  
  -- Store the table
  table.insert(tables, tbl)
  
  -- Remove the table from its original location
  return {}
end

-- Add captions and tables at the end of the document
function Pandoc(doc)
  if #tables > 0 then
    -- Add a section header for captions
    local caption_header = pandoc.Header(1, {pandoc.Str("Table Captions")})
    table.insert(doc.blocks, caption_header)
    
    -- Add all captions
    for i, tbl in ipairs(tables) do
      -- Build caption content as a list of inlines
      local caption_inlines = {}
      
      -- Try different ways to extract caption
      if tbl.caption then
        if tbl.caption.long then
          -- Pandoc 2.10+
          for _, block in ipairs(tbl.caption.long) do
            if block.content then
              -- If it's a Para or other block with content
              for _, inline in ipairs(block.content) do
                table.insert(caption_inlines, inline)
              end
            end
          end
        elseif type(tbl.caption) == "table" then
          -- Older Pandoc versions - caption is directly a list of inlines
          for _, inline in ipairs(tbl.caption) do
            table.insert(caption_inlines, inline)
          end
        end
      end
      
      -- If no caption was found, add a default one
      if #caption_inlines == 0 then
        table.insert(caption_inlines, pandoc.Str("Table " .. tostring(i)))
      end
      
      table.insert(doc.blocks, pandoc.Para(caption_inlines))
    end
    
    -- Add spacing
    table.insert(doc.blocks, pandoc.Para({}))
    
    -- Add a section header for tables
    local table_header = pandoc.Header(1, {pandoc.Str("Tables")})
    table.insert(doc.blocks, table_header)
    
    -- Add all tables with just their number
    for i, tbl in ipairs(tables) do
      -- Add just a label before the table
      table.insert(doc.blocks, pandoc.Para({
        pandoc.Strong({pandoc.Str("Table " .. tostring(i))})
      }))
      
      -- Add the table itself
      table.insert(doc.blocks, tbl)
      
      -- Add spacing between tables
      table.insert(doc.blocks, pandoc.Para({}))
    end
  end
  
  return doc
end

-- Return the filters in the correct order
return {
  {Table = Table},
  {Pandoc = Pandoc}
}
