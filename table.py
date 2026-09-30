#!/usr/bin/env python3

import os
import sys
import csv
import math
import subprocess
import numpy as np
from pathlib import Path
from scipy.stats import wilcoxon

if len(sys.argv) < 3:
    print("Usage: ./table.py ALG1 ALG2 [DIM=30]")
    sys.exit(1)

alg1 = sys.argv[1]
alg2 = sys.argv[2]
dim = int(sys.argv[3]) if len(sys.argv) > 3 else 30

def read_runs(alg, f_id):
    """Read full 25 RUNS for a given algorithm and function"""
    file_path = Path(f"data/{alg}/N/N{f_id}-D{dim}")
    values = []
    if not file_path.exists():
        raise FileNotFoundError(f"{file_path} not found")
    with open(file_path, newline='') as f:
        reader = csv.reader(f)
        for row in reader:
            values.append(float(row[0]))
    return values

def latex_escape(s):
    return s.replace('_', r'\_').replace('&', r'\&')

# Counters for bolds
bold_count1 = 0
bold_count2 = 0

# --- generate LaTeX table ---
tex = r"""
\documentclass{article}
\usepackage{geometry}
\geometry{margin=0.5in}
\begin{document}

\begin{table}[ht]
\centering
\small
\begin{tabular}{|c|ccc|ccc|c|c|}
\hline
F & \multicolumn{3}{c|}{\texttt{""" + latex_escape(alg1) + r"""}} & \multicolumn{3}{c|}{\texttt{""" + latex_escape(alg2) + r"""}} & $p$ & $\log_{10}(p)$ \\
 & 10\% & 50\% & 90\% & 10\% & 50\% & 90\% & & \\
\hline
"""

# --- setup Markdown table ---
md_rows = []
md_rows.append(f"| F | {alg1} (10%) | {alg1} (50%) | {alg1} (90%) | {alg2} (10%) | {alg2} (50%) | {alg2} (90%) | p | log10(p) |")
md_rows.append("|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|")

