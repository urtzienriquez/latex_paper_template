--- refsection-bibliographies.lua
--- Insert a bibliography where a section named "References" appears.
PANDOC_VERSION:must_be_at_least({ 2, 19, 1 })
local utils = require("pandoc.utils")
local citeproc = utils.citeproc
-- Deep copy helper
local function deepcopy(x)
	if type(x) ~= "table" then
		return x
	end
	local y = {}
	for k, v in pairs(x) do
		y[k] = deepcopy(v)
	end
	return y
end
return {
	{
		Pandoc = function(doc)
			local meta = doc.meta
			if not meta.bibliography and not meta.references then
				io.stderr:write("[refsection-bibliographies] no bibliography found\n")
				return doc
			end
			-- Load all references
			local all_refs = utils.references(doc)
			if not next(all_refs) then
				return doc
			end
			local new_blocks = pandoc.List()
			local current_chunk = pandoc.List()
			for _, blk in ipairs(doc.blocks) do
				if
					blk.t == "Header"
					and (
						(blk.identifier == "references")
						or (pandoc.utils.stringify(blk.content):lower() == "references")
					)
				then
					-- Process all blocks up to this header
					local section_meta = deepcopy(meta)
					section_meta.references = deepcopy(all_refs)
					local processed = citeproc(pandoc.Pandoc(current_chunk, section_meta))

					-- Separate bibliography from other blocks
					local bibliography = nil
					local non_bib_blocks = pandoc.List()
					for _, pb in ipairs(processed.blocks) do
						if pb.t == "Div" and pb.classes:includes("references") then
							bibliography = pb
						else
							non_bib_blocks:insert(pb)
						end
					end

					-- Add non-bibliography blocks, then header, then bibliography
					new_blocks:extend(non_bib_blocks)
					new_blocks:insert(blk)
					if bibliography then
						new_blocks:insert(bibliography)
					end

					-- Clear chunk for next section
					current_chunk = pandoc.List()
				else
					current_chunk:insert(blk)
				end
			end
			-- Process any remaining blocks after the last References section
			if #current_chunk > 0 then
				local section_meta = deepcopy(meta)
				section_meta.references = deepcopy(all_refs)
				local processed = citeproc(pandoc.Pandoc(current_chunk, section_meta))
				new_blocks:extend(processed.blocks)
			end
			return pandoc.Pandoc(new_blocks, meta)
		end,
	},
}
