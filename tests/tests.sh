#!/bin/bash

# Copyright (c) 2019 Wind River Systems Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Ensures that generate_report.sh and test reports will be in the tests directory
FILE_DIR=$(dirname ${BASH_SOURCE[0]})
cd $FILE_DIR; FILE_DIR=$(pwd)
cp -f ../generate_report.sh $FILE_DIR/generate_report.sh

# Docker must be at least version 17.03 for tests to run
check_docker_version(){
    local docker_version=
    docker_version=$(docker --version | awk '{print $3}' | sed "s/[^0-9]*//g")

    if [ $docker_version -lt 17030 ]; then
        echo "Error: Docker must be version 17.03 or greater."
        exit 1
    fi
}

# Confirms that a package exists by trying to install it
check_package_exists(){
    local package_name="$1"
    local package_type="$2"
    # Declared as an empty string to catch invalid package_type
    local return_value=

    if [ "$package_type" = "alpine" ]; then
        docker run -it --rm alpine /bin/sh -c "apk --update \
            add $package_name >/dev/null 2>/dev/null"
        return_value=$?
    fi

    if [ "$package_type" = "debian" ]; then
        docker run -it --rm debian /bin/bash -c "apt-get -y update >/dev/null 2>/dev/null;\
            apt-get -y install $package_name >/dev/null 2>/dev/null"
        return_value=$?
    fi

    if [ "$package_type" = "python" ]; then
        docker run -it --rm alpine /bin/sh -c "apk --update \
            add py-pip >/dev/null 2>/dev/null;\
            pip install $package_name >/dev/null"
        return_value=$?
    fi

    if [ $return_value != 0 ]; then
        echo "Error: The package $package_name could not be installed."
        exit 1
    fi
}

# Confirms that a new package entry has been created and recorded in the second report
check_new_package(){
    local old_report="$1"
    local new_report="$2"
    local package="$3"

    grep -q -x "Package Name: $package" "$old_report"
    result_1=$?
    grep -q -x "Package Name: $package" "$new_report"
    result_2=$?

    if [ $result_1 == 0 ] || [ $result_2 != 0 ]; then
        echo "Error: Inconsistent appearance of $package in $old_report and $new_report."
        exit 1
    fi
}

# Checks the package entries of a report
check_entries(){
    local report="$1"
    IFS=$'\n'
    local packages=($(grep "Package Name: " "$report" | sed "s/Package Name: //g"))

    declare -a packages
    for package in "${packages[@]}"; do
        check_valid_entry "$package" "$report"
        check_unique_entry "$package" "$report"
    done

}

# Confirms that a package entry has at least one piece of valid information
check_valid_entry(){
    local package="$1"
    local report="$2"
    local package_info=($(grep -A5 "Package Name: $package" "$report"))

    local package_type=
    local package_version=
    local package_url=
    local package_license=

    package_type=$(echo "${package_info[1]}" | sed "s/Package Type: //g")
    package_version=$(echo "${package_info[2]}" | sed "s/Version: //g")
    package_url=$(echo "${package_info[3]}" | sed "s/Source URL: //g")

    if  [ "$package_type" = "Debian" ]; then
        package_license=${package_info[5]}
        if [ -z "$package_license" ] || [ "$package_license" = "--" ]; then
            package_license="N/A"
        fi
    else
        package_license=$(echo "${package_info[4]}" | sed "s/License: //g")
    fi

    if [ -z "$package_version" ] && [ "$package_url" = "N/A" ] && [ "$package_license" = "N/A" ]; then
        echo "Error: The entry for $package is invalid."
        exit 1
    fi

}

# Confirms that an entry does not already exist in the report
check_unique_entry(){
    local package=$1
    local report=$2
    local package_count=
    local version_count=

    package_count=$(grep -c -x "Package Name: $package" "$report")

    # Check that the version numbers of similar package entries are distinct
    if [ "$package_count" -gt 1 ]; then
        local package_versions=($(awk "/Package Name: $package/{nr[NR+2]}; NR in nr" $report | sed "s/Version: //g"))
        for version in "${package_versions[@]}"; do
            version_count=$(grep -c $version <<< "${package_versions[@]}")
            if [ ""$version_count -gt 1 ]; then
                echo "Error: Repeated entries for package $package, version $version"
                exit 1
            fi
        done

    fi
}

# Checks whether two reports are identical to each other.
check_duplicate(){
    report_1="$1"
    report_2="$2"

    diff "$report_1" "$report_2" > /dev/null
    result=$?

    if [ $result != 0 ]; then
        echo "Error: $report_1 and $report_2 should be identical reports."
        exit 1
    fi
}

# Install an Alpine package, create a new report and prove the existence of the newly created entries.
test_alpine(){
    local alpine_package="$1"

    check_package_exists "$alpine_package" alpine

    echo "Excecuting an Alpine package test using $alpine_package..."

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        alpine /bin/sh -c "cd /mnt;\
            apk update >/dev/null;\
            sh generate_report.sh > test_alpine_before;\
            apk add $alpine_package > /dev/null;\
            sh generate_report.sh > test_alpine_after"

    check_entries test_alpine_before
    check_entries test_alpine_after
    check_new_package test_alpine_before test_alpine_after "$alpine_package"

    echo "Test Passed."
}

# Create a report containing Alpine, Debian and a Python package by continuously appending and prove that there are no duplicate entries.
test_appended(){
    local python_package="$1"

    check_package_exists "$python_package" python

    echo "Excecuting an appended report test using $python_package..."

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        alpine /bin/sh -c "cd /mnt;\
            apk --update add py-pip > /dev/null;\
            sh generate_report.sh > test_alpine_appended;\
            pip install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh -a test_alpine_appended >> test_alpine_appended"

    check_entries test_alpine_appended

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        debian /bin/bash -c "cd /mnt;\
            apt-get -y update >/dev/null;\
            apt-get -y install python-pip >/dev/null 2>/dev/null;\
            sh generate_report.sh test_debian_appended > test_appended;\
            pip install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh -a test_debian_appended >> test_debian_appended"

    check_entries test_debian_appended

    echo "Test Passed."

}

