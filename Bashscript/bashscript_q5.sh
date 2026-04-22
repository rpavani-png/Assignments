#Write script with following functionality:
#If -v tag is passed, replaces lowercase characters with uppercase and vise versa
#If -s is passed, script substitutes <A_WORD> with <B_WORD> in text (case sensitive)
#If -r is passed, script reverses text lines
#If -l is passed, script converts all the text to lower case
#If -u is passed, script converts all the text to upper case
#Script should work with -i <input file> -o <output file> tags

#!/bin/bash

# Initialize variables
input_file=""
output_file=""
operation=""
word_a=""
word_b=""

# Parse arguments
while getopts "vs:rlui:o:" opt; do
  case "$opt" in
    v)
      operation="invert"
      ;;
    s)
      operation="substitute"
      IFS=',' read -r word_a word_b <<< "$OPTARG"
      ;;
    r)
      operation="reverse"
      ;;
    l)
      operation="lower"
      ;;
    u)
      operation="upper"
      ;;
    i)
      input_file="$OPTARG"
      ;;
    o)
      output_file="$OPTARG"
      ;;
    *)
      echo "Usage:"
      echo "$0 [-v | -r | -l | -u | -s A_WORD,B_WORD] -i input -o output"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$operation" ] || [ -z "$input_file" ] || [ -z "$output_file" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 [-v | -r | -l | -u | -s A,B] -i input -o output"
  exit 1
fi

# Check if input file exists
if [ ! -f "$input_file" ]; then
  echo "Error: Input file does not exist"
  exit 1
fi

# Perform operation
case "$operation" in
  invert)
    tr 'a-zA-Z' 'A-Za-z' < "$input_file" > "$output_file"
    ;;
  substitute)
    sed "s/${word_a}/${word_b}/g" "$input_file" > "$output_file"
    ;;
  reverse)
    rev "$input_file" > "$output_file"
    ;;
  lower)
    tr 'A-Z' 'a-z' < "$input_file" > "$output_file"
    ;;
  upper)
    tr 'a-z' 'A-Z' < "$input_file" > "$output_file"
    ;;
esac

echo "Operation completed successfully"


