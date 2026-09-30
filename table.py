#!/usr/bin/env python3

import os
import sys
import csv
import math
import subprocess
import numpy as np
from pathlib import Path
from scipy.stats import wilcoxon, mannwhitneyu

if len(sys.argv) < 3:
    print("Usage: ./table.py ALG1 ALG2 [DIM=30]")
    sys.exit(1)

alg1 = sys.argv[1]
alg2 = sys.argv[2]
dim = int(sys.argv[3]) if len(sys.argv) > 3 else 30

def read_runs(alg, f_id):
    """Read full runs for a given algorithm and function"""
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

def format_p_and_log(p):
    """Helper to format p-value and log10(p-value) strings"""
    if p == 0 or math.isnan(p):
        return "1.00", "0.0"
    
    if p < 0.01:
        p_str = f"{p:.2e}"
    else:
        p_str = f"{p:.2f}"
    
    log_p = math.log10(p)
    log_p_str = f"{log_p:.1f}"
    return p_str, log_p_str

# Counters for bolds
bold_count1 = 0
bold_count2 = 0

# --- generate LaTeX table ---
tex = r"""
\documentclass{article}
\usepackage{geometry}
\geometry{margin=0.2in}
\begin{document}

\begin{table}[ht]
\centering
\scriptsize
\begin{tabular}{|c|ccc|ccc|c|c|c|c|}
\hline
F & \multicolumn{3}{c|}{\texttt{""" + latex_escape(alg1) + r"""}} & \multicolumn{3}{c|}{\texttt{""" + latex_escape(alg2) + r"""}} & $p_W$ & $\log_{10}(p_W)$ & $p_{MW}$ & $\log_{10}(p_{MW})$ \\
 & 10\% & 50\% & 90\% & 10\% & 50\% & 90\% & & & & \\
\hline
"""

# --- setup Markdown table ---
md_rows = []
md_rows.append(f"| F | {alg1} (10%) | {alg1} (50%) | {alg1} (90%) | {alg2} (10%) | {alg2} (50%) | {alg2} (90%) | p_W | log10(p_W) | p_MW | log10(p_MW) |")
md_rows.append("|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|")

for f_id in range(1, 30):  # functions 1..29
    # Read full runs
    runs1 = read_runs(alg1, f_id)
    runs2 = read_runs(alg2, f_id)

    # Compute quantiles (10%, 50% median, 90%)
    q1_10, q1_50, q1_90 = np.quantile(runs1, [0.1, 0.5, 0.9])
    q2_10, q2_50, q2_90 = np.quantile(runs2, [0.1, 0.5, 0.9])

    # Wilcoxon Signed-Rank Test (Paired)
    try:
        _, p_w = wilcoxon(runs1, runs2)
    except ValueError:
        p_w = 1.0

    # Mann-Whitney U Test (Unpaired)
    try:
        _, p_mw = mannwhitneyu(runs1, runs2, alternative='two-sided')
    except ValueError:
        p_mw = 1.0

    pw_raw, log_pw_raw = format_p_and_log(p_w)
    pmw_raw, log_pmw_raw = format_p_and_log(p_mw)

    # Primary decision criteria based on Mann-Whitney U test
    bold_row = (p_mw <= 0.05) and not math.isnan(p_mw)

    # Format Wilcoxon p-values
    pw_tex = f"${pw_raw}$"
    log_pw_tex = f"${log_pw_raw}$"
    pw_md = pw_raw
    log_pw_md = log_pw_raw

    # Format Mann-Whitney p-values (bold if significant)
    if bold_row:
        pmw_tex = r"$\textbf{" + pmw_raw + r"}$"
        log_pmw_tex = r"$\textbf{" + log_pmw_raw + r"}$"
        pmw_md = f"**{pmw_raw}**"
        log_pmw_md = f"**{log_pmw_raw}**"
    else:
        pmw_tex = f"${pmw_raw}$"
        log_pmw_tex = f"${log_pmw_raw}$"
        pmw_md = pmw_raw
        log_pmw_md = log_pmw_raw

    # Raw display strings for quantiles
    q1_10_d, q1_50_d, q1_90_d = f"{q1_10:.1e}", f"{q1_50:.1e}", f"{q1_90:.1e}"
    q2_10_d, q2_50_d, q2_90_d = f"{q2_10:.1e}", f"{q2_50:.1e}", f"{q2_90:.1e}"

    # Bold quantiles logic
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
        f"{pw_tex} & {log_pw_tex} & {pmw_tex} & {log_pmw_tex} \\\\\n"
    )

    # Append Markdown row
    md_rows.append(
        f"| {f_id} | {q1_10_md} | {q1_50_md} | {q1_90_md} | "
        f"{q2_10_md} | {q2_50_md} | {q2_90_md} | "
        f"{pw_md} | {log_pw_md} | {pmw_md} | {log_pmw_md} |"
    )

# Add final "Better" row to LaTeX
tex += r"\hline" + "\n"
tex += f"Better & \\multicolumn{{3}}{{c|}}{{{bold_count1}}} & \\multicolumn{{3}}{{c|}}{{{bold_count2}}} & & & & \\\\\n"
tex += r"\hline" + "\n"

tex += r"""
\end{tabular}
\end{table}

\end{document}
"""

# Add final "Better" row to Markdown
md_rows.append(f"| **Better** | <span colspan=\"3\">**{bold_count1}**</span> | | | <span colspan=\"3\">**{bold_count2}**</span> | | | | | | |")

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
