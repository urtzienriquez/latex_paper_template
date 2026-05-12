-- number-figures.lua
-- Prepends "Figure N: " to each figure caption

local fig_num = 0

function Figure(fig)
  fig_num = fig_num + 1
  local prefix = pandoc.Str("Figure " .. fig_num .. ": ")
  for _, block in ipairs(fig.caption.long) do
    if block.content then
      table.insert(block.content, 1, prefix)
      break
    end
  end
  return fig
end
