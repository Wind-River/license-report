# tests.sh

## Requirements

Bash:

Alpine | Debian
------ | ------
apk add bash | sudo apt install bash

python3 >= 3.3

Docker CE >= 17.03:

    https://docs.docker.com/engine/installation

## Test Cases

The automated test cases within tests.sh can be called from the command line in
any order/combination. Docker containers are implemented within the tests to be
able to run the necessary package commands (Alpine, Debian, etc.) within an
independent, closed environment.

To run test cases:

    $ bash ./tests.sh [Test_1] <package_1> [Test_2] <package_2> ...

The test cases can be invoked using default packages with the Makefile
in tests.  The default Alpine, Debian and Python packages used are
apache2, vim and samurai respectively. Reports created for testing can
be removed using "make clean" or at the beginning of any Makefile test
case.

### Case 1 - Installing an Alpine, Debian or Python package:

Command Line | Makefile
------------ | --------
bash tests.sh alpine <alpine_package> | make test_alpine
bash tests.sh debian <debian_package> | make test_debian
bash tests.sh python <python_package> | make test_python

The purpose of this test case is to prove that entries in a generated report are
actually dependent on which packages are installed. This is done by creating
reports before and after installing the specified package and using grep to show
that the package only exists in the second report. The Python test case is
performed in both Alpine and Debian containers.

### Case 2 - Duplicate reports:

Command Line | Makefile
------------ | --------
bash tests.sh duplicate <python_package> | make test_duplicate

The purpose of this test case is to prove that the structure of a generated
report will always be consistent. This is done by generating pairs of Alpine and
Debian reports containing the specified Python package and using diff to show
that they are perfectly identical.

### Case 3 - Usage of Python venvs:

Command Line | Makefile
------------ | --------
bash tests.sh pip <python_package> | make test_pip

The purpose of this test case is to prove that generate_report.sh uses a package
package manager to locate Python packages if one is specified. This is done by
creating Python venvs in both Alpine and Debian containers, installing the
specified package within them, generating pairs of reports using either the
global package manager or the one in the venv and using grep to show that the
specified package only exists in the report using the pip venv.

### Case 4 - Appending a Report:

Command Line | Makefile
------------ | --------
bash tests.sh appended <python_package> | make test_appended

The purpose of this test case is to prove that the entries in appended reports
created by generate_report.sh are correct and did not previously exist in the
base report. This is done by appending the specified Python package to an Alpine
and Debian report and using grep to show that none of the package entries from
the base report are repeated.
