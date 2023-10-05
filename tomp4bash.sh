#!/bin/bash

searchDir=./SRC
dstDir=./DST
logDir=./LOG
# default extension, but assignable with -e flag
ext="mov"

# log=$logDir/$(date +%Y-%m-%d_%H.%M.%S).log
log=$logDir/$(date +%Y-%m-%d).log
# create log file
touch "$log"

# prints to a log file defined above. takes two arguments: 
# $1 - message type
# $2 - message 
function printToLog() { 
    echo -e "$(date +"%T")\t$1\t$2" >> "$log"
}

# prints to the console. takes two arguments: 
# $1 - message type
# $2 - message 
function printToConsole() {
    if [ "$1" == "Info:" ]; then
        echo -e "$(date +"%T")\t$1\t\t$2"
    fi
    if [ "$1" == "Warning:" ]; then
        echo -e "$(date +"%T")\t$1\t$2"
    fi
}

# Check if an argument was provided
if [ $# -gt 0 ]; then 
# reassign variables
while getopts e:s: flag
    do
        case "${flag}" in
        # for -e
        e) ext=${OPTARG};;
        # for -s
        s) searchDir=${OPTARG};;
        esac
    done
fi


for file in $(find "$searchDir" -type f); do
    # process file only if it has the given extension
    if [ "${file##*.}" == "$ext" ]; then
        # Check if the filename contains "raw," "RAW," or "Raw" (case-insensitive)
        if echo "$file" | grep -iq 'raw'; then
            printToConsole "Info:" "Processing file ->\t$file"
        else
            printToConsole "Warning:" "Unprocessed file ->\t$file"
        fi
    fi
done
