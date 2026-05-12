-- tikz-to-image.lua
-- Converts TikZ picture environments to PNG images for pandoc conversion

local function file_exists(name)
  local f = io.open(name, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

--- Create a standalone LaTeX document which contains only the TikZ picture.
--- Convert to PDF, then to PNG via ImageMagick.
local function tikz2image(src, outfile)
  local basename = outfile:gsub("%.png$", "")
  local texfile = basename .. ".tex"
  local pdffile = basename .. ".pdf"

  local f = io.open(texfile, 'w')

  -- Write standalone document with TikZ
  f:write("\\documentclass{standalone}\n")
  f:write("\\usepackage{tikz}\n")
  f:write("\\usetikzlibrary{arrows.meta, calc}\n")
  f:write("\\usepackage{graphicx}\n") -- for includegraphics
  f:write("\\begin{document}\n")
  f:write(src)
  f:write("\n\\end{document}\n")
  f:close()

  -- Compile to PDF (run from current directory so relative paths work)
  os.execute("pdflatex -interaction=batchmode " .. texfile .. " > /dev/null 2>&1")

  -- Convert PDF to PNG with high resolution
  os.execute("convert -density 300 " .. pdffile .. " " .. outfile)

  -- Clean up temporary files
  os.remove(texfile)
  os.remove(pdffile)
  os.remove(basename .. ".log")
  os.remove(basename .. ".aux")
end

function RawBlock(el)
  -- Only process LaTeX raw blocks
  if el.format ~= "latex" then
    return nil
  end

  -- Only process tikzpicture environments
  if not el.text:match('\\begin{tikzpicture}') then
    return nil
  end

  -- Generate unique filename based on content hash
  local fname = "tikz_" .. pandoc.sha1(el.text) .. ".png"

  -- Only generate image if it doesn't exist (caching)
  if not file_exists(fname) then
    io.stderr:write("Generating TikZ image: " .. fname .. "\n")
    tikz2image(el.text, fname)
  end

  -- Replace TikZ code with image
  return pandoc.Para({ pandoc.Image({}, fname) })
end
