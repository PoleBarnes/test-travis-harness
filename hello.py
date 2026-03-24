import argparse
import sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", default="Harness")
    args = parser.parse_args()
    print(f"Hello, {args.name}!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
