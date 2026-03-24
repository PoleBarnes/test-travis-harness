import argparse
import sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", action="version", version="hello-harness v1.0.0")
    args = parser.parse_args()
    print("Hello, Harness!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
