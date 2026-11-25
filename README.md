# LaTeX Paper Template for Rnoweb

A reusable template for academic papers written in **Rnoweb** (`.Rnw` — mix LaTeX with R code chunks). Works with either **knitrmini** (out-of-the-box) or **knitr** (requires additional setup snippets, documented below).

It is made for [manuscript.nvim](https://github.com/urtzienriquez/manuscript.nvim), which builds it,
exports it to Word and back, and makes the files a journal asks for (anonymous or not), but it
compiles by hand too. If you use the template and find any bugs, issue reports are very welcome.

---

## Prerequisites

- LaTeX distribution with `latexmk`, `pdflatex` (or `lualatex`: both work; pdfLaTeX is ~20% faster), `biber`
- R with the `knitrmini` package (or `knitr` — see [Compiling](#compiling) for setup differences)

## Project structure

```
├── 00_preamble.tex       Packages, settings, preamble (and the switches of the variants)
├── 01_metadata.tex       Title, authors and affiliations (the authors: left out of an anonymous version)
├── 1_index.Rnw           Main file — knit this to compile
├── 2_main.Rnw            Main body
├── 3_appendix1.Rnw       Appendix 1
├── 4_appendix2.Rnw       Appendix 2
├── title_page.tex        The title page, for journals that ask for it apart (a document of its own)
├── cover_letter.tex      The cover letter (a document of its own)
└── .manuscript.lua       manuscript.nvim's options for this paper: a journal's variant
```

---

## With manuscript.nvim

`:Manuscript new latex_paper_template paper` makes a paper from this template (with
`templates = "~/Templates"` in its setup). Then, from any of its files:

| Command | |
| --- | --- |
| `:Manuscript build` | the PDF of the part you are in (`main.pdf`), or of the whole |
| `:Manuscript build anon` | the same, anonymous (`main-anon.pdf`); `review`: line numbers, double spacing |
| `:Manuscript export` / `merge` | Word files for your collaborators, and their edits back |
| `:Manuscript submit geb` | the files for a journal: PDFs, and a zip of the LaTeX that compiles them |
| `:Manuscript diff @geb` | the tracked changes since that submission |
| `:Manuscript respond` | the response to the reviewers, from their comments |

The switches (`\ifanonymous`, `\iflinenumbers`, `\ifdoublespacing`, `\iffiguresatend`,
`\ifdraftversion`) are set by the variant a build is made with, and are all off when the paper is
compiled by hand. A journal's variant goes in `.manuscript.lua`:

```lua
return {
  variants = {
    geb = { anonymous = true, linenumbers = true, doublespacing = true },
  },
}
```

## Compiling by hand

### Using knitrmini

The template works out-of-the-box with knitrmini. It knits to `.tex` and compiles to PDF in one call.

```r
R -e 'knitrmini::knit("1_index.Rnw", engine = "pdflatex")'
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
    for (part in c("01_metadata")) {
      if (file.exists(paste0(part, ".tex"))) {
        part_text <- paste(readLines(paste0(part, ".tex")), collapse = "\n")
        part_text_escaped <- gsub("\\\\", "\\\\\\\\", part_text)
        preamble_text <- gsub(paste0("\\\\(input|include)\\{", part, "(\\.tex)?\\}"), part_text_escaped, preamble_text)
      }
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
R -e 'knitr::knit("1_index.Rnw"); system("latexmk -pdf -bibtex -interaction=nonstopmode -synctex=1 -f 1_index.tex")'
```

For a custom output name:

```
R -e 'knitr::knit("1_index.Rnw", output = "my_paper.tex"); system("latexmk -pdf -bibtex -interaction=nonstopmode -synctex=1 -f my_paper.tex")'
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
