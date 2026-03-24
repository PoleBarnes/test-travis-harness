import subprocess

def test_hello_default():
    result = subprocess.run(["python3", "hello.py"], capture_output=True, text=True)
    assert result.stdout.strip() == "Hello, Harness!"
    assert result.returncode == 0

def test_hello_version():
    result = subprocess.run(["python3", "hello.py", "--version"], capture_output=True, text=True)
    assert result.stdout.strip() == "hello-harness v1.0.0"
    assert result.returncode == 0
