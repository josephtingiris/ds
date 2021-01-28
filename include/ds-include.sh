# This file *always* gets sourced, don't put anything 'custom' in here!

# 20210102, joseph.tingiris@gmail.com

#
# Debug Functions (must be first, no dependencies)
#

function echoDebug() {
    # TODO: better debug levels

    if [[ ! "${Debug}" =~ [0-9]+ ]]; then
        return
    fi

    if [[ "${DEBUG_LEVEL}" =~ [0-9]+ ]]; then
        #echo "Debug=${Debug}, DEBUG_LEVEL=${DEBUG_LEVEL}"
        if [ ${Debug} -lt ${DEBUG_LEVEL} ]; then
            unset DEBUG_LEVEL
            return
        fi
    fi

    if [ ${TPUT_SETAF_3} ]; then
        1>&2 echo -n ${TPUT_BOLD}
        1>&2 echo -n ${TPUT_SETAF_3}
    fi

    1>&2 echo "[DEBUG] $(date +%Y-%m-%d\ %H:%M:%S) : $@"

    if [ ${TPUT_SGR0} ]; then
        1>&2 echo -n ${TPUT_SGR0}
    fi

    unset DEBUG_LEVEL
}

function echoDebugVar() {
    if [ "${1}" == "" ]; then return; fi

    DEBUG_LEVEL=100
    echoDebug "${1}=${!1}"
}

function echoStatus() {

    local status_msg

    if [ "${DS_ECHO_STATUS}" == "" ]; then
        export DS_ECHO_STATUS="STATUS"
        if [ ${TPUT_SETAF_2} ]; then
            1>&2 echo -n ${TPUT_BOLD}
            1>&2 echo -n ${TPUT_SETAF_2}
        fi
    else
        if [ ${TPUT_SETAF_1} ]; then
            1>&2 echo -n ${TPUT_BOLD}
            1>&2 echo -n ${TPUT_SETAF_1}
        fi
    fi

    status_msg=""

    #if [ "${STEP_COUNTER}" != "" ]; then
    #status_msg+="[${STEP_COUNTER}]"
    #fi

    status_msg+="[${DS_ECHO_STATUS}] $(date +%Y-%m-%d\ %H:%M:%S) : $@"
    1>&2 echo "${status_msg}"

    if [ ${TPUT_SGR0} ]; then
        1>&2 echo -n ${TPUT_SGR0}
    fi

    unset DS_ECHO_STATUS
}

#
# Globals
#


DS_ACTION=${DS_ACTION:-""}
echoDebugVar DS_ACTION

DS_ARGUMENTS=${DS_ARGUMENTS:="$@"}
echoDebugVar DS_ARGUMENTS

DS_BASENAME=${DS_BASENAME:-"ds"}
echoDebugVar DS_BASENAME

DS_DIR=$(realpath $(dirname ${BASH_SOURCE}))
DS_BIN="${DS_DIR}/${DS_BASENAME}"
if [ ! -x "${DS_BIN}" ]; then
    DS_BIN="${DS_DIR}/../${DS_BASENAME}"
fi
DS_BIN=$(realpath "${DS_BIN}")
echoDebugVar DS_BIN

DS_DIR=$(dirname "${DS_BIN}")
echoDebugVar DS_DIR

DS_BUILD=${DS_BUILD:-"0"}
echoDebugVar DS_BUILD

DS_EDIT_HELP=${DS_EDIT_HELP:-"0"}
echoDebugVar DS_EDIT_HELP

DS_FORCE=${DS_FORCE:-"0"}
echoDebugVar DS_FORCE

DS_HELP_DIR=${DS_HELP_DIR:-"${DS_DIR}/help"}
echoDebugVar DS_HELP_DIR

DS_MARKDOWN=${DS_MARKDOWN:="0"}
echoDebugVar DS_MARKDOWN

DS_NAME=${DS_NAME:-"${DS_BASENAME}"}
echoDebugVar DS_NAME

DS_RENAME=${DS_RENAME:-"0"}
echoDebugVar DS_RENAME

DS_TLDR=${DS_TLDR:-"0"}
echoDebugVar DS_TLDR

DS_TOC=${DS_TOC:-"0"}
echoDebugVar DS_TOC

DS_TOUCH=${DS_TOUCH:-"0"}
echoDebugVar DS_TOUCH

DS_WD=${DS_WD:-"$(dirname "${BASH_SOURCE}" 2> /dev/null)"}
echoDebugVar DS_WD

DS_QUIET=0
echoDebugVar DS_QUIET

# must be exported

export DS_ANSIBLE_OUT=/tmp/ansible.out
echoDebugVar DS_ANSIBLE_OUT

