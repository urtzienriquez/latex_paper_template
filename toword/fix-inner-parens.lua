-- fix-inner-parens.lua
-- After citeproc has rendered citations, find parenthetical groups
-- that contain year-parens like (2009) and strip the inner year-parens.
-- E.g.  (as said by Author (2009))  -->  (as said by Author 2009)
-- Does NOT affect standalone \textcite: Author (2009) stays as-is.

local function strip_year_parens(text)
  return text:gsub("%((%d+)%)", "%1")
end

local function process_recursive(inlines)
  for _, el in ipairs(inlines) do
    if el.t == "Str" then
      el.text = strip_year_parens(el.text)
    elseif el.t == "Span" then
      process_recursive(el.content)
    elseif el.t == "Cite" then
      process_recursive(el.content)
    end
  end
end

local function fix_inlines(inlines)
  local i = 1
  while i <= #inlines do
    local el = inlines[i]
    if el.t == "Str" and el.text:match("^%(") then
      local open_paren_count = select(2, el.text:gsub("%(", ""))
      local close_paren_count = select(2, el.text:gsub("%)", ""))
      local depth = open_paren_count - close_paren_count

      local j = i + 1
      local close_idx = nil
      while j <= #inlines do
        local e = inlines[j]
        if e.t == "Str" then
          local oc = select(2, e.text:gsub("%(", ""))
          local cc = select(2, e.text:gsub("%)", ""))
          depth = depth + oc - cc
          if depth <= 0 then
            close_idx = j
            break
          end
        end
        j = j + 1
      end

      if close_idx then
        for k = i, close_idx do
          local e = inlines[k]
          if e.t == "Str" then
            e.text = strip_year_parens(e.text)
          elseif e.t == "Span" then
            process_recursive(e.content)
          elseif e.t == "Cite" then
            process_recursive(e.content)
          end
        end
        i = close_idx
      end
    end
    i = i + 1
  end
  return inlines
end

local function walk_block(block)
  if block.t == "Para" or block.t == "Plain" then
    block.content = fix_inlines(block.content)
  end
  return block
end

return {
  {Para = walk_block, Plain = walk_block},
}
