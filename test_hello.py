import subprocess

def test_hello_default():
    result = subprocess.run(["python3", "hello.py"], capture_output=True, text=True)
    assert result.stdout.strip() == "Hello, Harness!"
    assert result.returncode == 0

def test_hello_with_name():
    result = subprocess.run(["python3", "hello.py", "--name", "Alice"], capture_output=True, text=True)
    assert result.stdout.strip() == "Hello, Alice!"
    assert result.returncode == 0

def test_hello_with_empty_name():
    result = subprocess.run(["python3", "hello.py", "--name", ""], capture_output=True, text=True)
    assert result.stdout.strip() == "Hello, !"
    assert result.returncode == 0
