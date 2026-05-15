return {
  {
    CodeBlock = function(cb)
      if #cb.classes == 0 then
        cb.classes:insert("r")
      end
      return cb
    end,
    Figure = function(fig)
      local code_blocks = {}
      local other_blocks = {}
      for _, b in ipairs(fig.content) do
        if b.t == "CodeBlock" then
          if #b.classes == 0 then
            b.classes:insert("r")
          end
          table.insert(code_blocks, b)
        else
          table.insert(other_blocks, b)
        end
      end
      if #code_blocks > 0 then
        fig.content = other_blocks
        local result = {}
        for _, cb in ipairs(code_blocks) do
          table.insert(result, cb)
        end
        table.insert(result, fig)
        return result
      end
      return nil
    end,
  },
}
