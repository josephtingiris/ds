STEP_DISABLE=false
STEP_FILE="${BASH_SOURCE}"
STEP_HEADER=true
STEP_NAME="Example Step"

function stepFunction() {
    mdReferences

    mdCommands

    if [ ${DS_BUILD} -eq 1 ] && [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
        mdExample
    fi

    if [ "${DS_ACTION}" == "delete" ]; then
        SUBSTEP_NAME="Delete substep"
        substep "${SUBSTEP_NAME}"

        mdReferences

        mdCommands

        if [ ${DS_BUILD} -eq 1 ] && [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            mdExample
        fi
    fi

    deleteExit

    if [ "${DS_ACTION}" == "create" ]; then
        SUBSTEP_NAME="Create substep"
        substep "${SUBSTEP_NAME}"

        mdReferences

        mdCommands

        if [ ${DS_BUILD} -eq 1 ] && [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            mdExample
        fi
    fi

    if [ "${DS_ACTION}" != "delete" ]; then
        SUBSTEP_NAME="Verify substep"
        substep "${SUBSTEP_NAME}"

        mdReferences

        mdCommands

        if [ ${DS_BUILD} -eq 1 ] && [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            mdExample
        fi
    fi
}

if [ "${0}" == "${BASH_SOURCE}" ]; then
    exit
else
    return
fi
