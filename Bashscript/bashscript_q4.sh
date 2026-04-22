#Write caesar cipher script accepting three parameters -s <shift> -i <input file> -o <output file>

#!/bin/bash

# Parse arguments
while getopts "s:i:o:" opt; do
  case "$opt" in
    s) shift_val="$OPTARG" ;;
    i) input_file="$OPTARG" ;;
    o) output_file="$OPTARG" ;;
    *)
      echo "Usage: $0 -s <shift> -i <input file> -o <output file>"
      exit 1
      ;;
  esac
done

# Validate inputs
if [ -z "$shift_val" ] || [ -z "$input_file" ] || [ -z "$output_file" ]; then
  echo "Error: Missing arguments"
  echo "Usage: $0 -s <shift> -i <input file> -o <output file>"
  exit 1
fi

if [ ! -f "$input_file" ]; then
  echo "Error: Input file does not exist"
  exit 1
fi

# Normalize shift (0–25)
shift_val=$((shift_val % 26))

# Caesar cipher logic using tr
lower_in="abcdefghijklmnopqrstuvwxyz"
lower_out="${lower_in:$shift_val}${lower_in:0:$shift_val}"

upper_in="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
upper_out="${upper_in:$shift_val}${upper_in:0:$shift_val}"

tr "$lower_in$upper_in" "$lower_out$upper_out" < "$input_file" > "$output_file"

echo "Caesar cipher completed successfully"


