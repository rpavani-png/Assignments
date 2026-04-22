# log_parser.py
import sys
import re
from collections import Counter

def extract_user_agent(log_line):
    match = re.findall(r'"([^"]*)"$', log_line)
    return match[0] if match else "Unknown"

def parse_log(file):
    agents = []

    with open(file, "r") as f:
        for line in f:
            agents.append(extract_user_agent(line))

    counter = Counter(agents)

    print(f"Total unique User Agents: {len(counter)}\n")
    for agent, count in counter.items():
        print(f"{agent} -> {count}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python log_parser.py <access.log>")
        sys.exit(1)

    parse_log(sys.argv[1])