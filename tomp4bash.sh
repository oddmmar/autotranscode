#!/bin/bash

searchDir="/Volumes/DATA/media/Transcoding/SRC"
dstDir="/Volumes/DATA/media/Transcoding/DST"
logDir="/Volumes/DATA/media/Transcoding/LOG"
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

# recursive search for every file in tehe given directory 
for file in $(find "$searchDir" -type f); do
    # check file existsnce
    if [  -e "$file" ]; then 
        # process file only if it has the given extension
        if [ "${file##*.}" == "$ext" ]; then
            # Check if the filename contains "raw," "RAW," or "Raw" (case-insensitive)
            if echo "$file" | grep -iq 'raw'; then
                printToConsole "Info:" "Processing file ->\t$file"
                printToLog "Info:" "Processing file ->\t$file"
                # get file information about the number of audio streams
                fileInfo=$(ffprobe -hide_banner -v error -select_streams a -show_entries stream=index -of csv=p=0 $file)
                # get length
                res=${#fileInfo}
                # Stream #0.1 -> #0.1 [channel: 0 -> 0]
                # Stream #0.2 -> #0.1 [channel: 0 -> 1]
                if [ $res == 3 ]; then
                    echo "Two audio streams with one channel -> 0:1:0, 0:2:0"
                    # ffmbc -i "$file" -target imx30 -map_audio_channel '0:1:0:0:1:0' -map_audio_channel '0:2:0:0:1:1' -y "$dstDir/$(date +%Y%m%d-%H.%M)_$actualName-RAW.mxf"
                fi
                # Stream #0.1 -> #0.1 [channel: 0 -> 0]
                # Stream #0.1 -> #0.1 [channel: 0 -> 1]
                if [ $res == 1 ]; then
                    echo "One audio stream with two channel -> 0:1:0, 0:1:1"
                    #  ffmbc -i "$file" -target imx30 -map_audio_channel '0:1:0:0:1:0' -map_audio_channel '0:1:1:0:1:1' -y "$dstDir/$(date +%Y%m%d-%H.%M)_$actualName-RAW.mxf"
                fi
            else
                printToConsole "Warning:" "Unprocessed file ->\t$file"
                printToLog "Warning:" "Unprocessed file ->\t$file"
            fi
        fi
    else 
        printToConsole "Error:" "File not found ->\t$file"
    fi
done