export DS_ANSIBLE_STEP=/tmp/ansible.step
echoDebugVar DS_ANSIBLE_STEP

export STEP_COUNTER=${STEP_COUNTER:-"0"}
echoDebugVar STEP_COUNTER

export STEP_DIR="${DS_DIR}/steps"
echoDebugVar STEP_DIR

export SUBSTEP_COUNTER=0
echoDebugVar SUBSTEP_COUNTER

export STEP_TMP=""

#
# Functions
#

function aborting() {
    local abort_msg

    if [ "${DS_ACTION}" != "delete" ]; then
        abort_msg="aborting ... "
    fi

    if [ ${DS_MARKDOWN} -eq 0 ]; then
        echo
        echo "${abort_msg}$@"
        echo
    else
        mkError "${abort_msg}$@"
    fi

    if [ "${DS_ACTION}" == "delete" ]; then
        if [ "${STEP}" == "" ]; then
            if [ "${0}" == "${BASH_SOURCE}" ]; then
                exit 2
            else
                return 2
            fi
        fi
    else
        if [ "${0}" == "${BASH_SOURCE}" ]; then
            exit 2
        else
            local aborting_basename="$(basename "${0}")"
            if [ "${aborting_basename}" == "${DS_BASENAME}" ] || [ "${aborting_basename}" == "${DS_BASENAME}-preview" ] || [ "${aborting_basename}" == "${DS_BASENAME}-wip" ]; then
                exit 3
            else
                echoDebug "aborting return: 0=${0}, BASH_SOURCE=${BASH_SOURCE}"
                return 2
            fi
        fi
    fi
}

if [ ! -d "${DS_DIR}" ]; then
    aborting "${DS_BASENAME} directory not found (DS_DIR=${DS_DIR})"
fi

if [ ! -x "${DS_BIN}" ]; then
    aborting "${DS_BASENAME} file not found executable (DS_BIN=${DS_BIN})"
fi

