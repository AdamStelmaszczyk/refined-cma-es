#!/usr/bin/env python3

import os
import sys
import csv
import subprocess
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
\geometry{margin=1in}
\begin{document}

\begin{table}[ht]
\centering
\begin{tabular}{|c|c|c|c|}
\hline
F & \texttt{""" + latex_escape(alg1) + r"""} & \texttt{""" + latex_escape(alg2) + r"""} & T \\
\hline
"""

for f_id in range(1, 30):  # functions 1..29
    # Read full runs
    runs1 = read_runs(alg1, f_id)
    runs2 = read_runs(alg2, f_id)

    # Compute means from runs
    m1 = sum(runs1) / len(runs1)
    m2 = sum(runs2) / len(runs2)

    # Wilcoxon test
    try:
        stat, p = wilcoxon(runs1, runs2)
        if p > 0.05:
            w_str = "="  # no significant difference
            bold_row = False
        else:
            w_str = "+" if m1 < m2 else "--"
            bold_row = True
    except ValueError:
        w_str = "="
        bold_row = False

    # Format means for display (1 decimal place scientific notation)
    m1_disp = f"{m1:.1e}"
    m2_disp = f"{m2:.1e}"

    # Bold smaller mean only if test is significant
    if bold_row:
        if m1 == m2:
            m1_str = r"\textbf{" + m1_disp + r"}"
            m2_str = r"\textbf{" + m2_disp + r"}"
            bold_count1 += 1
            bold_count2 += 1
        elif m1 < m2:
            m1_str = r"\textbf{" + m1_disp + r"}"
            m2_str = m2_disp
            bold_count1 += 1
        else:
            m1_str = m1_disp
            m2_str = r"\textbf{" + m2_disp + r"}"
            bold_count2 += 1
    else:
        m1_str = m1_disp
        m2_str = m2_disp

    tex += f"{f_id} & {m1_str} & {m2_str} & {w_str} \\\\\n"

# Add final "Better" row
tex += r"\hline" + "\n"
tex += f"Better & {bold_count1} & {bold_count2} & \\\\\n"
tex += r"\hline" + "\n"

tex += r"""
\end{tabular}
\end{table}

\end{document}
"""

Path("tex").mkdir(exist_ok=True)

tex_file = Path("tex/table.tex")
tex_file.write_text(tex)

subprocess.run(["pdflatex", "-interaction=nonstopmode", "-output-directory=tex" ,"tex/table.tex"])
filename = f"{alg1}_vs_{alg2}_{dim}d.pdf"
os.rename('tex/table.pdf', f'{filename}')
print(f"{filename} saved.")
