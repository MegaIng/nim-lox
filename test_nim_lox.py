import pytest

import re
from pathlib import Path
from subprocess import run, PIPE


def extract_expected(text: str):
    comments = re.findall("//.*", text)
    error_expect = None
    output_expect = []
    for comment in comments:
        if "Error at" in comment:
            assert not output_expect
            assert error_expect is None
            error_expect = comment
        elif "expect: " in comment:
            assert error_expect is None
            output_expect.append(comment[comment.index(':') + 1:])
        else:
            print("Unreleated comment: ", comment)
    if error_expect is not None:
        return True, error_expect
    else:
        return False, output_expect


@pytest.mark.parametrize("path", Path("lox_tests").rglob("*.lox"))
def test_lox(path: Path):
    print(path)
    text = path.read_text()
    expect_failure, expected_output = extract_expected(text)

    result = run(["./nim_lox/nim_lox.exe", path], stdout=PIPE, stderr=PIPE)
    if expect_failure:
        assert result.returncode != 0
    else:
        assert result.returncode == 0
        for expected, actual in zip(expected_output, result.stdout.splitlines()):
            try:
                assert float(expected) == float(actual.decode())
            except ValueError:
                assert expected.strip() == actual.decode().strip()