# Install a Debian package, create a new report and prove the existence of the newly created entries.
test_debian(){
    local debian_package="$1"

    check_package_exists "$debian_package" debian

    echo "Excecuting a Debian package test using $debian_package..."

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        debian /bin/sh -c "cd /mnt;\
            sh generate_report.sh > test_debian_before;\
            apt-get -y update >/dev/null;\
            apt-get -y install $debian_package >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_debian_after"

    check_entries test_debian_before
    check_entries test_debian_after
    check_new_package test_debian_before test_debian_after "$debian_package"

    echo "Test Passed."
}

# Create duplicate Alpine and Debian reports containing a Python package and prove that their structure is the same.
test_duplicate(){
    local python_package="$1"

    check_package_exists "$python_package" python

    echo "Excecuting a duplicate report test using $python_package..."

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        alpine /bin/sh -c "cd /mnt;\
            apk --update add py-pip > /dev/null;\
            pip install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_alpine_original;\
            sh generate_report.sh > test_alpine_duplicate"

    check_entries test_alpine_original
    check_entries test_alpine_duplicate
    check_duplicate test_alpine_original test_alpine_duplicate

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        debian /bin/sh -c "cd /mnt;\
            apt-get -y update >/dev/null;\
            apt-get -y install python-pip >/dev/null 2>/dev/null;\
            pip install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_debian_original;\
            sh generate_report.sh > test_debian_duplicate"

    check_entries test_debian_original
    check_entries test_debian_duplicate
    check_duplicate test_debian_original test_debian_duplicate

    echo "Test Passed."

}

# A variation of the Python package test that uses a package manager in a Python venv.
test_pip(){
    local python_package="$1"

    check_package_exists "$python_package" python

    echo "Excecuting a Python venv report test using $python_package..."

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        alpine /bin/sh -c "cd /mnt;\
            apk --update add python3 >/dev/null 2>/dev/null;\
            python3 -m venv ./.alpine_venv;\
            .alpine_venv/bin/pip3 install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_alpine_pip;\
            sh generate_report.sh -p .alpine_venv/bin/pip3 > test_alpine_venv_pip"

    check_entries test_alpine_pip
    check_entries test_alpine_venv_pip
    check_new_package test_alpine_pip test_alpine_venv_pip "$python_package"

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        debian /bin/sh -c "cd /mnt;\
            apt-get -y update >/dev/null;\
            apt-get -y install python3 python3-venv python3-pip>/dev/null 2>/dev/null;\
            python3 -m venv ./.debian_venv;\
            .debian_venv/bin/pip3 install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_debian_pip;\
            sh generate_report.sh -p .debian_venv/bin/pip3 > test_debian_venv_pip"

    check_entries test_debian_pip
    check_entries test_debian_venv_pip
    check_new_package test_debian_pip test_debian_venv_pip "$python_package"

    echo "Test Passed."

}

# Install a Python package, create Alpine and Debian reports and prove the existence of the newly created entries.
test_python(){
    local python_package="$1"

    check_package_exists "$python_package" python

    echo "Excecuting a Python package test using $python_package..."

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        alpine /bin/sh -c "cd /mnt;\
            apk --update add py-pip >/dev/null;\
            sh generate_report.sh > test_python_alpine_before;\
            pip install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_python_alpine_after"

    check_entries test_python_alpine_before
    check_entries test_python_alpine_after
    check_new_package test_python_alpine_before test_python_alpine_after "$python_package"

    docker run -it --rm --mount "type=bind,src=$FILE_DIR,dst=/mnt" \
        debian /bin/sh -c "cd /mnt;\
            apt-get -y update >/dev/null;\
            apt-get -y install python-pip >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_python_debian_before;\
            pip install $python_package >/dev/null 2>/dev/null;\
            sh generate_report.sh > test_python_debian_after"

    check_entries test_python_debian_before
    check_entries test_python_debian_after
    check_new_package test_python_debian_before test_python_debian_after "$python_package"

    echo "Test Passed."

}

usage() {
    cat <<EOF
Usage: $0 [Test Case] <package> ...

  alpine <alpine_package>: Install an Alpine package, create a new report and prove the existence of the newly created entries.

  appended <python_package>: Create a report containing Alpine, Debian and a Python package by continuously appending and prove that there are no duplicate entries.

  debian <debian_package>: Install a Debian package, create a new report and prove the existence of the newly created entries.

  duplicate <python_package>: Create duplicate Alpine and Debian reports containing a Python package and prove that their structure is the same.

  pip <python_package>: A variation of the Python test that installs and reads Python packages from a venv.

  python <python_package>: Install a Python package, create Alpine and Debian reports and prove the existence of the newly created entries.

EOF
    exit 1
}

# Main code
check_docker_version
while [ "$# " -gt 0 ]; do
    TEST="$1"
    PACKAGE="$2"
    case "$TEST" in
        alpine) test_alpine "$PACKAGE"; shift 2;;
        appended) test_appended "$PACKAGE"; shift 2;;
        debian) test_debian "$PACKAGE"; shift 2;;
        duplicate) test_duplicate "$PACKAGE"; shift 2;;
        python) test_python "$PACKAGE"; shift 2 ;;
        pip) test_pip "$PACKAGE"; shift 2;;
        *) usage ;;
    esac
done
