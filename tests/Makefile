# Copyright (c) 2017 Wind River Systems Inc.
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

.PHONY: test_alpine test_debian test_python test_pip \
	test_duplicate test_appended test_all clean

test_alpine: clean
	bash tests.sh alpine apache2

test_debian: clean
	bash tests.sh debian vim

test_pip: clean
	bash tests.sh pip samurai

test_python: clean
	bash tests.sh python samurai

test_duplicate: clean
	bash tests.sh duplicate samurai

test_appended: clean
	bash tests.sh appended samurai

test_all: clean
	bash tests.sh alpine apache2 \
	    debian vim \
	    python samurai \
	    pip samurai \
	    duplicate samurai \
	    appended samurai

clean: # Clear leftover products from previous tests
	rm -rf test_* *venv
