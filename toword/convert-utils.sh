# copy the ".tex", ".bib" and ".csl" files here and run:
# toword [-m] [-t] -i input.tex -o output.docx
# -m, --move-figures: move figures to end of document
# -t, --move-tables: move tables to end of document

toword() {
    local input=""
    local output=""
    local use_move_figures=false
    local use_move_tables=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--move-figures) use_move_figures=true; shift ;;
            -t|--move-tables) use_move_tables=true; shift ;;
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

def strip_hl_from_alltt(alltt_content):
    i = 0
    parts = []
    while i < len(alltt_content):
        m = re.match(r'\\(hl[a-z]+)\{', alltt_content[i:])
        if m:
            brace = i + m.end() - 1
            close = find_balanced(alltt_content, brace)
            if close:
                parts.append(alltt_content[brace + 1:close - 1])
                i = close
                continue
        parts.append(alltt_content[i])
        i += 1
    return ''.join(parts)

def process_alltt_environments(content):
    result = []
    pos = 0
    while True:
        start = content.find('\\begin{alltt}', pos)
        if start == -1:
            result.append(content[pos:])
            break
        result.append(content[pos:start])
        end = content.find('\\end{alltt}', start)
        if end == -1:
            result.append(content[start:])
            break
        inner = content[start + len('\\begin{alltt}'):end]
        cleaned = strip_hl_from_alltt(inner)
        result.append('\\begin{verbatim}')
        result.append(cleaned)
        result.append('\\end{verbatim}')
        pos = end + len('\\end{alltt}')
    return ''.join(result)

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    content = f.read()

# Extract title and authors for \appendixtitleblock expansion
raw_title = re.search(r'\\title\{([^}]*)\}', content)
paper_title = raw_title.group(1) if raw_title else ''

# Allow symbols like '*' in the global author scanner block
raw_authors = re.findall(r'\\author(?:\[[^\]]+\])?\{([^}]*)\}', content)
paper_authors = '; '.join(raw_authors) if raw_authors else ''

# Fix \nptextcite
content = re.sub(r'\\nptextcite\{([^}]*)\}', r'\\textcite{\1}', content)

# Fix \printbibliography to produce \section{References} for refsection filter
content = re.sub(
    r'\\printbibliography\[heading=bibnumbered,\s*title=\{References\}\]',
    r'\\section{References}\n\\printbibliography[heading=none]',
    content
)

# Fix authblk
# Allow alphanumeric and punctuation tags (like '1*') inside brackets
authblk_authors = re.findall(r'\\author\[([^\]]+)\]\{([^}]*)\}', content)
authblk_affils = re.findall(r'\\affil\[([^\]]+)\]\{([^}]*)\}', content)

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

    # Update deletion regexes to match the updated bracket wildcard
    content = re.sub(r'\\author\[[^\]]+\]\{[^}]*\}\n?', '', content)
    content = re.sub(r'\\affil\[[^\]]+\]\{[^}]*\}\n?', '', content)
    content = content.replace('\\usepackage{authblk}\n', '')
    content = content.replace('\\usepackage{authblk}', '')
    content = content.replace('\\date{\\today}\n', '')
    content = content.replace('\\date{\\today}', '')
    content = content.replace('\\maketitle', f'\\maketitle\n\n{author_block}\n\n\\vspace{{1em}}')

