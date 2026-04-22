# file_extension.py
import sys
import os

def get_extension(filename):
    if "." not in filename or filename.startswith("."):
        raise Exception("No extension found!")
    return filename.split(".")[-1]

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python file_extension.py <filename>")
        sys.exit(1)

    try:
        ext = get_extension(sys.argv[1])
        print(f"Extension: {ext}")
    except Exception as e:
        print(f"Error: {e}")