#!/bin/bash

# A script used to automate the transcoding of News' TV material. The files are originally encoded in dvvideo
# and need to be transcoded in H264/x264 for video and the audio enccoding can be copied @pcm_s16le.
# Use wrapper .mp4. The aspect ratio must be the as source at 16x9, bit rate unspecified (SD@3.5M and HD@8.5M ??).
# The script caters for input files with the follwoing structure:
# V0, A1CH0, A2CH1 or V0, A1CH0:1 The output will alway be V0, A1CH0:1 Unique mono
#
# The output naming convention is as follows: YYYmmdd_SLUG_CTN_RAW - capitlise?? The date comes from the file name
#
# archive.db table structure:
#   - id
#   - archiveDir (absolute path minus mount point)
#   - slug
#   - originalSizeM (du -m)
#   - format (SD/HD)
#   - engDate (story date, contained in the file name)
#   - adudioStreams
#   - isProcessed
#   - didPass
#   - newName
#   - newSizeM
#   -
#   -

############################################## Declarations ####################################################

searchDir="/Volumes/DATA/media/transcoding/SRC"
# searchDir="/Volumes/Seapoint_Archive_NAS_Drive"
dstDir="/Volumes/DATA/media/Transcoding/DST"
logDir="/Volumes/DATA/media/Transcoding/LOG"
database="archive.db"
# default extension, but assignable with -e flag
ext="mov"
# log=$logDir/$(date +%Y-%m-%d_%H.%M.%S).log
log=$logDir/$(date +%Y-%m-%d).log
# create log file
touch "$log"

################################################# OUTPUT #####################################################

# prints to a log file defined above. takes two arguments:
# $1 - message type
# $2 - message
function printToLog() {
    # echo -e "$(date +"%T")\t$1\t\t$2" >> "$log"
    if [ "$1" == "Info:" ]; then
        echo -e "$(date +"%T")\t$1\t\t$2" >>"$log"
    fi
    if [ "$1" == "Warning:" ]; then
        echo -e "$(date +"%T")\t$1\t$2" >>"$log"
    fi
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

################################################## FILE ######################################################

function getDate() {
    # Use grep with a regular expression to extract 5 to 6 consecutive digits
    date=$(grep -oE '[0-9]{5,6}' <<<"$1")
    # printToConsole "Info:" "date ${#date}"
    if [ ${#date} != 0 ]; then
        # printToConsole "Info:" "$1"
        fullDate=""
        engDate=""
        lastTwoDigits="${date:4:2}"
        # Determine the century for the year (assumed to be 20 for 00-49 and 19 for 50-99)
        if [[ "$lastTwoDigits" -ge 0 && "$lastTwoDigits" -le 49 ]]; then
            year="20$lastTwoDigits"
        else
            year="19$lastTwoDigits"
        fi

        # cater for one condition. distinguishing between month or day short, too lengthy
        if [ ${#date} == 6 ]; then
            fullDate="${date:0:4}$year"
        # elif [ ${#date} == 5 ]; then
        #     fullDate="0${date:0:3}${year}"
        else
            printToConsole "Error:" "Date format is incorrect"
        fi
        # printToConsole "Info:" "full date $fullDate"
        engDate="${fullDate:4:4}${fullDate:2:2}${fullDate:0:2}"
        # echo "$engDate"
    else
        printToConsole "Error:" "Date format is incorrect, file connot be processed"
    fi
}

archiveDir="$(basename "$searchDir")"
archiveDirFile="$archiveDir".txt
touch "$archiveDirFile"
find "$searchDir" -type f | grep -i raw >>"$archiveDirFile"

################################################### DB #######################################################

table="archive"

function createTable() {
    # Use sqlite3 to check if the table exists
    if sqlite3 "$database" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
        printToConsole "Info:" "Table '$table' already exists in the database."
    else
        printToConsole "Info:" "Table '$table' does not exist in the database. Will create..."
        sqlite3 "$database" "CREATE TABLE IF NOT EXISTS "$table" (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER);"
    fi
}

function populteDb() {
    while IFS= read -r line; do
        baseName="$(basename "$line")"
        dirName="$(dirname "$line")"
        getDate "$(basename "$line")"
    done <"$archiveDirFile"
}

if [ -e "$database" ]; then
    # printToConsole "Info:" "DB found"
    # createTable
    populteDb
else
    printToConsole "Info:" "DB not found"
    touch "$database"
    printToConsole "Info:" "...file created, please rerun teh script"
    exit 0
fi

################################################# ----- #####################################################

# Check if an argument was provided
if [ $# -gt 0 ]; then
    # reassign variables
    while getopts e:s: flag; do
        case "${flag}" in
        # for -e
        e) ext=${OPTARG} ;;
        # for -s
        s) searchDir=${OPTARG} ;;
        esac
    done
fi

# # recursive search for every file in tehe given directory
# for file in $(find $searchDir -type f -print0  ); do
#     echo -e "FILE: ${file}"
#     # check file existsnce
#     if [  -e "$file" ]; then
#         # process file only if it has the given extension
#         if [ "${file##*.}" == "$ext" ]; then
#             # Check if the filename contains "raw," "RAW," or "Raw" (case-insensitive)
#             if echo "$file" | grep -iq 'raw'; then
#                 printToConsole "Info:" "Processing file ->\t$file"
#                 printToLog "Info:" "Processing file ->\t$file"
#                 # get file information about the number of audio streams
#                 fileInfo=$(ffprobe -hide_banner -v error -select_streams a -show_entries stream=index -of csv=p=0 $file)
#                 # get length
#                 res=${#fileInfo}
#                 # Stream #0.1 -> #0.1 [channel: 0 -> 0]
#                 # Stream #0.2 -> #0.1 [channel: 0 -> 1]
#                 if [ $res == 3 ]; then
#                     echo "Two audio streams with one channel -> 0:1:0, 0:2:0"
#                     # ffmbc -i "$file" -map_audio_channel '0:1:0:0:1:0' -map_audio_channel '0:2:0:0:1:1' -y "$dstDir/$(date +%Y%m%d-%H.%M)_$actualName-RAW.mxf"
#                 fi
#                 # Stream #0.1 -> #0.1 [channel: 0 -> 0]
#                 # Stream #0.1 -> #0.1 [channel: 0 -> 1]
#                 if [ $res == 1 ]; then
#                     echo "One audio stream with two channel -> 0:1:0, 0:1:1"
#                     #  ffmbc -i "$file" -map_audio_channel '0:1:0:0:1:0' -map_audio_channel '0:1:1:0:1:1' -y "$dstDir/$(date +%Y%m%d-%H.%M)_$actualName-RAW.mxf"
#                 fi
#             else
#                 printToConsole "Warning:" "Unprocessed file (no raw) ->\t$file"
#                 printToLog "Warning:" "Unprocessed file (no raw) ->\t$file"
#             fi
#         fi
#     else
#         printToConsole "Error:" "File not found ->\t$file"
#     fi
# done

# map all video channels and map all audio channels from in to out
# ffmpeg -hwaccel videotoolbox  -i ARGUS\ raw.mov -b:v 10M -c:v h264_videotoolbox -map 0:v -map 0:a  ARGUS_RAW_10.mov
# NOTE
# check constant bitrate
#  sacn type - has to be kept interlaced (can't set this)