# Handle TikZ pictures (if present)
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

    def find_figure_label(content, tikz_start):
        fig_start = content.rfind(r'\begin{figure}', 0, tikz_start)
        if fig_start == -1:
            return None
        fig_end = content.find(r'\end{figure}', tikz_start)
        if fig_end == -1:
            return None
        label_match = re.search(
            r'\\label\{fig:([^}]*)\}', content[fig_start:fig_end]
        )
        return label_match.group(1) if label_match else None

    tikz_pattern = r'\\begin{tikzpicture}.*?\\end{tikzpicture}'
    matches = list(re.finditer(tikz_pattern, content, re.DOTALL))

    for match in reversed(matches):
        tikz_code = match.group(0)
        label = find_figure_label(content, match.start())
        if label:
            base_name = f"tikz_{re.sub(r'[^\w\\-]', '_', label)}"
        else:
            img_hash = hashlib.sha1(tikz_code.encode()).hexdigest()[:16]
            base_name = f"tikz_{img_hash}"
        pdf_name = f"{base_name}.pdf"
        svg_name = f"{base_name}.svg"

        if not os.path.exists(svg_name):
            tex_content = f"""\\documentclass{{standalone}}
\\usepackage{{tikz}}
\\usetikzlibrary{{positioning,backgrounds,arrows.meta,calc}}
{shared_styles}
\\begin{{document}}
{tikz_code}
\\end{{document}}"""

            with open(f"{base_name}.tex", 'w') as f:
                f.write(tex_content)
            subprocess.run(['pdflatex', '-interaction=batchmode', f"{base_name}.tex"],
                           stdout=subprocess.DEVNULL)
            subprocess.run(['pdftocairo', '-svg', pdf_name, svg_name],
                           stdout=subprocess.DEVNULL)
            for ext in ['.tex', '.log', '.aux']:
                try: os.remove(f"{base_name}{ext}")
                except: pass

        content = content[:match.start()] + f"\\includegraphics[width=\\textwidth]{{{svg_name}}}" + content[match.end():]

# Expand \appendixtitleblock
def expand_appendix(m):
    num = m.group(1)
    label = m.group(2)
    return ("\\begin{center}\n"
            "{\\Large\\textbf{Appendix " + num + "} \\textit{for:} " + paper_title + "}\n"
            "\n"
            "{\\large " + paper_authors + "}\n"
            "\\end{center}\n"
            "\n"
            "\\label{" + label + "}")

# Add \s* to support spaces or line breaks between \appendixtitleblock and \label
content = re.sub(
    r'\\appendixtitleblock\{(\d+)\}\s*\\label\{(\w+)\}',
    expand_appendix,
    content
)

# Strip \hlXXX commands from alltt environments and convert to verbatim
# (Pandoc does not allow \textcolor inside alltt)
content = process_alltt_environments(content)

# Strip knitr wrapper environments (no-ops in DOCX output)
content = re.sub(r'\\begin\{knitrout\}', '', content)
content = re.sub(r'\\end\{knitrout\}', '', content)
content = re.sub(r'\\begin\{kframe\}', '', content)
content = re.sub(r'\\end\{kframe\}', '', content)
# Strip knitr color commands (not meaningful in DOCX)
content = re.sub(
    r'\\definecolor\{shadecolor\}\{rgb\}\{[^}]*\}\\color\{fgcolor\}(?:\\begin\{kframe\})?',
    '',
    content
)

with open(output_file, 'w') as f:
    f.write(content)
PYTHON_SCRIPT

    local cmd=(pandoc "$processed_input")
    [ -f "zotero.bib" ] && cmd+=(--bibliography=zotero.bib)
    [ -f "packages.bib" ] && cmd+=(--bibliography=packages.bib)

    cmd+=(--lua-filter refsection-bibliographies.lua
        -csl global-ecology-and-biogeography.csl
        --lua-filter number-figures.lua
        --lua-filter number-tables.lua
        --lua-filter fix-inner-parens.lua
        --lua-filter fix-titleblock.lua
        --lua-filter code-block-lang.lua
        --highlight-style tango)

    [ "$use_move_figures" = true ] && cmd+=(--lua-filter move-figures.lua)
    [ "$use_move_tables" = true ] && cmd+=(--lua-filter move-tables.lua)
    [ -f tikz-to-image.lua ] && cmd+=(--lua-filter tikz-to-image.lua)
    cmd+=(--reference-doc=latex_word_ref.docx -o "$output")

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
        found=$(find . -maxdepth 1 \( -name 'tikz_*.png' -o -name 'tikz_*.pdf' -o -name 'tikz_*.svg' \) -print -quit)
        if [ -n "$found" ]; then
            n=0; while [ -d "$(printf "tikz_pictures_%02d" $n)" ]; do n=$((n + 1)); done
            dir="$(printf "tikz_pictures_%02d" $n)"
            mkdir -p "$dir"
            find . -maxdepth 1 \( -name 'tikz_*.png' -o -name 'tikz_*.pdf' -o -name 'tikz_*.svg' \) -exec mv {} "$dir" \;
        fi
        echo "Conversion successful!"
    else
        echo "Error: Pandoc conversion failed"; return 1
    fi
}
