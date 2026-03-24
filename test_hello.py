import subprocess

def test_hello_default():
    result = subprocess.run(["python3", "hello.py"], capture_output=True, text=True)
    assert result.stdout.strip() == "Hello, Harness!"
    assert result.returncode == 0

def test_hello_count_three():
    result = subprocess.run(["python3", "hello.py", "--count", "3"], capture_output=True, text=True)
    lines = result.stdout.strip().split("\n")
    assert len(lines) == 3
    assert all(line == "Hello, Harness!" for line in lines)
    assert result.returncode == 0

def test_hello_count_default():
    result = subprocess.run(["python3", "hello.py"], capture_output=True, text=True)
    lines = result.stdout.strip().split("\n")
    assert len(lines) == 1
    assert result.returncode == 0
