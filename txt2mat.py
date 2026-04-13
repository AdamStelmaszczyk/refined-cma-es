#!/usr/bin/env python3

import os
import argparse
import numpy as np
from scipy.io import savemat

def convert_txt_to_mat(folder):
    folder = os.path.abspath(folder)
    if not os.path.exists(folder):
        print(f"Folder {folder} does not exist!")
        return
    txt_files = [f for f in os.listdir(folder) if f.endswith('.txt')]
    if not txt_files:
        print(f"No .txt files found in {folder}")
        return
    for filename in txt_files:
        txt_path = os.path.join(folder, filename)
        try:
            data = np.loadtxt(txt_path, delimiter=',')
            if data.shape != (1001, 25):
                print(f"Warning: {filename} has shape {data.shape}, expected (1001, 25)")
            var_name = os.path.splitext(filename)[0]
            mat_path = os.path.join(folder, var_name + '.mat')
            savemat(mat_path, {var_name: data})
            print(f"Converted {filename} -> {var_name}.mat")
        except Exception as e:
            print(f"Error processing {filename}: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert CSV .txt files to .mat")
    parser.add_argument("folder", help="Folder containing .txt files of a given algorithm")
    args = parser.parse_args()
    convert_txt_to_mat(args.folder)

