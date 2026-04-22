#The Fibonacci numbers are the numbers in the following integer sequence. 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, …….. In mathematical terms, the sequence Fn of Fibonacci numbers is defined by the recurrence relation Fn = Fn-1 + Fn-2 with seed values F0 = 0 and F1 = 1. Write a function fib that returns Fn. For example:
#if n = 0, then fib should return 0
#if n = 1, then it should return 1
#if n > 1, it should return Fn-1 + Fn-2
#!/bin/bash

fib() {
    n=$1

    if [ "$n" -eq 0 ]; then
        echo 0
        return
    fi

    if [ "$n" -eq 1 ]; then
        echo 1
        return
    fi

    a=0
    b=1

    for (( i=2; i<=n; i++ ))
    do
        c=$((a + b))
        a=$b
        b=$c
    done

    echo "$b"
}

read -p "Enter n: " num
fib "$num"

