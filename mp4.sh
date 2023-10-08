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
#   - originalSize (du -m)
#   - resolution (SD/HD)
#   - engDate (story date, contained in the file name)
#   - adudioStreamCount
#   - didTranscode
#   - didPass
#   - newName
#   - newSize
#   -
#   -

# Dependencies: neofetch

############################################## Declarations ####################################################

destinationPath="/Volumes/DATA/media/Transcoding/DST"
sourcePath="/Volumes/DATA/media/transcoding/SRC"
# sourcePath="/Volumes/Seapoint_Archive_NAS_Drive"
logPath="/Volumes/DATA/media/Transcoding/LOG"
# name of the db to keep track of completed jobs
database="archive.db"
# set default bit rate. chaned dynamicaly based on resolution
bitrate="10M" # SD
# filter for the recursive search
filter="raw"
# default extension, but assignable with -e flag
ext="mov"
# log creation based on day (new log each new day)
log=$logPath/$(date +%Y-%m-%d).log
# create log file
touch "$log"

################################################# ----- #####################################################

# Check if an argument was provided
if [ $# -gt 0 ]; then
    # reassign variables
    while getopts e:s: flag; do
        case "${flag}" in
        # for -e
        e) ext=${OPTARG} ;;
        # for -s
        s) sourcePath=${OPTARG} ;;
        esac
    done
fi

################################################# OUTPUT #####################################################

# prints to a log file defined above. takes two arguments:
# $1 - message type
# $2 - message content
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
# $2 - message content
function printToConsole() {
    if [ "$1" == "Info:" ]; then
        echo -e "$(date +"%T")\t$1\t\t$2"
    fi
    if [ "$1" == "Warning:" ]; then
        echo -e "$(date +"%T")\t$1\t$2"
    fi
}

################################################# HELPER #####################################################

# initialise by creating the neccessary infrastructure
function init() {
    # just the directory name from the absolute path containg the archive content
    archiveDir="$(basename "$sourcePath")"
    # create a file named after the actual archive directory
    archiveListFile="$archiveDir".txt
    touch "$archiveListFile"
    # recursively search the archive using the filter variable
    find "$sourcePath" -type f | grep -i $filter >>"$archiveListFile"
}

function getUtilites() {
    local depNeofetch=$(which neofetch)
    local depSqlite=$(which sqlite3)

    if [[ ${#depNeofetch} == 0 || 4{#depSqlite} == 0 ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            brew install neofetch
            brew install sqlite
        elif [[ "$(uname)" == "Linux"* ]]; then
            sudo apt install neofetch
            sudo apt install sqlite3
        fi
    fi
}

################################################## FILE ######################################################

# $1  - fle path
function getNames() {
    baseName="$(basename "$1")"
    newName=$(basename "$1" .$ext)
    dirName="$(dirname "$1")"
}

function getDate() {
    engDate=""
    # Use grep with a regular expression to extract 5 to 6 consecutive digits
    date=$(grep -oE '[0-9]{5,6}' <<<"$1")
    # cater for one condition only mmddYY. distinguishing between month or day short, too lengthy
    if [ ${#date} == 6 ]; then
        fullDate=""
        lastTwoDigits="${date:4:2}"
        # Determine the century for the year (assumed to be 20 for 00-49 and 19 for 50-99)
        if [[ "$lastTwoDigits" -ge 0 && "$lastTwoDigits" -le 49 ]]; then
            year="20$lastTwoDigits"
        else
            year="19$lastTwoDigits"
        fi
        fullDate="${date:0:4}$year"
        engDate="${fullDate:4:4}${fullDate:2:2}${fullDate:0:2}"
    else
        printToConsole "Error:" "Date format is incorrect, file connot be processed"
    fi
}

function getSize() {
    # only get the size, not the directory names
    sizeInM=$(du -ms "$1" | cut -f1)
}

function getResolution() {
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$1")
    if [ "$resolution" == 1080 ]; then
        bitrate="30M"
    else
        bitrate="10M"
    fi
}

function getStreamCount() {
    aCount=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1")
    if [ ${#aCount} == 3 ]; then
        # for [0:1:0] [0:2:0]
        adudioStreamCount=2
    else
        # for [0:1:0] [0:1:1]
        adudioStreamCount=1
    fi

}

function transcode() {
    # NOTE
    # check constant bitrate
    # scan type - has to be kept interlaced (can't set this yet)

    # map all video channels and map all audio channels from in to out
    getUtilites
    if [[ "$(uname)" == "Darwin" ]]; then
        local hw=$(neofetch | grep -i amd)
        # no hw codec possible
        if [ ${#hw} == 0 ]; then
            # software render
            ffmpeg -hide_banner -i "$1" -b:v "$bitrate" -c:v h264 -map 0:v -map 0:a "$2" -y
            ret=$?
        else
            # hardware render
            ffmpeg -hide_banner -hwaccel videotoolbox -i "$1" -b:v "$bitrate" -c:v h264_videotoolbox -map 0:v -map 0:a "$2" -y
            ret=$?
        fi
    elif [[ "$(uname)" == "Linux"* ]]; then
        local hw=$(neofetch | grep -i nvidia)
        # no hw codec possible
        if [ ${#hw} == 0 ]; then
            # software render
            ffmpeg -hide_banner -i "$1" -b:v "$bitrate" -c:v h264 -map 0:v -map 0:a "$2" -y
            ret=$?
        else
            # hardware render
            ffmpeg -hide_banner -hwaccel cuda -i "$1" -b:v "$bitrate" -c:v h264_nvenc -map 0:v -map 0:a "$2" -y
            ret=$?
        fi
    fi
    if [ $ret == 0 ]; then
        didTranscode=true
    else
        didTranscode=false
    fi
    echo $didTranscode
}

################################################### DB #######################################################

table="archive"

function createTable() {
    # Use sqlite3 to check if the table exists
    if sqlite3 "$database" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
        printToConsole "Info:" "'$table' table already exists in the database."
    else
        printToConsole "Info:" "Table '$table' does not exist in the database. Will create..."
        sqlite3 "$database" "CREATE TABLE IF NOT EXISTS "$table" (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER);"
    fi
}

# function createRecord() {}
# function readRecord() {}
# function updateRecord() {}
# function deleteRecord() {}

function iterate() {
    init
    while IFS= read -r line; do
        getNames "$line"
        # get the date the story was shot. update engDate
        getDate "$baseName"
        # gets file size in megabytes. updates a sizeInM variable
        getSize "$line"
        # originalSize=$sizeInM
        # updates the resolution variable with frame width
        getResolution "$line"
        # updates the adudioStreamCount variable
        getStreamCount "$line"
        # echo "$adudioStreamCount"
        # "$destinationPath/$(date +%Y%m%d-%H.%M)_$actualName-RAW.mxf"
        # echo $engDate
        if [ ${#engDate} == 8 ]; then
            transcode "$line" "$destinationPath/"$engDate"_$newName.mp4"
        else
            printToConsole "Warning:" "File is missing a date"
        fi
    done <"$archiveListFile"
}

if [ -e "$database" ]; then
    printToConsole "Info:" "DB found"
    createTable
    iterate
else
    printToConsole "Info:" "DB not found"
    touch "$database"
    printToConsole "Info:" "...file created, please rerun the script"
    exit 0
fi

## WHILE DEBUGGGING
rm "$archiveListFile"