function ansibleStep() {
    local to="$1"
    if [ "${to}" == "" ]; then return 1; fi

    if [ ${DS_BUILD} -eq 0 ]; then return 0; fi

    local remote_user no_abort
    if [ "$2" == "noabort" ]; then
        no_abort="$2"
    else
        remote_user="$2"
    fi

    if [ "$3" == "noabort" ]; then
        no_abort="$3"
    fi

    local ansible_extra_args scp_extra_args

    if [ "${remote_user}" != "" ]; then
        if [ ${#ansible_extra_args} -gt 0 ]; then ansible_extra_args+=" "; fi
        ansible_extra_args+="-u ${remote_user}"
        scp_extra_args+="${remote_user}@"
    fi

    if [ "${DS_ANSIBLE_USER}" == "" ]; then
        DS_ANSIBLE_USER=root
    fi

    local source_rm
    if [ "${DS_ANSIBLE_USER}" == "root" ]; then
        source_rm="; rm -f ${DS_ANSIBLE_STEP}"
    fi

    chmod 0666 "${DS_ANSIBLE_STEP}"
    scp -q -p -i ~/.ssh/id_rsa.pub ${DS_ANSIBLE_STEP} ${scp_extra_args}${to}:/tmp
    if [ $? -eq 0 ]; then
        echoDebug "ansible all -i ${to}, ${ansible_extra_args} -m shell -b --become-user ${DS_ANSIBLE_USER} -a \"source ${DS_ANSIBLE_STEP}${source_rm}\" &> \"${DS_ANSIBLE_OUT}\""
        ansible all -i ${to}, ${ansible_extra_args} -m shell -b --become-user ${DS_ANSIBLE_USER} -a "source ${DS_ANSIBLE_STEP}${source_rm}" &> "${DS_ANSIBLE_OUT}"
        DS_ANSIBLE_RC=$?
        if [ ${DS_ANSIBLE_RC} -eq 0 ]; then
            cat "${DS_ANSIBLE_OUT}" | egrep -ve 'CHANGED|rc=0|remote_tmp' | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}' > "${DS_ANSIBLE_OUT}.1"
            if [ -s "${DS_ANSIBLE_OUT}.1" ]; then
                mdExample

                mdBlock bash
                cat "${DS_ANSIBLE_OUT}.1"
                mdBlock
            else
                mdSuccess
            fi
        else
            if [ "${no_abort}" == "" ]; then
                mdExample

                mdBlock bash
                cat "${DS_ANSIBLE_OUT}"
                mdBlock
                unset DS_ANSIBLE_USER
                aborting "failed ansible in ${SUBSTEP_NAME} trying to ansible all -i ${to}, ${ansible_extra_args} -m shell -b -a \"source ${DS_ANSIBLE_STEP}${source_rm}\" (rc=${DS_ANSIBLE_RC})"
            fi
        fi
    fi
    rm -f "${DS_ANSIBLE_STEP}" &> /dev/null
    rm -f "${DS_ANSIBLE_OUT}" &> /dev/null
    rm -f "${DS_ANSIBLE_OUT}.1" &> /dev/null
    unset DS_ANSIBLE_RC DS_ANSIBLE_USER
}

function deleteExit() {
    if [ "${DS_ACTION}" == "delete" ]; then
        if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            exit 0
        fi
    fi
}

function dynamicPass() {
    local dynamicPass
    dynamicPass="!"$(echo -n ${1} | md5sum | awk "{print \$1}")"!"
    echo -n "${dynamicPass}"
}

function environmentVariables() {

    if [ -r "${DS_NAME}.env" ]; then
        export DS_ENV="${DS_NAME}.env"
    else
        if [ -r "../${DS_NAME}.env" ]; then
            export DS_ENV="../${DS_NAME}.env"
        else
            aborting "${DS_NAME}.env file not found readable; use -n or ${DS_BASENAME}.env as a template"
            exit 99
        fi
    fi
    echoDebugVar DS_ENV

    # if set via external environment
    if [ "${DS_PROJECT_ENV}" != "" ]; then
        if [ ! -r "${DS_PROJECT_ENV}" ]; then
            aborting "DS_PROJECT_ENV is invalid; ${DS_PROJECT_ENV} file not found readable"
        fi
    fi

    if [ "${DS_PROJECT_ENV}" == "" ]; then
        export DS_PROJECT_ENV="${DS_NAME}-project.env"
    fi

    local grep_variable_prefix="DS"

    if [ "$1" == "quiet" ]; then
        DS_QUIET=1
    else
        DS_QUIET=0
    fi

    if [ ${#DS_VARIABLE_PREFIX} -gt 0 ]; then
        SUBSTEP_NAME="Unset ${DS_VARIABLE_PREFIX} Variables"
        grep_variable_prefix=${DS_VARIABLE_PREFIX}
    else
        SUBSTEP_NAME="Unset Environment Variables"
    fi
    substep "${SUBSTEP_NAME}"

    MD_REFERENCES+=('https://www.gnu.org/software/bash/manual/html_node/Environment.html')
    mdReferences

    MD_COMMANDS+=("for VARIABLE_PREFIX in \$(env | grep ^${grep_variable_prefix} | awk -F= '{print \$1}' | sort -V); do")
    MD_COMMANDS+=('    echo unset $VARIABLE_PREFIX')
    MD_COMMANDS+=('    unset $VARIABLE_PREFIX')
    MD_COMMANDS+=('done')
    mdCommands

    if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
        mdExample

        if [ ${DS_QUIET} -eq 0 ]; then
            mdBlock
            for VARIABLE_PREFIX in $(env | grep ^${grep_variable_prefix} | awk -F= '{print $1}' | sort -V); do
                echo unset $VARIABLE_PREFIX
                unset $VARIABLE_PREFIX
            done
            mdBlock
        fi
    fi

    if [ ${DS_QUIET} -eq 1 ]; then
        for VARIABLE_PREFIX in $(env | grep ^${grep_variable_prefix} | awk -F= '{print $1}' | sort -V); do
            unset $VARIABLE_PREFIX
        done
    fi

    # always source after unsetting
    source "${DS_ENV}"
    if [ $? -ne 0 ]; then
        DS_QUIET=0
        aborting "failed to source ${DS_ENV}"
    fi

    if [ -r "${DS_PROJECT_ENV}" ]; then
        DEBUG_LEVEL=11 && echoDebug "+ ${FUNCNAME} using ${DS_PROJECT_ENV}"
        source "${DS_PROJECT_ENV}"
    else
        if [ -r "../${DS_PROJECT_ENV}" ]; then
            DEBUG_LEVEL=11 && echoDebug "+ ${FUNCNAME} using ../${DS_PROJECT_ENV}"
            source "../${DS_PROJECT_ENV}"
        fi
    fi

    if [ ${#DS_VARIABLE_PREFIX} -gt 0 ]; then
        DEBUG_LEVEL=20 && echoDebug "DS_VARIABLE_PREFIX=${DS_VARIABLE_PREFIX}"
        if [ ${#DS_NAME} -gt 0 ]; then
            export ${DS_VARIABLE_PREFIX}=${DS_NAME}
            DEBUG_LEVEL=20 && echoDebug "DS_NAME=${DS_NAME}: ${DS_VARIABLE_PREFIX}=${!DS_VARIABLE_PREFIX}"
        fi
    fi

    if [ ${DS_QUIET} -eq 1 ]; then
        DS_QUIET=0
        SUBSTEP_COUNTER=0
        return
    fi

    if [ "${DS_ACTION}" == "create" ] || [ "${1}" == "preview" ]; then
        if [ ${#DS_VARIABLE_PREFIX} -gt 0 ]; then
            SUBSTEP_NAME="Set ${DS_VARIABLE_PREFIX} Variables"
            grep_variable_prefix=${DS_VARIABLE_PREFIX}
        else
            SUBSTEP_NAME="Set Environment Variables"
        fi
        substep "${SUBSTEP_NAME}"

        MD_REFERENCES+=('https://www.gnu.org/software/bash/manual/html_node/Environment.html')
        mdReferences

        MD_COMMANDS+=("cat << 'EOF' > \"${DS_NAME}.env\"")
        MD_COMMANDS+=("$(cat "${DS_ENV}")")
        MD_COMMANDS+=('EOF')
        MD_COMMANDS+=("source \"${DS_NAME}.env\"")
        mdCommands

        if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            mdExample

            mdSuccess
        fi
    fi

    if [ "${DS_ACTION}" != "delete" ] || [ "${1}" == "preview" ]; then
        if [ ${#DS_VARIABLE_PREFIX} -gt 0 ]; then
            SUBSTEP_NAME="Verify ${DS_VARIABLE_PREFIX} Variables"
            grep_variable_prefix=${DS_VARIABLE_PREFIX}
        else
            SUBSTEP_NAME="Verify Environment Variables"
        fi
        substep "${SUBSTEP_NAME}"

        MD_REFERENCES+=('https://www.mankier.com/1/env')
        MD_REFERENCES+=('https://www.mankier.com/1/grep')
        MD_REFERENCES+=('https://www.mankier.com/1/sort')
        MD_REFERENCES+=('https://www.gnu.org/software/bash/manual/html_node/Environment.html')
        mdReferences

        MD_COMMANDS+=("env | grep ^${grep_variable_prefix} | sort -uV")
        mdCommands

        mdExample

        if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            mdBlock bash
            env | grep ^${grep_variable_prefix} | sort -uV
            mdBlock
            echo
        fi
    fi

    SUBSTEP_COUNTER=0
}

function error() {
    local error_msg

    error_msg="ERROR! "

    if [ ${DS_MARKDOWN} -eq 0 ]; then
        echo
        echo "${error_msg}$@"
        echo
    else
        mkError "$@"
    fi
}

function mdBlock() {
    if [ ${DS_QUIET} -eq 1 ]; then return; fi
    if [ ${DS_TOC} -eq 1 ]; then return; fi

    if [ "${1}" != "" ]; then
        MD_BLOCK="${1}"
        if [ "${MD_BLOCK}" == "yaml" ]; then
            MD_BLOCK="bash"
        fi
    fi

    if [ ${DS_MARKDOWN} -eq 1 ]; then
        echo "\`\`\`${MD_BLOCK}"
    fi

    unset MD_BLOCK
}

function mdCommands() {
    MD_COMMANDS_LAST="${MD_COMMANDS}"

    if [ ${DS_TOC} -eq 1 ]; then
        unset MD_COMMANDS
        return
    fi

    if [ ${DS_QUIET} -eq 1 ]; then
        unset MD_COMMANDS
        return
    fi

    if [ "${MD_COMMANDS}" == "" ] && [ "$1" == "" ]; then return; fi

    if [ ${DS_TLDR} -eq 0 ]; then
        echo
        if [ ${DS_MARKDOWN} -eq 1 ]; then
            echo "**_Command(s):_**"
        else
            echo "Command(s):"
        fi
        echo
    fi

    if [ "${MD_COMMANDS}" != "" ]; then
        mdBlock bash
        for MD_COMMAND in "${MD_COMMANDS[@]}"; do
            echo "${MD_COMMAND}"
        done
        mdBlock
    else
        if [ "$1" != "" ] && [ "$1" != "." ]; then
            mdBlock bash
            echo "$@"
            mdBlock
        fi
    fi
    unset MD_COMMANDS
}

function mdExample() {
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ] || [ ${DS_BUILD} -eq 0 ]; then
        unset MD_COMMANDS_LAST
        return
    fi

    if [ ${DS_QUIET} -eq 1 ]; then
        unset MD_COMMANDS_LAST
        return
    fi

    if [ "${MD_COMMANDS_LAST}" != "" ]; then
        echo
        if [ ${DS_MARKDOWN} -eq 1 ]; then
            echo "**_Example Output:_**"
        else
            echo "Example Output:"
        fi
        echo
    fi

    unset MD_COMMANDS_LAST
}

function mdReferences() {
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ]; then
        unset MD_REFERENCES
        return
    fi

    if [ ${DS_QUIET} -eq 1 ]; then
        unset MD_REFERENCES
        return
    fi

    if [ "${MD_REFERENCES}" != "" ]; then
        echo
        if [ ${DS_MARKDOWN} -eq 1 ]; then
            echo "**_Reference(s):_**"
        else
            echo "Reference(s):"
        fi
        echo
        for MD_REFERENCE in "${MD_REFERENCES[@]}"; do
            if [ ${DS_MARKDOWN} -eq 1 ]; then
                if [[ "${MD_REFERENCE}" == *"["*"]"* ]]; then
                    if [[ "${MD_REFERENCE}" == *"("*")"* ]]; then
                        echo "* ${MD_REFERENCE}"
                    else
                        echo "* [${MD_REFERENCE}](${MD_REFERENCE})"
                    fi
                else
                    echo "* [${MD_REFERENCE}](${MD_REFERENCE})"
                fi
            else
                echo "* ${MD_REFERENCE}"
            fi
        done
        unset MD_REFERENCE
        echo
    fi
    unset MD_REFERENCES
}

function mdSuccess() {
    if [ ${DS_QUIET} -eq 1 ]; then return; fi
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ]; then return; fi

    echo "\`\`\`diff"
    if [ "$1" == "" ]; then
        echo "+ success does not produce any output"
    else
        echo $@
    fi
    echo '```'
}

function mkError() {
    if [ ${DS_QUIET} -eq 1 ]; then return; fi
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ]; then return; fi

    echo
    echo "!!! error"
    echo "    $@"
    echo
}

function mkImportant() {
    if [ ${DS_QUIET} -eq 1 ]; then return; fi
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ]; then return; fi

    echo
    echo "!!! important"
    echo "    $@"
    echo
}

function mkNote() {
    if [ ${DS_QUIET} -eq 1 ]; then return; fi
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ]; then return; fi

    echo
    echo "!!! note"
    echo "    $@"
    echo
}

function mkTip() {
    if [ ${DS_QUIET} -eq 1 ]; then return; fi
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ]; then return; fi

    echo
    echo "!!! tip"
    echo "    $@"
    echo
}

function mkWarning() {
    if [ ${DS_QUIET} -eq 1 ]; then return; fi
    if [ ${DS_TOC} -eq 1 ] || [ ${DS_TLDR} -eq 1 ]; then return; fi

    echo
    echo "!!! warning"
    echo "    $@"
    echo
}

function step() {

    local step_name="$@"

    if [ "${DS_RENAME}" == "1" ]; then
        stepRename "${step_name}"
        return
    fi

    stepTmp "$@"

    SUBSTEP_COUNTER=0

    #echoDebug "${STEP_COUNTER} - ${step_name}"

    if [ "${STEP}" != "" ] && [ "${STEP}" != "${STEP_COUNTER}" ]; then
        unset STEP_HELP

        stepTmp "$@"
        unset STEP_TMP

        return
    fi

    if [ ${DS_QUIET} -eq 1 ]; then
        unset STEP_HELP
        return
    fi

    if [ ${DS_MARKDOWN} -eq 0 ]; then
        [ ${TPUT_SETAF_2} ] && echo -n ${TPUT_SETAF_2}
        if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            echo
            echo "#"
        fi
    fi

    if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
        echo -n "### "
    fi

    if [ ${DS_TLDR} -eq 0 ]; then
        echo "${STEP_COUNTER} - ${step_name}"
    else
        echo
        echo "### ${STEP_COUNTER} - ${step_name}"
    fi

    if [ ${DS_MARKDOWN} -eq 0 ]; then
        if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            echo "#"
            echo
        fi
        [ ${TPUT_SGR0} ] && echo -n ${TPUT_SGR0}
    fi

    stepHelp "${step_name}"

    unset STEP_HELP

    stepTmp "$@"
    unset STEP_TMP
}

function stepExit() {
    if [ "${STEP}" == "${STEP_COUNTER}" ]; then
        exit 0
    fi
}

function stepHelp() {
    if [ "$1" == "" ]; then return; fi

    if [ "${STEP_HELP}" == "false" ]; then
        unset STEP_HELP
        return
    fi

    if [ ${DS_QUIET} -eq 1 ]; then
        unset STEP_HELP
        return
    fi

    if [ "${STEP_HELP}" == "" ]; then
        STEP_HELP="$@"
    fi

    local step_rename substep_rename

    if [ ${#STEP_RENAME} -gt 0 ]; then
        step_rename="${STEP_RENAME}"
        local stepHelp_rename="${DS_HELP_DIR}/${step_rename}.md"
        if [ -f "${stepHelp_rename}" ]; then
            echoDebug "stepHelp_rename = ${stepHelp_rename}"
            if [ -f "${DS_HELP_DIR}/${STEP_HELP}.md" ]; then
                aborting "${DS_HELP_DIR}/${STEP_HELP}.md already exists (STEP_RENAME)"
            else
                mv "${stepHelp_rename}" "${DS_HELP_DIR}/${STEP_HELP}.md"
                if [ $? -ne 0 ]; then
                    aborting "failed to mv '${stepHelp_rename}' '${DS_HELP_DIR}/${STEP_HELP}.md'"
                fi
            fi
        fi
        if [ "${STEP_FILE}" == "${STEP_SH}" ]; then
            if [ -f "${STEP_SH}" ]; then
                sed -i "/^STEP_RENAME=\"${STEP_RENAME}\"/d" "${STEP_SH}"
            fi
        fi
        unset STEP_RENAME
    fi

    if [ ${#SUBSTEP_RENAME} -gt 0 ]; then
        step_rename="${SUBSTEP_RENAME}"
        local stepHelp_rename="${DS_HELP_DIR}/${step_rename}.md"
        if [ -f "${stepHelp_rename}" ]; then
            echoDebug "stepHelp_rename = ${stepHelp_rename}"
            if [ -f "${DS_HELP_DIR}/${STEP_HELP}.md" ]; then
                aborting "${DS_HELP_DIR}/${STEP_HELP}.md already exists (SUBSTEP_RENAME)"
            else
                mv "${stepHelp_rename}" "${DS_HELP_DIR}/${STEP_HELP}.md"
                if [ $? -ne 0 ]; then
                    aborting "failed to mv '${stepHelp_rename}' '${DS_HELP_DIR}/${STEP_HELP}.md'"
                fi
            fi
        fi
        if [ "${STEP_FILE}" == "${STEP_SH}" ]; then
            if [ -f "${STEP_SH}" ]; then
                sed -i "/SUBSTEP_RENAME=\"${SUBSTEP_RENAME}\"/d" "${STEP_SH}"
            fi
        fi
        unset STEP_RENAME
    fi

    local helpfile

    if [ "${STEP}" == "" ] || [ "${STEP}" == "${STEP_COUNTER}" ]; then
        helpfile="${DS_HELP_DIR}/${STEP_HELP}.md"
        if [ ${DS_EDIT_HELP} -eq 1 ] && [ ${DS_FORCE} -eq 1 ]; then
            touch "${helpfile}"
            wait $!
            if [ ${DS_TOUCH} -eq 0 ]; then
                ${EDITOR} "${helpfile}"
            fi
        else
            if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
                if [ -r "${helpfile}" ]; then
                    if [ -s "${helpfile}" ]; then
                        echo
                        if [ ${DS_MARKDOWN} -eq 0 ]; then
                            cat "${helpfile}" | egrep -ve '^```' | sed -e '/\*\*_/s///g' -e '/_\*\*/s///g'
                        else
                            cat "${helpfile}"
                        fi
                        echo
                    fi
                else
                    if [ ${DS_EDIT_HELP} -eq 1 ]; then
                        touch "${helpfile}"
                        if [ ${DS_TOUCH} -eq 0 ]; then
                            ${EDITOR} "${helpfile}"
                        fi
                        if [ ${DS_MARKDOWN} -eq 0 ]; then
                            cat "${helpfile}" | egrep -ve '^```' | sed -e '/\*\*_/s///g' -e '/_\*\*/s///g'
                        else
                            cat "${helpfile}"
                        fi
                    else
                        if [ ! -f "${helpfile}" ]; then
                            echo
                            echo "missing '${helpfile}'"
                            echo
                        fi
                    fi
                fi
            else
                if [ ${DS_TOC} -eq 1 ]; then
                    if [ ${DS_EDIT_HELP} -eq 1 ]; then
                        if [ ! -f "${helpfile}" ]; then
                            touch "${helpfile}"
                            if [ ${DS_TOUCH} -eq 0 ]; then
                                ${EDITOR} "${helpfile}"
                            fi
                        fi
                    fi
                else
                    echo
                fi
            fi
        fi
        if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
            if egrep -qe "Command:|Commands:|Command.s." "${helpfile}" 2> /dev/null; then
                mdExample
            fi
        fi
        unset STEP_HELP
    fi

    unset STEP_RENAME SUBSTEP_RENAME
}

function stepHelpCheck() {
    if [ "${DS_ACTION}" == "helpcheck" ]; then
        echo "DS_DIR=${DS_DIR}"
        echo "STEP_DIR=${STEP_DIR}"
        exit
    fi
}

function stepLoop() {

    if [ "${DS_ACTION}" == "delete" ] && [ ${DS_RENAME} -eq 0 ] && [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ] && [ "${STEP}" == "" ]; then
        step "Delete Everything"

        #
        # CAREFUL; THIS NEEDS TESTING
        #

        echo -n "Are you sure (type YES to continue)? "
        read YES
        if [ "$YES" != "YES" ]; then
            aborting "YES was not confirmed"
        fi

        exit 0
    fi

    STEPS_SH=()
    while read STEP_SH; do
        STEPS_SH+=("${STEP_SH}")
    done <<< "$(ls -1 "${STEP_DIR}"/*.sh | sort -V)"

    for STEP_SH in "${STEPS_SH[@]}"; do
        unset STEP_DISABLE STEP_FILE STEP_HEADER STEP_NAME STEP_SH_BASENAME

        if [ ! -r "${STEP_SH}" ]; then
            aborting "${STEP_SH} file not readable"
        fi

        STEP_COUNTER_LAST=${STEP_COUNTER}

        STEP_DISABLE=false
        STEP_HEADER=true

        unset -f stepFunction
        source "${STEP_SH}"

        if [ ${#STEP_FILE} -eq 0 ]; then
            sed -i '/^STEP_FILE=/d' "${STEP_SH}"
            sed -i '1s/^/STEP_FILE="${BASH_SOURCE}"\n/' "${STEP_SH}"
            source "${STEP_SH}"
        fi

        if [ ${#STEP_FILE} -eq 0 ]; then
            aborting "STEP_FILE is empty"
        fi

        if ! ${STEP_DISABLE}; then
            if ${STEP_HEADER}; then
                let STEP_COUNTER=STEP_COUNTER+1
            fi
        fi

        if [ "${STEP_FILE}" != "${STEP_SH}" ]; then
            #echoDebug "STEP_SH           = ${STEP_SH}"
            aborting "STEP_FILE != STEP_SH (this shouldn't happen)"
        fi

        if [ "${DS_RENAME}" == "1" ]; then

            if [ "${STEP_COUNTER}" == "0" ] && [ "${SUBSTEP_COUNTER}" == "0" ]; then
                (${DS_BIN} -n ${DS_NAME} -d --toc)
                (${DS_BIN} -n ${DS_NAME} -c --toc)
                echo
            fi

            sed -i '/^STEP_HEADER=/d' "${STEP_SH}"
            sed -i "1s/^/STEP_HEADER=${STEP_HEADER}\n/" "${STEP_SH}"

            sed -i '/^STEP_FILE=/d' "${STEP_SH}"
            sed -i '1s/^/STEP_FILE="${BASH_SOURCE}"\n/' "${STEP_SH}"

            sed -i '/^STEP_DISABLE=/d' "${STEP_SH}"
            sed -i "1s/^/STEP_DISABLE=${STEP_DISABLE}\n/" "${STEP_SH}"
        fi

        if [ ${DS_RENAME} -eq 0 ]; then
            if [ "${STEP}" != "" ] && [ "${STEP}" != "${STEP_COUNTER}" ]; then
                continue
            fi
        fi

        if ${STEP_DISABLE}; then
            continue
        fi

        if ${STEP_HEADER}; then
            step "${STEP_NAME}"
        else
            if [ ${DS_RENAME} -eq 1 ]; then
                step "${STEP_NAME}"
            fi
        fi

        if [ ${DS_RENAME} -eq 0 ]; then
            if type -t stepFunction &> /dev/null; then
                stepFunction
                wait $!
            fi
        fi
    done
    unset STEP_SH STEP_SH_BASENAME

    STEP_COUNTER=0
}

function stepRename() {
    local current_step_number step_file_basename step_name step_number step_rename substep substep_file substep_name substep_number subsubstep_counter
    step_name="$@"

    if [ "${DS_RENAME}" != "1" ]; then
        return
    fi

    if [ ${#STEP_FILE} -eq 0 ]; then
        aborting "STEP_FILE is empty ($FUNCNAME)"
    fi

    if [ "${STEP_DIR}" == "" ]; then
        aborting "STEP_DIR is empty"
    fi

    if [ ! -d "${STEP_DIR}" ]; then
        mkdir -p "${STEP_DIR}"
        if [ $? -ne 0 ]; then
            aborting "failed to mkdir ${STEP_DIR}"
        fi
    fi

    step_file_basename="${STEP_FILE##*/}"
    #echoDebug "step_file_basename = ${step_file_basename}"

    current_step_number=${step_file_basename%%.sh*}
    current_step_number=${current_step_number%% *}

    step_number="${STEP_COUNTER}"
    if [ "${STEP_COUNTER}" == "0" ]; then
        let SUBSTEP_COUNTER=${SUBSTEP_COUNTER}+1
        step_number+=".${SUBSTEP_COUNTER}"
    fi

    step_rename="${STEP_DIR}/${step_number}"
    step_rename+=" - ${step_name}.sh"

    if [ "${step_rename}" != "${STEP_FILE}" ]; then
        if [ ! -f "${step_rename}" ]; then
            #echoDebug "rename step ${STEP_DIR}/${STEP_COUNTER} - ${step_name}"
            mv "${STEP_FILE}" "${step_rename}"
            if [ $? -ne 0 ]; then
                aborting "failed to mv ${STEP_FILE} ${step_rename}"
            fi
            echo "[RENAME] [${STEP_COUNTER}] STEP_FILE = ${STEP_FILE} -> ${step_rename}"
            STEP_FILE="${step_rename}"
        else
            aborting "'${step_rename}' file found, refusing to mv '${STEP_FILE}'"
        fi
    else
        echo "[  OK  ] [${STEP_COUNTER}] STEP_FILE = ${STEP_FILE}"
    fi
}

function stepTmp() {
    if [ "${DS_PROJECT_ENV}" == "" ]; then
        export STEP_TMP="/tmp/${@}.${USER}.tmp"
    else
        export STEP_TMP="/tmp/${@}.${USER}.${DS_PROJECT_ENV}.tmp"
    fi
    echoDebugVar STEP_TMP
    if [ -f "${STEP_TMP}" ]; then
        rm -f "${STEP_TMP}"
    fi
}

function substep() {
    let SUBSTEP_COUNTER=SUBSTEP_COUNTER+1

    stepTmp "$@"

    if [ ${DS_QUIET} -eq 1 ]; then
        unset STEP_HELP
        return
    fi

    if [ ${DS_MARKDOWN} -eq 0 ]; then
        [ ${TPUT_SETAF_4} ] && echo -n ${TPUT_SETAF_4}
    fi
    if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
        echo
        echo -n "#### "
    fi
    #echo "Step ${STEP_COUNTER}.${SUBSTEP_COUNTER} - $@"
    if [ ${DS_TLDR} -eq 0 ]; then
        echo "${STEP_COUNTER}.${SUBSTEP_COUNTER} - $@"
    else
        if [ ${DS_MARKDOWN} -eq 0 ]; then
            echo
            echo "# ${STEP_COUNTER}.${SUBSTEP_COUNTER} - $@"
        else
            echo "*${STEP_COUNTER}.${SUBSTEP_COUNTER} - $@*<br>"
        fi
    fi
    if [ ${DS_TOC} -eq 0 ] && [ ${DS_TLDR} -eq 0 ]; then
        echo
    fi

    if [ ${DS_MARKDOWN} -eq 0 ]; then
        [ ${TPUT_SGR0} ] && echo -n ${TPUT_SGR0}
    fi

    stepHelp "$@"

    unset STEP_HELP

    stepTmp "$@"
    unset SUBSTEP_TMP
}

function waiting() {
    local sleep_seconds wait_msg

    if [ "${2}" != "" ]; then
        wait_msg="${2} "
    fi

    if [ "${DS_NOWAIT}" == "1" ]; then
        export DS_ECHO_STATUS="WAIT"
        1>&2 echoStatus "finish ${wait_msg}... NOT WAITING ${1} seconds !!"
        return
    fi

    if [[ "${1}" =~ [0-9]+ ]]; then
        sleep_seconds=${1}
    else
        sleep_seconds=60
    fi

    1>&2 echo
    for ((w=${sleep_seconds}; w>0; w=w-10)); do
        export DS_ECHO_STATUS="WAIT"
        1>&2 echoStatus "start ${wait_msg}... WAITING ${w} seconds (or hit C to continue) !!"
        read -t 10 C
        if [ "${C,,}" == "c" ]; then
            break
        fi
    done
    unset C w
    export DS_ECHO_STATUS="WAIT"
    1>&2 echoStatus "finish ${wait_msg}... CONTINUING !!"
    1>&2 echo
}

environmentVariables quiet

# for troubleshooting ...
# export DS_SOURCE=true
# export DS_NAME=xxx
# source include/${DS_BASENAME}-include.sh
# ... and do everything else manually
if [ ${#DS_SOURCE} -ne 0 ]; then
    if [ -r "${DS_DIR}/${DS_BASENAME}-source-${DS_NAME}.env" ]; then
        source "${DS_DIR}/${DS_BASENAME}-source-${DS_NAME}.env"
    else
        echoStatus "${DS_DIR}/${DS_BASENAME}-source-${DS_NAME}.env file not found readable"
    fi
fi
