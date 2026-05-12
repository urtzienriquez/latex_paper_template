-- Lua filter to move all figures to the end of the document
-- Captions appear first, then figures with labels
-- Usage: pandoc input.tex -o output.docx --lua-filter=move-figures.lua

local figures = {}
local figure_counter = 0

-- Collect figures and remove them from the text
function Figure(fig)
  figure_counter = figure_counter + 1
  
  -- Store the figure
  table.insert(figures, fig)
  
  -- Remove the figure from its original location
  return {}
end

-- Add captions and figures at the end of the document
function Pandoc(doc)
  if #figures > 0 then
    -- Add a section header for captions
    local caption_header = pandoc.Header(1, {pandoc.Str("Figure Captions")})
    table.insert(doc.blocks, caption_header)
    
    -- Add all captions
    for i, fig in ipairs(figures) do
      -- Build caption content as a list of inlines
      local caption_inlines = {}
      
      -- Try different ways to extract caption
      if fig.caption then
        if fig.caption.long then
          -- Pandoc 2.10+
          for _, block in ipairs(fig.caption.long) do
            if block.content then
              -- If it's a Para or other block with content
              for _, inline in ipairs(block.content) do
                table.insert(caption_inlines, inline)
              end
            end
          end
        elseif type(fig.caption) == "table" then
          -- Older Pandoc versions - caption is directly a list of inlines
          for _, inline in ipairs(fig.caption) do
            table.insert(caption_inlines, inline)
          end
        end
      end
      
      -- If no caption was found, add a default one
      if #caption_inlines == 0 then
        table.insert(caption_inlines, pandoc.Str("Figure " .. tostring(i)))
      end
      
      table.insert(doc.blocks, pandoc.Para(caption_inlines))
    end
    
    -- Add spacing
    table.insert(doc.blocks, pandoc.Para({}))
    
    -- Add a section header for figures
    local figure_header = pandoc.Header(1, {pandoc.Str("Figures")})
    table.insert(doc.blocks, figure_header)
    
    -- Add all figures with just their number
    for i, fig in ipairs(figures) do
      -- Add just a label before the figure
      table.insert(doc.blocks, pandoc.Para({
        pandoc.Strong({pandoc.Str("Figure " .. tostring(i))})
      }))
      
      -- Add the figure content (the image itself)
      for _, block in ipairs(fig.content) do
        table.insert(doc.blocks, block)
      end
      
      -- Add spacing between figures
      table.insert(doc.blocks, pandoc.Para({}))
    end
  end
  
  return doc
end

-- Return the filters in the correct order
return {
  {Figure = Figure},
  {Pandoc = Pandoc}
}