for f_id in range(1, 30):  # functions 1..29
    # Read full runs
    runs1 = read_runs(alg1, f_id)
    runs2 = read_runs(alg2, f_id)

    # Compute quantiles (10%, 50% median, 90%)
    q1_10, q1_50, q1_90 = np.quantile(runs1, [0.1, 0.5, 0.9])
    q2_10, q2_50, q2_90 = np.quantile(runs2, [0.1, 0.5, 0.9])

    # Wilcoxon test
    try:
        stat, p = wilcoxon(runs1, runs2)
        if p == 0 or math.isnan(p):
            p_val_raw = "1.00"
            log_p_val_raw = "0.0"
            bold_row = False
        else:
            if p < 0.01:
                p_val_raw = f"{p:.2e}"
            else:
                p_val_raw = f"{p:.2f}"
            
            log_p = math.log10(p)
            log_p_val_raw = f"{log_p:.1f}"
            bold_row = p <= 0.05
    except ValueError:
        # Identical runs case
        p_val_raw = "1.00"
        log_p_val_raw = "0.0"
        bold_row = False

    # Format p-values
    if bold_row:
        p_str_tex = r"$\textbf{" + p_val_raw + r"}$"
        log_p_str_tex = r"$\textbf{" + log_p_val_raw + r"}$"
        p_str_md = f"**{p_val_raw}**"
        log_p_str_md = f"**{log_p_val_raw}**"
    else:
        p_str_tex = f"${p_val_raw}$"
        log_p_str_tex = f"${log_p_val_raw}$"
        p_str_md = p_val_raw
        log_p_str_md = log_p_val_raw

    # Raw display strings
    q1_10_d, q1_50_d, q1_90_d = f"{q1_10:.1e}", f"{q1_50:.1e}", f"{q1_90:.1e}"
    q2_10_d, q2_50_d, q2_90_d = f"{q2_10:.1e}", f"{q2_50:.1e}", f"{q2_90:.1e}"

    # Bold logic
    if bold_row:
        if q1_50 == q2_50:
            # LaTeX
            q1_10_tex, q1_50_tex, q1_90_tex = f"\\textbf{{{q1_10_d}}}", f"\\textbf{{{q1_50_d}}}", f"\\textbf{{{q1_90_d}}}"
            q2_10_tex, q2_50_tex, q2_90_tex = f"\\textbf{{{q2_10_d}}}", f"\\textbf{{{q2_50_d}}}", f"\\textbf{{{q2_90_d}}}"
            # Markdown
            q1_10_md, q1_50_md, q1_90_md = f"**{q1_10_d}**", f"**{q1_50_d}**", f"**{q1_90_d}**"
            q2_10_md, q2_50_md, q2_90_md = f"**{q2_10_d}**", f"**{q2_50_d}**", f"**{q2_90_d}**"
            
            bold_count1 += 1
            bold_count2 += 1
        elif q1_50 < q2_50:
            # LaTeX
            q1_10_tex, q1_50_tex, q1_90_tex = f"\\textbf{{{q1_10_d}}}", f"\\textbf{{{q1_50_d}}}", f"\\textbf{{{q1_90_d}}}"
            q2_10_tex, q2_50_tex, q2_90_tex = q2_10_d, q2_50_d, q2_90_d
            # Markdown
            q1_10_md, q1_50_md, q1_90_md = f"**{q1_10_d}**", f"**{q1_50_d}**", f"**{q1_90_d}**"
            q2_10_md, q2_50_md, q2_90_md = q2_10_d, q2_50_d, q2_90_d

            bold_count1 += 1
        else:
            # LaTeX
            q1_10_tex, q1_50_tex, q1_90_tex = q1_10_d, q1_50_d, q1_90_d
            q2_10_tex, q2_50_tex, q2_90_tex = f"\\textbf{{{q2_10_d}}}", f"\\textbf{{{q2_50_d}}}", f"\\textbf{{{q2_90_d}}}"
            # Markdown
            q1_10_md, q1_50_md, q1_90_md = q1_10_d, q1_50_d, q1_90_d
            q2_10_md, q2_50_md, q2_90_md = f"**{q2_10_d}**", f"**{q2_50_d}**", f"**{q2_90_d}**"

            bold_count2 += 1
    else:
        q1_10_tex, q1_50_tex, q1_90_tex = q1_10_d, q1_50_d, q1_90_d
        q2_10_tex, q2_50_tex, q2_90_tex = q2_10_d, q2_50_d, q2_90_d
        q1_10_md, q1_50_md, q1_90_md = q1_10_d, q1_50_d, q1_90_d
        q2_10_md, q2_50_md, q2_90_md = q2_10_d, q2_50_d, q2_90_d

    # Append LaTeX row
    tex += (
        f"{f_id} & {q1_10_tex} & {q1_50_tex} & {q1_90_tex} & "
        f"{q2_10_tex} & {q2_50_tex} & {q2_90_tex} & "
        f"{p_str_tex} & {log_p_str_tex} \\\\\n"
    )

    # Append Markdown row
    md_rows.append(
        f"| {f_id} | {q1_10_md} | {q1_50_md} | {q1_90_md} | "
        f"{q2_10_md} | {q2_50_md} | {q2_90_md} | "
        f"{p_str_md} | {log_p_str_md} |"
    )

# Add final "Better" row to LaTeX
tex += r"\hline" + "\n"
tex += f"Better & \\multicolumn{{3}}{{c|}}{{{bold_count1}}} & \\multicolumn{{3}}{{c|}}{{{bold_count2}}} & & \\\\\n"
tex += r"\hline" + "\n"

tex += r"""
\end{tabular}
\end{table}

\end{document}
"""

# Add final "Better" row to Markdown
md_rows.append(f"| **Better** | <span colspan=\"3\">**{bold_count1}**</span> | | | <span colspan=\"3\">**{bold_count2}**</span> | | | | |")

# --- Save TeX and Compile PDF ---
Path("tex").mkdir(exist_ok=True)
tex_file = Path("tex/table.tex")
tex_file.write_text(tex)

subprocess.run(["pdflatex", "-interaction=nonstopmode", "-output-directory=tex", "tex/table.tex"])
pdf_filename = f"{alg1}_vs_{alg2}_{dim}d.pdf"
os.rename('tex/table.pdf', f'{pdf_filename}')

# --- Save Markdown file exclusively to md_filename ---
md_filename = f"{alg1}_vs_{alg2}_{dim}d.md"
md_content = "\n".join(md_rows) + "\n"
Path(md_filename).write_text(md_content)

print(f"{pdf_filename} saved.")
print(f"Markdown table saved to {md_filename}.")
