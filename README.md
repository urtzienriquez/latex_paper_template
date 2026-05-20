# LaTeX Paper Template for Rnoweb

A reusable template for academic papers written in **Rnoweb** (`.Rnw` — mix LaTeX with R code chunks). Works with either **knitrmini** (out-of-the-box) or **knitr** (requires additional setup snippets, documented below).

If you use the template or the conversion utilities and find any bugs, issue reports are very welcome.

---

## Prerequisites

- LaTeX distribution with `latexmk`, `lualatex`, `biber`
- `pdftocairo` (from poppler-utils) — used to convert TikZ PDF output to SVG
- R with the `knitrmini` package (or `knitr` — see [Compiling](#compiling) for setup differences)

## Project structure

```
├── 00_preamble.tex       Packages, settings, preamble
├── 01_titlepage.tex      Title, authors, affiliations
├── 1_index.Rnw           Main file — knit this to compile
├── 2_main.Rnw            Main body
├── 3_appendix1.Rnw       Appendix 1
├── 4_appendix2.Rnw       Appendix 2
└── toword/               LaTeX → DOCX conversion (see below)
```

---

## Compiling

### Using knitrmini

The template works out-of-the-box with knitrmini. It knits to `.tex` and compiles to PDF in one call.

```r
R -e 'knitrmini::opts_knit$set(engine = "lualatex"); knitrmini::knit("1_index.Rnw")'
```

### Using knitr

The template is configured for knitrmini by default. To use the original **knitr** package instead, you need to add two code snippets.

**1. Add to `00_preamble.tex`** (after `\usepackage{listings}`):

```latex
\usepackage{alltt}
\usepackage{framed}
\usepackage{etoolbox}

% knitr code block customizations
\definecolor{fgcolor}{rgb}{0.000, 0.000, 0.000}
\definecolor{shadecolor}{rgb}{0.969, 0.969, 0.969}
\definecolor{messagecolor}{rgb}{0, 0, 0}
\definecolor{warningcolor}{rgb}{1, 0, 1}
\definecolor{errorcolor}{rgb}{1, 0, 0}

\newenvironment{knitrout}{}{}
\newenvironment{kframe}{}{}

\BeforeBeginEnvironment{alltt}{\begin{snugshade}}
    \AfterEndEnvironment{alltt}{\end{snugshade}}

\newcommand{\hlnum}[1]{\textcolor[rgb]{0.000,0.000,0.812}{#1}}
\newcommand{\hlstr}[1]{\textcolor[rgb]{0.306,0.604,0.024}{#1}}
\newcommand{\hlsng}[1]{\textcolor[rgb]{0.306,0.604,0.024}{#1}}
\newcommand{\hlcom}[1]{\textcolor[rgb]{0.561,0.349,0.008}{\textit{#1}}}
\newcommand{\hlopt}[1]{\textcolor[rgb]{0.808,0.361,0.000}{\textbf{#1}}}
\newcommand{\hlstd}[1]{\textcolor[rgb]{0.000,0.000,0.000}{#1}}
\newcommand{\hldef}[1]{\textcolor[rgb]{0.000,0.000,0.000}{#1}}
\newcommand{\hlkwd}[1]{\textcolor[rgb]{0.125,0.290,0.529}{\textbf{#1}}}
\newcommand{\hlkwc}[1]{\textcolor[rgb]{0.561,0.349,0.008}{#1}}
\newcommand{\hlkwa}[1]{\textcolor[rgb]{0.125,0.290,0.529}{\textbf{#1}}}
\newcommand{\hlkwb}[1]{\textcolor[rgb]{0.561,0.349,0.008}{#1}}
\newcommand{\hlkwr}[1]{\textcolor[rgb]{0.647,0.000,0.000}{\textbf{#1}}}
```

**2. Replace the setup chunk in `1_index.Rnw`** with:

```r
<<label=setup, echo=FALSE, message=FALSE, warning=FALSE>>=
knitr::opts_chunk$set(
  echo = FALSE,
  message = FALSE,
  warning = FALSE,
  fig.width = 6,
  fig.height = 4,
  fig.align = "center",
  fig.pos = "!htb",
  fig.path = file.path(getwd(), "figures/")
)

knitr::knit_hooks$set(document = function(x) {
  full_text <- paste(x, collapse = "\n")
  if (file.exists("00_preamble.tex")) {
    preamble_text <- paste(readLines("00_preamble.tex"), collapse = "\n")
    if (file.exists("01_titlepage.tex")) {
      title_text <- paste(readLines("01_titlepage.tex"), collapse = "\n")
      title_text_escaped <- gsub("\\\\", "\\\\\\\\", title_text)
      preamble_text <- gsub("\\\\(input|include)\\{01_titlepage(\\.tex)?\\}", title_text_escaped, preamble_text)
    }
    preamble_text_escaped <- gsub("\\\\", "\\\\\\\\", preamble_text)
    full_text <- gsub("\\\\input\\{00_preamble(\\.tex)?\\}", preamble_text_escaped, full_text)
  }
  full_text <- gsub("\\\\newif\\\\iftexlab[\\s\\S]*?\\\\fi", "", full_text, perl = TRUE)
  full_text
})
@
```

Then compile with knitr:

```
R -e 'knitr::knit("1_index.Rnw"); system("latexmk -lualatex -bibtex -interaction=nonstopmode -synctex=1 -f 1_index.tex")'
```

For a custom output name:

```
R -e 'knitr::knit("1_index.Rnw", output = "my_paper.tex"); system("latexmk -lualatex -bibtex -interaction=nonstopmode -synctex=1 -f my_paper.tex")'
```

---

## Cleaning

I don't clean during work — auxiliary files make recompilation much faster. I only clean at the end.

### Standard clean (keeps PDF)

```
latexmk -c 1_index.tex
```

### Thorough clean (keeps PDF)

`latexmk -c` misses some files. I also remove these:

```
rm -f 1_index.{aux,bcf,run.xml,log,listing,out,toc,nav,snm,vrb,fls,fdb_latexmk,blg,bbl,synctex.gz} 1_index-tikzDictionary
```

### Full clean (removes PDF too)

```
latexmk -C 1_index.tex
```

---

## Word conversion (toword)

The `toword/` directory converts the compiled LaTeX to `.docx` using Pandoc with several Lua filters and post-processing steps.

### Setup

Copy your `.tex`, `.bib`, and `.csl` files into the `toword/` directory, then run:

```
toword [-m] [-t] -i input.tex -o output.docx
```

### Options

| Flag                   | Description                                          |
| ---------------------- | ---------------------------------------------------- |
| `-i`, `--input`        | Input `.tex` file                                    |
| `-o`, `--output`       | Output `.docx` file                                  |
| `-m`, `--move-figures` | Move figures to end of document (publisher-friendly) |
| `-t`, `--move-tables`  | Move tables to end of document (publisher-friendly)  |

### What it does

The conversion runs three stages:

**1. Pre-processing (Python)** — modifies the LaTeX before Pandoc touches it:

- Reformats `\author` / `\affil` (authblk) into plain text
- Converts TikZ pictures to SVG images (via `pdflatex` + `pdftocairo`); images are named after their `\label{fig:...}` when available, falling back to a content hash
- Expands `\appendixtitleblock` with paper title and authors
- Converts `\printbibliography[heading=bibnumbered, title={References}]` to a plain `\section{References}` (needed for the `refsection-bibliographies.lua` filter)
- Strips knitr wrapper environments (`knitrout`, `kframe`) — only needed when compiling with knitr, no-ops with knitrmini
- Converts knitrmini `Shaded`/`Highlighting` code blocks to `verbatim` with `\hl` commands stripped — no-ops with knitr
- Replaces `alltt` environments with `verbatim` (Pandoc doesn't support `\hl` commands inside `alltt`) — only needed when compiling with knitr, no-ops with knitrmini
- Fixes `\nptextcite` → `\textcite`

**2. Pandoc conversion** — uses these filters and settings:

| Component       | Detail                                                                                                                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Bibliography    | Loads `zotero.bib` and `packages.bib` if present                                                                                                                                                 |
| CSL style       | `global-ecology-and-biogeography.csl`                                                                                                                                                            |
| Lua filters     | `refsection-bibliographies.lua`, `number-figures.lua`, `number-tables.lua`, `fix-inner-parens.lua`, `fix-titleblock.lua`, `code-block-lang.lua`, `tikz-to-image.lua` (if exists), `move-figures.lua` (only with `-m`), `move-tables.lua` (only with `-t`) |
| Highlight style | tango                                                                                                                                                                                            |
| Reference doc   | `latex_word_ref.docx` (provides the base DOCX styling)           |

**3. Post-processing (Python)** — patches the DOCX XML:

- Centers the title paragraph; left-aligns the author paragraph
- Sets `Free Mono` as monospace font for code blocks
