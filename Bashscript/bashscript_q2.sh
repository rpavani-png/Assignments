#Write bash script accepting operation parameter (“-”, “+”, “*”, “%”), sequence of numbers and debug flag. For example:
 #./your_script.sh -o % -n 5 3 -d > Result: 2
#./your_script.sh -o + -n 3 5 7 -d > Result: 15

#!/bin/bash

# Initialize variables
operation=""
numbers=()
debug=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      operation="$2"
      shift 2
      ;;
    -n)
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
        numbers+=("$1")
        shift
      done
      ;;
    -d)
      debug=true
      shift
      ;;
    *)
      echo "Invalid option: $1"
      exit 1
      ;;
  esac
done

# Debug output
if $debug; then
  echo "DEBUG: Operation = $operation"
  echo "DEBUG: Numbers = ${numbers[*]}"
fi

# Validation
if [[ -z "$operation" || ${#numbers[@]} -lt 2 ]]; then
  echo "Usage: $0 -o [+|-|*|%] -n num1 num2 [num3 ...] [-d]"
  exit 1
fi

# Perform calculation
result=${numbers[0]}

for (( i=1; i<${#numbers[@]}; i++ )); do
  case "$operation" in
    +) result=$(( result + numbers[i] )) ;;
    -) result=$(( result - numbers[i] )) ;;
    \*) result=$(( result * numbers[i] )) ;;
    %) result=$(( result % numbers[i] )) ;;
    *)
      echo "Unsupported operation"
      exit 1
      ;;
  esac
done

echo "Result: $result"

