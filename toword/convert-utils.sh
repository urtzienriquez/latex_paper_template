# copy the ".tex", ".bib" and ".csl" files here and run:
# toword [-m] -i input.tex -o output.docx

toword() {
    local input=""
    local output=""
    local use_move_figures=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--move-figures) use_move_figures=true; shift ;;
            -i|--input) input="$2"; shift 2 ;;
            -o|--output) output="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done
    
    if [ -z "$input" ] || [ -z "$output" ]; then
        echo "Error: Both input and output files are required"; return 1
    fi

    local processed_input="${input%.tex}_processed.tex"
    
    echo "Pre-processing LaTeX..."
    python3 - <<'PYTHON_SCRIPT' "$input" "$processed_input"
import sys, re, hashlib, os, subprocess

def find_balanced(text, start_index):
    count = 0
    for i in range(text.find('{', start_index), len(text)):
        if text[i] == '{': count += 1
        elif text[i] == '}': count -= 1
        if count == 0: return i + 1
    return None

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    content = f.read()

# --- 1. Fix \nptextcite ---
content = re.sub(r'\\nptextcite\{([^}]*)\}', r'\\textcite{\1}', content)

# --- 2. Fix authblk ---
authblk_authors = re.findall(r'\\author\[([\d,]+)\]\{([^}]*)\}', content)
authblk_affils = re.findall(r'\\affil\[([\d,]+)\]\{([^}]*)\}', content)

if authblk_authors:
    author_names = []
    for num, name in authblk_authors:
        author_names.append(f"{name}\\textsuperscript{{{num}}}")

    if len(author_names) == 1:
        author_str = author_names[0]
    elif len(author_names) == 2:
        author_str = " and ".join(author_names)
    else:
        author_str = ", ".join(author_names[:-1]) + " \\& " + author_names[-1]

    affil_lines = []
    for num, affil in authblk_affils:
        affil_lines.append(f"\\textsuperscript{{{num}}} {affil}")
    affil_str = "\\\\".join(affil_lines)

    author_block = f"\\begin{{center}}{author_str}\\end{{center}}\n\\begin{{flushleft}}{affil_str}\\end{{flushleft}}"

    content = re.sub(r'\\author\[[\d,]+\]\{[^}]*\}\n?', '', content)
    content = re.sub(r'\\affil\[[\d,]+\]\{[^}]*\}\n?', '', content)
    content = content.replace('\\usepackage{authblk}\n', '')
    content = content.replace('\\usepackage{authblk}', '')
    content = content.replace('\\date{\\today}\n', '')
    content = content.replace('\\date{\\today}', '')
    content = content.replace('\\maketitle', f'\\maketitle\n\n{author_block}\n\n\\vspace{{1em}}')

# --- 3. Handle TikZ pictures (if present) ---
if '\\begin{tikzpicture}' in content:
    print("TikZ code detected - preprocessing...")

    libraries = "\n".join(re.findall(r'\\usetikzlibrary\{.*?\}', content, re.DOTALL))
    tikzsets = []
    search_pos = 0
    while True:
        match = re.search(r'\\tikzset', content[search_pos:])
        if not match: break
        end = find_balanced(content, search_pos + match.start())
        if end:
            tikzsets.append(content[search_pos + match.start():end])
            search_pos = end
        else: search_pos += 7
    shared_styles = libraries + "\n" + "\n".join(tikzsets)

    tikz_pattern = r'\\begin{tikzpicture}.*?\\end{tikzpicture}'
    matches = list(re.finditer(tikz_pattern, content, re.DOTALL))

    for match in reversed(matches):
        tikz_code = match.group(0)
        img_hash = hashlib.sha1(tikz_code.encode()).hexdigest()[:16]
        img_name = f"tikz_{img_hash}.png"

        if not os.path.exists(img_name):
            tex_content = f"""\\documentclass{{standalone}}
\\usepackage{{tikz}}
\\usetikzlibrary{{positioning,backgrounds,arrows.meta,calc}}
{shared_styles}
\\begin{{document}}
{tikz_code}
\\end{{document}}"""

            base_name = img_name[:-4]
            with open(f"{base_name}.tex", 'w') as f:
                f.write(tex_content)
            subprocess.run(['pdflatex', '-interaction=batchmode', f"{base_name}.tex"],
                           stdout=subprocess.DEVNULL)
            subprocess.run(['convert', '-density', '300', f"{base_name}.pdf", img_name],
                           stdout=subprocess.DEVNULL)
            for ext in ['.tex', '.pdf', '.log', '.aux']:
                try: os.remove(f"{base_name}{ext}")
                except: pass

        content = content[:match.start()] + f"\\includegraphics{{{img_name}}}" + content[match.end():]

with open(output_file, 'w') as f:
    f.write(content)
PYTHON_SCRIPT

    local cmd=(pandoc "$processed_input" --citeproc)
    [ -f "zotero.bib" ] && cmd+=(--bibliography=zotero.bib)
    [ -f "packages.bib" ] && cmd+=(--bibliography=packages.bib)

    cmd+=(-csl global-ecology-and-biogeography.csl
        --lua-filter number-figures.lua
        --lua-filter fix-inner-parens.lua
        --lua-filter fix-titleblock.lua)

    [ "$use_move_figures" = true ] && cmd+=(--lua-filter move-figures.lua)
    [ -f tikz-to-image.lua ] && cmd+=(--lua-filter tikz-to-image.lua)
    cmd+=(--reference-doc=latex7.dotx -o "$output")

    "${cmd[@]}"
    local exit_code=$?

    rm -f "$processed_input"

    if [ $exit_code -eq 0 ]; then
        python3 - <<'PYTHON_POST' "$output"
import sys, zipfile, os, shutil, tempfile, xml.etree.ElementTree as ET

docx_path = sys.argv[1]
w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
ET.register_namespace('w', w)

tmpdir = tempfile.mkdtemp()
with zipfile.ZipFile(docx_path, 'r') as z:
    z.extractall(tmpdir)

doc_path = os.path.join(tmpdir, 'word', 'document.xml')
tree = ET.parse(doc_path)
root = tree.getroot()

paras = root.findall(f'.//{{{w}}}p')
super_count = 0
for p in paras:
    has_super = len(p.findall(f'.//{{{w}}}vertAlign')) > 0
    if not has_super:
        continue
    super_count += 1
    pPr = p.find(f'{{{w}}}pPr')
    if pPr is None:
        pPr = ET.SubElement(p, f'{{{w}}}pPr')
        p.insert(0, pPr)
    jc = pPr.find(f'{{{w}}}jc')
    if jc is None:
        jc = ET.SubElement(pPr, f'{{{w}}}jc')
    if super_count == 1:
        jc.set(f'{{{w}}}val', 'center')
    elif super_count == 2:
        jc.set(f'{{{w}}}val', 'left')

tree.write(doc_path, xml_declaration=True, encoding='UTF-8')

with zipfile.ZipFile(docx_path, 'w', zipfile.ZIP_DEFLATED) as zout:
    for dirpath, _, filenames in os.walk(tmpdir):
        for fn in filenames:
            fpath = os.path.join(dirpath, fn)
            arcname = os.path.relpath(fpath, tmpdir)
            zout.write(fpath, arcname)

shutil.rmtree(tmpdir)
PYTHON_POST
        find . -maxdepth 1 -name 'tikz_*.png' -delete -o -name 'tikz_*.pdf' -delete 2>/dev/null
        echo "Conversion successful!"
    else
        echo "Error: Pandoc conversion failed"; return 1
    fi
}
