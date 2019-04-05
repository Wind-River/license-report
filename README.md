# License Report

License Report is an open-source compliance tool that generates a
summary report of package license information for Alpine, Debian and
Python packages. The tool is intended to be run inside the build stage
of Docker images, where the generated report can be embedded.

## File Layout

--- license-report
    |--- generate_report.sh (Creates a report)
    |--- README.md
    |--- LICENSE.md
    |--- tests
    |    |--- tests.sh (Automated tests for generate_report.sh)
    |    |--- Makefile (Simplifies usage of tests.sh)

## Getting Started

### Requirements

generate_report.sh is a shell script, so nothing extra should be
needed to execute the file.

However, licensecheck is an optional dependency for sourcing Debian
packages:

    apt install licensecheck

Update the apk package index before generating a report if
applicable. The following warning will be raised otherwise:

    apk WARNING: Ignoring APKINDEX: No such file or directory

### Installing

Download the project from Github:

    git clone https://github.com/WindRiver-OpenSourceLabs/license-report

Alternatively, pull only the generate_report.sh script:

    curl -L https://github.com/downloads/WindRiver-OpenSourceLabs/license-report/generate_report.sh

## Usage

generate_report.sh usage function:

``` sh
usage() {
    cat <<EOF
Usage: $0 [-a, --appended <report name>] [-p, --pip <path/to/package/manager>]

  No options selected: An entirely new report will be created.

  -a, --appended <base_report>: Create an appended report consisting only of package entries that did not exist in the base report.

  -p, --pip <path/to/pip>: Use the specified package manager when searching for Python packages.

EOF
    exit 1
}
```

### Output Description

Reports created by generate_report.sh will be printed to the
console. This is so the user can control what is done with the output,
as demonstrated in Applications.

A package entry follows this general format:

    ----------------------------------------------------------------------------------------

    Package Name: <Name>
    Package Type: <Type>
    Version: <Version>
    Source URL: <URL>
    License: <License Codes>

If the version, source url or license code of a package cannot be
found, then the field "N/A" will be provided in its place. A package
entry is required to have at least one of those fields so that the
information it provides will be of value. The binary for Debian
package copyrights will be listed if the license code cannot be found
using licensecheck (Hence the optional dependency on the package).

Example:
    -----------------------------------------------------------------------------------------

    Package Name: amd64-microcode
    Package Type: Debian
    Version: 3.20180524.1~ubuntu0.18.04.2
    Source URL: N/A
    License: See /usr/share/doc/amd64-microcode/copyright

A report will follow this general format:

    ----------------------------------------------------------------------------------------


    <ORIGINAL/APPENDED> PACKAGES:


    ----------------------------------------------------------------------------------------

    Package Name: <Name>
    Package Type: <Type>
    Version: <Version>
    Source URL: <URL>
    License: <License Codes>

    ----------------------------------------------------------------------------------------

    <Other entries...>

As a result, concatenating a base report with an appended report will produce the following:

    ----------------------------------------------------------------------------------------


    ORIGINAL PACKAGES:


    ----------------------------------------------------------------------------------------

    Package Name: <Name>
    Package Type: <Type>
    Version: <Version>
    Source URL: <URL>
    License: <License Codes>

    ----------------------------------------------------------------------------------------

    <Other entries...>

    ----------------------------------------------------------------------------------------


    APPENDED PACKAGES:


    ----------------------------------------------------------------------------------------

    Package Name: <Name>
    Package Type: <Type>
    Version: <Version>
    Source URL: <URL>
    License: <License Codes>

    ----------------------------------------------------------------------------------------

    <Other entries...>


### Applications

Redirecting the output of generate_report.sh to a physical file:

    sh generate_report.sh > report # Output would be contained inside "report"

    sh generate_report.sh -a report > appended # Entries for additional packages
    would be contained inside "appended"

Adding appended information to an existing report:

    sh generate_report.sh -a report >> report

Creating and appending a report throughout a Dockerfile's build stages:

    RUN mkdir /<report-directory> &&
        cd /<report-directory> && \
        curl -L https://github.com/downloads/WindRiver-OpenSourceLabs/license-report/generate_report.sh && \
        sh generate_report > <report> && \
        rm /<report-directory>/generate_report.sh # Skip if carrying the report through another build stage

Carrying the report into another build stage:

    COPY --from=<Previous stage> /<report-directory> /<report-directory>

    RUN cd /<report-directory> && \
        sh generate_report -a <report> >> <report>

## Testing

See tests/README.md#1

## TODO

* Generate entries for RPM packages
* Add an option to produce the report in a machine-readable format

## Contributing

Contributions submitted must be signed off under the terms of the
Linux Foundation Developer's Certificate of Origin version 1.1. Please
refer to: https://developercertificate.org

To submit a patch:

* Open a Pull Request on the GitHub project
* Optionally create a GitHub Issue describing the issue addressed by the patch

## License

This project is licensed under the MIT License - see the LICENSE.md#1
file for more details.
