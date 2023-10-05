#!/bin/bash

# A media file can have multiple tracks/streams?? of audio, and each track can have 1 or more channels.
# This script to convert or transcode the given file format to .mxf
# srcDir:   the source directory
# dstDir:  the destination directory.
# map_audio_channel in file.stream:channel:out file.stream[:channel]  set audio channel extraction on stream
# Stream mapping:
#   (V)Stream #0.0 -> #0.0
#   (A1)Stream #0.1 -> #0.1 [channel: 0 -> 0]
#   (A2)Stream #0.2 -> #0.1 [channel: 0 -> 1]
#
# NOTES
# [mxf_d10 @ 0x7fcec700ec00] MXF D-10 only supports one audio track !!

srcDir=./SRC
dstDir=./DST
logDir=./LOG
doneDir=./DONE
ext=.mov
# log=$logDir/$(date +%Y-%m-%d_%H.%M.%S).log
log=$logDir/$(date +%Y-%m-%d).log
# create log file
touch "$log"

# prints to a log file defined above. takes two arguments: 
# $1 - message type
# $2 - message 
function printToLog() { ou
    echo -e "$(date +"%T")\t$1\t$2" >> "$log"
}

# prints to the console. takes two arguments: 
# $1 - message type
# $2 - message 
function printToConsole() {
    echo -e "$(date +"%T")\t$1\t$2"
}

# while getopts a: flag
#     do
#         case "${flag}" in
#         a) app=${OPTARG}
#         esac
#     done
# echo "app chosen: $app"

for file in $srcDir/*$ext
    do
        actualName=$(basename "$file" $ext)
        if [ -e  "$dstDir/$actualName.mxf" ] ; then
            printToLog "Error" "File already processed\t\t$file" 
            printToConsole "Error" "File already processed\t\t$file" 
        else
            if [ -e "$file" ]; then
                # get file information about the number of audio streams
                fileInfo=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 $file)
                # get length
                res=${#fileInfo}
                # Stream #0.1 -> #0.1 [channel: 0 -> 0]
                # Stream #0.2 -> #0.1 [channel: 0 -> 1]
                if [ $res == 3 ]; then
                    echo "Two streams, one channel each"
                    ffmbc -i "$file" -target imx30 -map_audio_channel '0:1:0:0:1:0' -map_audio_channel '0:2:0:0:1:1' -y "$dstDir/$(date +%Y%m%d-%H.%M)_$actualName-RAW.mxf"
                fi
                # Stream #0.1 -> #0.1 [channel: 0 -> 0]
                # Stream #0.1 -> #0.1 [channel: 0 -> 1]
                if [ $res == 1 ]; then
                    echo "One stream, two channels"
                     ffmbc -i "$file" -target imx30 -map_audio_channel '0:1:0:0:1:0' -map_audio_channel '0:1:1:0:1:1' -y "$dstDir/$(date +%Y%m%d-%H.%M)_$actualName-RAW.mxf"
                fi
                printToLog "Info" "File processed successfully\t$file"
                mv "$file" "$doneDir"
                printToLog "Info" "File\t$file \tmoved to $doneDir"
            else 
                printToLog "Info" "Directory is empty or no compatible files were found"
                printToConsole "Info" "Directory is empty or no compatible files were found"
            fi
        fi
    done
echo -e "\n"


#       |            |
#       |            |
#   A1  |     O      |     O
#       |____________|___________
#       |            |
#   A2  |     O      |     X
#       |            |
#       |____________|___________
#           CH 0        CH 1
#


