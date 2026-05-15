# LaTeX Paper Template for Rnoweb

A reusable template for academic papers written in **Rnoweb** (`.Rnw` — mix LaTeX with R code chunks). Knitr compiles the R into LaTeX, then `latexmk` produces the PDF with bibliography.

If you use the template or the conversion utilities and find any bugs, issue reports are very welcome.

---

## Prerequisites

- LaTeX distribution with `latexmk`, `lualatex`, `biber`
- R with the `knitr` package

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

I knit the `.Rnw` to `.tex` and then run `latexmk`. I always compile via `1_index.Rnw`.

### Default output filename

The generated `.tex` file will be named `1_index.tex`:

```
R -e 'knitr::knit("1_index.Rnw"); system("latexmk -lualatex -bibtex -interaction=nonstopmode -synctex=1 -f 1_index.tex")'
```

### Custom output filename

Pass an `output` argument to `knitr::knit`:

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
toword [-m] -i input.tex -o output.docx
```

### Options

| Flag                   | Description                                          |
| ---------------------- | ---------------------------------------------------- |
| `-i`, `--input`        | Input `.tex` file                                    |
| `-o`, `--output`       | Output `.docx` file                                  |
| `-m`, `--move-figures` | Move figures to end of document (publisher-friendly) |

### What it does

The conversion runs three stages:

**1. Pre-processing (Python)** — modifies the LaTeX before Pandoc touches it:

- Reformats `\author` / `\affil` (authblk) into plain text
- Converts TikZ pictures to PNG images
- Expands `\appendixtitleblock` with paper title and authors
- Strips knitr wrapper environments (`knitrout`, `kframe`)
- Replaces `alltt` environments with `verbatim` (Pandoc doesn't support `\hl` commands inside `alltt`)
- Fixes `\nptextcite` → `\textcite`

**2. Pandoc conversion** — uses these filters and settings:

| Component       | Detail                                                                                                                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Bibliography    | Loads `zotero.bib` and `packages.bib` if present                                                                                                                                                 |
| CSL style       | `global-ecology-and-biogeography.csl`                                                                                                                                                            |
| Lua filters     | `refsection-bibliographies.lua`, `number-figures.lua`, `fix-inner-parens.lua`, `fix-titleblock.lua`, `code-block-lang.lua`, `tikz-to-image.lua` (if exists), `move-figures.lua` (only with `-m`) |
| Highlight style | tango                                                                                                                                                                                            |
| Reference doc   | `latex7.dotx` (provides the base DOCX styling)                                                                                                                                                   |

**3. Post-processing (Python)** — patches the DOCX XML:

- Centers the title paragraph; left-aligns the author paragraph
- Sets `Free Mono` as monospace font for code blocks
