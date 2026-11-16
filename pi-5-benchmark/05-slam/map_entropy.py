#!/usr/bin/env python3
"""Shannon entropy of occupancy-grid images (lower = crisper, more certain map)."""
import sys
import numpy as np
from PIL import Image


def shannon_entropy(pgm_path):
    try:
        # Load the image and convert to grayscale array
        img = np.array(Image.open(pgm_path).convert('L'))
        # Histogram of pixel values 0-255
        counts, _ = np.histogram(img, bins=256, range=(0, 255))
        # Counts -> probabilities
        probs = counts / counts.sum()
        # Drop zero probabilities to avoid log(0)
        probs = probs[probs > 0]
        # H = -sum(p * log2(p))
        return -np.sum(probs * np.log2(probs))
    except Exception as e:
        return f"Error: {e}"


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 map_entropy.py <map1.pgm> <map2.pgm> ...")
        sys.exit(1)
    print(f"{'Map Filename':<30} | {'Entropy (bits)':<15}")
    print("-" * 50)
    for path in sys.argv[1:]:
        entropy = shannon_entropy(path)
        if isinstance(entropy, float):
            print(f"{path:<30} | {entropy:.4f}")
        else:
            print(f"{path:<30} | {entropy}")
