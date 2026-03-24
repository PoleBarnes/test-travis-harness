import argparse
import sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=1)
    args = parser.parse_args()
    for _ in range(args.count):
        print("Hello, Harness!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
