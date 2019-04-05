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

ORIGINAL_REPORT="report"
APPENDING_REPORT="no"
PIP=pip
LICENSE_CHECK=$(command -v licensecheck)

usage() {
    cat <<EOF
Usage: $0 [-a, --appended <report name>] [-p, --pip <path/to/package/manager>]

  No options selected: Print a new report to console.

  -a, --appended <base_report>: Print an appended report containing entries absent from the base report.

  -p, --pip <path/to/pip>: Use the specified package manager when searching for Python packages.

EOF
    exit 1
}

while [ "$# " -gt 0 ]; do
    case "$1" in
        -a|--appended) APPENDING_REPORT="yes"; ORIGINAL_REPORT="$2"; shift 2 ;;
        -p|--pip) PIP="$2"; shift 2 ;;
        *)              usage ;;
    esac
done

ALPINE=$(command -v apk 2>/dev/null)
DEBIAN=$(command -v apt 2>/dev/null)
PYTHON=$(command -v "$PIP" 2>/dev/null)

catch_empty_fields(){
    local package=$1

    if [ -z "$PACKAGE_VERSION" ]; then
        PACKAGE_VERSION="N/A"
    fi

    if [ -z "$PACKAGE_SRC_URL" ]; then
        PACKAGE_SRC_URL="N/A"
    fi

    if [ -z "$PACKAGE_LICENSE" ]; then
        PACKAGE_LICENSE="N/A"
    fi
}

get_alpine_info(){
    local package=$1
    local package_info=
    package_info=$(apk info -w --license "$package")

    PACKAGE_TYPE="Alpine"

    PACKAGE_VERSION=$(echo "$package_info" | grep -m1 "$package" |
        awk '{print $1}' | sed "s/$package-//g")

    PACKAGE_SRC_URL=$(echo "$package_info" | grep -A1 -m1 "webpage:" | grep -v "webpage:" )

    PACKAGE_LICENSE=$(echo "$package_info" | grep -A1 -m1 "license:" | grep -v "license:")

    catch_empty_fields "$package"
}

get_debian_info() {
    local package="$1"

    PACKAGE_TYPE="Debian"

    PACKAGE_VERSION=$(dpkg -l "$package" | awk 'NR>5 {print $3}')

    PACKAGE_SRC_URL=$(apt-cache show "$package"="$PACKAGE_VERSION" |
        grep 'Homepage:' | awk '{print $2}')

    if [ -n "$LICENSE_CHECK" ]; then
        PACKAGE_LICENSE="$(licensecheck "/usr/share/doc/$package/copyright" | \
            sed "s#/usr/share/doc/$package/copyright: ##g")"
        if echo "$PACKAGE_LICENSE" | grep -q "UNKNOWN"; then
            PACKAGE_LICENSE="See /usr/share/doc/$package/copyright"
        fi
    else
        PACKAGE_LICENSE="See /usr/share/doc/$package/copyright"
    fi

    catch_empty_fields "$package"

}

get_python_info(){
    local package="$1"
    local package_info=
    package_info=$("$PIP" show "$package" 2>/dev/null)

    PACKAGE_TYPE="Python"

    PACKAGE_VERSION=$(echo "$package_info" | grep "Version:" | awk '{print $2}')

    PACKAGE_SRC_URL=$(echo "$package_info" | grep "Home-page:" | awk '{print $2}')

    PACKAGE_LICENSE=$(echo "$package_info" | grep "License:" | awk '{print $2}')

    catch_empty_fields "$package"
}

write_package_info(){
    local package="$1"
    local valid_entry="false"
    local unique_entry="false"

    if  [ "$PACKAGE_VERSION" != "N/A" ] || \
        [ "$PACKAGE_SRC_URL" != "N/A" ] || \
        [ "$PACKAGE_LICENSE" != "N/A" ]; then
            valid_entry="true"
    fi

    if  [ "$APPENDING_REPORT" = "no" ] || \
        ! (echo "$ORIGINAL_REPORT" | grep -q "Package Name: $package" || echo "$ORIGINAL_REPORT" | grep -q "Version: $PACKAGE_VERSION"); then
            unique_entry="true"
    fi

    if [ "$valid_entry" = "true" ] && [ "$unique_entry" = "true" ]; then
        echo "----------------------------------------------------------------------------------------"
        echo
        echo "Package Name: $package"
        echo "Package Type: $PACKAGE_TYPE"
        echo "Version: $PACKAGE_VERSION"
        echo "Source URL: $PACKAGE_SRC_URL"
        echo "License: $PACKAGE_LICENSE"
        echo
    fi

}

print_packages(){
    if [ -n "$ALPINE" ]; then
        local alpine_pkgs=
        alpine_pkgs=$(apk info)

        for package in $alpine_pkgs; do
            get_alpine_info "$package"
            write_package_info "$package"
        done
    fi

    if [ -n "$DEBIAN" ]; then
        local debian_pkgs=
        debian_pkgs=$(dpkg --get-selections | cut -f1 -d':' | awk '{print $1}')

        for package in $debian_pkgs; do
            get_debian_info "$package"
            write_package_info "$package"
        done
    fi

    if [ -n "$PYTHON" ]; then
        local python_pkgs=
        python_pkgs=$($PIP freeze 2>/dev/null | awk -F== '{print $1}')

        for package in $python_pkgs; do
            get_python_info "$package"
            write_package_info "$package"
        done
    fi
}

create_report() {
    echo "----------------------------------------------------------------------------------------"
    echo
    echo
    echo "ORIGINAL PACKAGES:"
    echo
    echo

    print_packages
}

create_appended_report(){
    echo "----------------------------------------------------------------------------------------"
    echo
    echo
    echo "APPENDED PACKAGES:"
    echo
    echo

    print_packages
}

if [ "$APPENDING_REPORT" = "yes" ]; then
    if ! [ -f "$ORIGINAL_REPORT" ]; then
        echo "Error: The indicated report to append does not exist." <&2
        exit 1
    fi
    create_appended_report
else
    create_report
fi
