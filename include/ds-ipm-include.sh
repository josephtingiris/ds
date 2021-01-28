# This file will only get sourced when the ds --name matches, e.g. ds-example-include.sh

#
# Globals
#

EXAMPLE_VARIABLE=0

#
# Functions
#

function example_substep() {
    if [ "$1" != "quiet" ]; then

        SUBSTEP_NAME="Example Substep"
        substep "${SUBSTEP_NAME}"

        MD_REFERENCES+=('https://www.example.com/')
        mdCommands
    fi

    if [ ${DS_BUILD} -eq 1 ] && [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
        mdExample

        mdBlock bash
        echo "todo tada"
        mdBlock
    fi
}

#
# Init (dependencies)
#

if ! type -P echo &> /dev/null; then
    aborting "can't find echo"
fi
