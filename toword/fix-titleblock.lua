-- fix-titleblock.lua
-- Reorder title, author, abstract, and keywords before Introduction.
-- Handles both rmarkdown (macro-based title run) and knitr (metadata-only) output.

local utils = require("pandoc.utils")
local TITLE_MACRO_PATTERN = "\\%w+titleblock"

local function text_of(x)
	return utils.stringify(x or "")
end

local function contains_title_macro(block)
	if not block then
		return false
	end
	if block.t == "RawBlock" and (block.format == "latex" or block.format == "tex") then
		if block.text:match(TITLE_MACRO_PATTERN) then
			return true
		end
	end
	if (block.t == "Para" or block.t == "Plain") and block.content then
		for _, inl in ipairs(block.content) do
			if inl.t == "RawInline" and (inl.format == "latex" or inl.format == "tex") then
				if inl.text:match(TITLE_MACRO_PATTERN) then
					return true
				end
			end
			if inl.t == "Str" and inl.text:match(TITLE_MACRO_PATTERN) then
				return true
			end
		end
	end
	return false
end

local function is_introduction_header(block)
	if block.t == "Header" then
		local htxt = text_of(block)
		if htxt and htxt:match("^%s*[Ii]ntroduction%s*$") then
			return true
		end
	end
	return false
end

local function expand_title_run(blocks, i)
	local n = #blocks
	local s, e = i, i
	while s > 1 do
		local prev = blocks[s - 1]
		local len = (#text_of(prev))
		if prev.t == "RawBlock" or len < 200 then
			s = s - 1
		else
			break
		end
	end
	while e < n do
		local nxt = blocks[e + 1]
		local len = (#text_of(nxt))
		if nxt.t == "RawBlock" or (len < 400 and not is_introduction_header(nxt)) then
			e = e + 1
		else
			break
		end
	end
	return s, e
end

local function is_keywords_para(block)
	if block.t == "Para" or block.t == "Plain" then
		local txt = text_of(block):lower()
		if txt:match("^%s*keywords%s*:") or txt:match("^%*%*keywords") then
			return true
		end
	end
	return false
end

-- Build abstract-only block from metadata, preserving inline elements
-- so that cross-reference Links survive intact.
local function build_abstract_from_meta(meta)
	local blocks = {}
	if meta and meta.abstract then
		local abs_blocks = meta.abstract
		if abs_blocks and #abs_blocks > 0 then
			local has_text = false
			for _, blk in ipairs(abs_blocks) do
				if blk.t == "Para" or blk.t == "Plain" then
					local txt = text_of(blk)
					if txt:match("%S") then
						has_text = true
						break
					end
				end
			end
			if has_text then
				table.insert(blocks, pandoc.Para({ pandoc.Strong({ pandoc.Str("Abstract:") }) }))
				for _, blk in ipairs(abs_blocks) do
					table.insert(blocks, blk)
				end
			end
		end
		meta.abstract = nil
	end
	return blocks
end

-- Resolve \ref cross-references inside abstract blocks using the document's
-- figure/table identifier map.
local function resolve_refs_in_blocks(blocks, ref_map)
	for _, blk in ipairs(blocks) do
		if blk.t == "Para" or blk.t == "Plain" then
			for j, inl in ipairs(blk.content) do
				if inl.t == "Link" and inl.attributes then
					local ref_id = inl.attributes["reference"]
					if ref_id and ref_map[ref_id] then
						blk.content[j] = pandoc.Str(tostring(ref_map[ref_id]))
					end
				end
			end
		end
	end
end

function Pandoc(doc)
	local blocks = doc.blocks
	local n = #blocks

	-- find Introduction
	local intro_idx
	for i = 1, n do
		if is_introduction_header(blocks[i]) then
			intro_idx = i
			break
		end
	end
	if not intro_idx then
		return doc
	end

	-- find title run (rmarkdown compat)
	local title_run_start, title_run_end
	for i = 1, n do
		if contains_title_macro(blocks[i]) then
			title_run_start, title_run_end = expand_title_run(blocks, i)
			break
		end
	end

	-- find keywords
	local keywords_idx
	for i = 1, n do
		if is_keywords_para(blocks[i]) then
			keywords_idx = i
			break
		end
	end

	-- build figure/table reference map
	local ref_map = {}
	local fig_num = 0
	local tbl_num = 0
	for _, blk in ipairs(blocks) do
		if blk.t == "Figure" then
			fig_num = fig_num + 1
			ref_map[blk.identifier] = fig_num
		elseif blk.t == "Table" then
			tbl_num = tbl_num + 1
			ref_map[blk.identifier] = tbl_num
		end
	end

	-- collect title blocks
	local title_blocks = {}
	if title_run_start then
		for k = title_run_start, title_run_end - 1 do
			table.insert(title_blocks, blocks[k])
		end
	end

	-- collect abstract
	local abs_blocks = {}
	if title_run_start then
		-- rmarkdown: use abstract from metadata
		abs_blocks = build_abstract_from_meta(doc.meta)
	else
		-- knitr: build abstract from metadata (title/author handled by ref doc)
		abs_blocks = build_abstract_from_meta(doc.meta)
	end

	-- resolve cross-refs in abstract blocks
	resolve_refs_in_blocks(abs_blocks, ref_map)

	-- extract keywords block
	local keywords_block
	if keywords_idx then
		keywords_block = blocks[keywords_idx]
	end

	-- rebuild
	local newblocks = {}
	for i = 1, n do
		if i == intro_idx then
			for _, b in ipairs(title_blocks) do
				table.insert(newblocks, b)
			end
			for _, b in ipairs(abs_blocks) do
				table.insert(newblocks, b)
			end
			if keywords_block then
				table.insert(newblocks, keywords_block)
			end
			table.insert(newblocks, blocks[i])
		elseif
			not (
				(title_run_start and i >= title_run_start and i <= title_run_end)
				or (keywords_idx and i == keywords_idx)
			)
		then
			table.insert(newblocks, blocks[i])
		end
	end

	doc.blocks = newblocks
	return doc
end
