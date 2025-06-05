#!/usr/bin/env bash
# Run the compiler on all .svgl files in input/ and save results to output/ with .svg extension

mkdir -p ./output

for infile in ./input/*.svgl; do
    base=$(basename "$infile" .svgl)
    outfile="./output/${base}.svg"
    ./compiler < "$infile" > "$outfile"
done
