-- fix-inner-parens.lua

local pandoc = require("pandoc")

-- helper: scan left skipping Spaces and Str "~" tokens, return true if we find a Str that ends with "("
local function scan_left_for_open_paren(inlines, idx)
	local j = idx - 1
	while j >= 1 do
		local t = inlines[j]
		if t.t == "Space" then
			j = j - 1
		elseif t.t == "Str" and t.text == "~" then
			j = j - 1
		elseif t.t == "Str" then
			return t.text:match("%($") ~= nil
		else
			return false
		end
	end
	return false
end

-- helper: scan right skipping Spaces and Str "~" tokens, return true if we find a Str that begins with ")"
local function scan_right_for_close_paren(inlines, idx)
	local k = idx + 1
	while k <= #inlines do
		local t = inlines[k]
		if t.t == "Space" then
			k = k + 1
		elseif t.t == "Str" and t.text == "~" then
			k = k + 1
		elseif t.t == "Str" then
			return t.text:match("^%)") ~= nil
		else
			return false
		end
	end
	return false
end

function remove_innermost_parens(inlines)
	local i = 1
	while i <= #inlines do
		local el = inlines[i]

		if el.t == "Cite" then
			-- use small lookaround that skips only Space and literal "~" tokens
			local left_nested = scan_left_for_open_paren(inlines, i)
			local right_nested = scan_right_for_close_paren(inlines, i)

			-- If either side is nested, remove parentheses inside citation (only on first/last token)
			if left_nested or right_nested then
				local c = el.content
				if #c >= 1 then
					local first = c[1]
					local last = c[#c]

					-- Remove leading '(' if present on the first token
					if first.t == "Str" and first.text:match("^%(") then
						first.text = first.text:gsub("^%(", "", 1)
					end
					-- Remove trailing ')' if present on the last token
					if last.t == "Str" and last.text:match("%)$") then
						last.text = last.text:gsub("%)$", "", 1)
					end
				end
			end
		end

		i = i + 1
	end
	return inlines
end

-- Apply to all paragraphs and plain blocks
local function walk_block(block)
	if block.t == "Para" or block.t == "Plain" then
		block.content = remove_innermost_parens(block.content)
	end
	return block
end

-- Return Pandoc filter
return {
	{
		Para = walk_block,
		Plain = walk_block,
	},
}
