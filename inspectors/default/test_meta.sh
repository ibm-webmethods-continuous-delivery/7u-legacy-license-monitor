#!/bin/sh

export TEST_LABEL=sh_sh
export TEST_SHELL_COMMAND=sh
sh ./test.sh

export TEST_LABEL=sh_bash
export TEST_SHELL_COMMAND=bash
sh ./test.sh

export TEST_LABEL=bash_bash
export TEST_SHELL_COMMAND=bash
bash ./test.sh

export TEST_LABEL=bash_sh
export TEST_SHELL_COMMAND=sh
bash ./test.sh
