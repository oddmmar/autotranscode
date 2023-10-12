#!/bin/bash

# Trancoding scipt - (2023) Odwa Majila

# A script used to automate the transcoding of News' TV material. The files are originally encoded in dvvideo
# and need to be transcoded in H264/x264 for video and the audio enccoding can be copied @pcm_s16le.
# Use wrapper .mp4. The aspect ratio must be the as source at 16x9, bit rate unspecified (SD@3.5M and HD@8.5M ??).
# The script caters for input files with the follwoing structure:
# V0, A1CH0, A2CH1 or V0, A1CH0:1 The output will alway be V0, A1CH0:1 Unique mono
#
# The output naming convention is as follows: YYYmmdd_fileName_CTN_RAW - capitlise?? The date comes from the file name
#

# Dependencies: neofetch, sqlite, ffmpeg

############################################## Declarations ####################################################

# WORK
destinationPath="/media/wctech/internal/3TBRUST/aspera"
logPath="/media/wctech/internal/500SSD/Transcoding"
sourcePath="/media/wctech/nas/TVARCHIVE/- AAA TO BE ARCHIVED AAA -"

# DEV
# destinationPath="/Volumes/DATA/media/Transcoding/DST"
# logPath="/Volumes/DATA/media/Transcoding/MANIFEST"
# sourcePath="/Volumes/DATA/media/transcoding/SRC"

# name of the db to keep track of completed jobs
database="${logPath}/archive.db"
# set default bit rate. chaned dynamicaly based on resolution
bitrate="10M" # SD
# filter for the recursive search
filter="raw"
# default extension, but assignable with -e flag
ext="mov"
# today's day
dateNow=$(date +%Y%m%d)
# log creation based on day (new log each new day)
log=$logPath/"${dateNow}.log"
# create log file
touch "$log"

################################################# OUTPUT #####################################################

# prints to a log file defined above. takes two arguments:
# $1 - message type
# $2 - message content
function printToLog() {
    # echo -e "$(date +"%T")\t$1\t\t$2" >> "$log"
    if [ "$1" == "Info:" ]; then
        echo "$(date +"%T")\t$1\t\t$2" >>"$log"
    fi
    if [ "$1" == "Warning:" ]; then
        echo "$(date +"%T")\t$1\t$2" >>"$log"
    fi
}

# prints to the console. takes two arguments:
# $1 - message type
# $2 - message content
function printToConsole() {
    if [ "$1" == "Info:" ]; then
        echo "$(date +"%T")\t$1\t\t$2"
    fi
    if [ "$1" == "Warning:" ]; then
        echo "$(date +"%T")\t$1\t$2"
    fi
}

touch contentfiile.txt

find "$sourcePath" -type f -print0 | while IFS= read -r -d $'\0' file; do
    if [[ "$file" =~ [m][o][v] ]]; then
        if [[ "$file" =~ [Rr][Aa][Ww] ]]; then
            echo "$file" >>contentfiile.txt
        fi
    fi
done

################################################# ----- #####################################################

# Check if an argument was provided
if [ $# -gt 0 ]; then
    # reassign variables
    while getopts "f:" flag; do
        case "${flag}" in
        f) inputFile=${OPTARG} ;;
        ?) printToConsole "Info:" "Hello" ;;
        esac
    done
fi

if [ ${#inputFile} == 0 ]; then
    printToConsole "Error:" "An ipnut file (-i) is needed."
    echo "An input file (-i) is needed."
    echo "Exiting"
    exit 0
fi

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

################################################## FILE ######################################################

# $1 - name to clean
function sanitizeFilename() {
    local newfilename=$(basename "$1" .$ext)
    newfilename=${newfilename// /_}
    newfilename=${newfilename//[^a-zA-Z_]/}
    newfilename=$(tr '[:lower:]' '[:upper:]' <<<"$newfilename")
    newName=$newfilename
}

# $1  - fle path
function getNames() {
    fileName="$(basename "$1")"
    sanitizeFilename "$1"
    # newName=$(basename "$1" .$ext) # needs fixing
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
        audioStreamCount=2
    else
        # for [0:1:0] [0:1:1]
        audioStreamCount=1
    fi

}

function transcode() {
    # S1 - input file
    # $2 - output file
    # NOTE
    # check constant bitrate
    # scan type - has to be kept interlaced (can't set this yet)

    # map all video channels and map all audio channels from in to out
    # ffmpeg -hide_banner -i "$1" -b:v "$bitrate" -c:v h264_nvenc -map 0:v -map 0:a "$2" -y
    ffmpeg -hide_banner -i "$1" -b:v "$bitrate" -c:v h264_videotoolbox -map 0:v -map 0:a "$2" -y
    didTranscode=$?
}

################################################### DB #######################################################

table="tracker"

function createTable() {
    # Use sqlite3 to check if the table exists
    if sqlite3 "$database" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
        printToConsole "Info:" "'$table' table already exists in the database."
    else
        printToConsole "Info:" "Table '$table' does not exist in the database. Will create..."
        sqlite3 "$database" "CREATE TABLE IF NOT EXISTS "$table" (id INTEGER PRIMARY KEY AUTOINCREMENT, \
         creationDate TEXT, engDate TEXT, sourcePath TEXT, fileName TEXT, originalSize REAL, destination TEXT, \
         newName TEXT,  newSize REAL, audioStreamCount INTEGER, resolution INTEGER, didTranscode INTEGER);"
    fi
}

function createRecord() {
    sqlite3 "$database" "INSERT INTO $table (creationDate, engDate, sourcePath, fileName, originalSize, destination, \
    newName, newSize, audioStreamCount, resolution, didTranscode) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $resolution, $didTranscode)"
}

################################################### EXEC ######################################################

function process() {
    # initialise
    init
    getNames "$inputFile"
    # gets file size in megabytes. updates a sizeInM variable
    getSize "$inputFile"
    originalSize=$sizeInM
    # updates the resolution variable with frame width
    getResolution "$inputFile"
    # updates the audioStreamCount variable
    getStreamCount "$inputFile"
    # get the date the story was shot. update engDate
    getDate "$fileName"
    if [ ${#engDate} == 0 ]; then
        printToConsole "Warning:" "File is missing a date."
        engDate="00000000"
    fi

    newFileName="${engDate}_${newName}_CTN.mp4"

    transcode "$inputFile" "$destinationPath/$newFileName"
    didTranscode="$?"

    getSize "${destinationPath}/${newFileName}"
    if [ "$?" == "" ]; then
        newSize=0
    else
        newSize=$sizeInM
    fi

    if [ "${didTranscode}" == 0 ]; then
        fileInfo="Name: ${fileName}, ENG Date: ${engDate}, Size: ${originalSize} M, Resolution: ${resolution}, Stream count: ${audioStreamCount}, New Name: ${newFileName}, New Sise: ${newSize} M"
        printToConsole "Info:" "$fileInfo"
        printToLog "Info:" "$fileInfo"
        createRecord "$dateNow" "$engDate" "'${sourcePath}'" "'${fileName}'" "$originalSize" "'${destinationPath}'" "'${newFileName}'" "$newSize" "$audioStreamCount"
    else
        printToConsole "Error::" "$fileName transcode not successful"
        printToLog "Error::" "$fileName transcode not successful"
    fi
}

################################################### EXEC ######################################################

if [ -e "$database" ]; then
    createTable
    if [[ "$inputFile" =~ [m][o][v] ]]; then
        if [[ "$inputFile" =~ [Rr][Aa][Ww] ]]; then
            printToLog "Info:" "Processing file ${inputFile}"
        else
            printToLog "Warning:" "NO DATE! processing ${inputFile}"
        fi
        if [ -e "$inputFile" ]; then
            process
        fi
    else
        printToConsole "Info:" "The script needs an .mov file. Please supply one and re-run"
        exit 0
    fi
else
    printToConsole "Info:" "DB not found"
    printToLog "Info:" "DB not found"
    touch "$database"
    printToConsole "Info:" "...file created, please rerun the script"
    printToLog "Info:" "...file created, please rerun the script"
    exit 0
fi

# //155.234.144.67/volume1/SPT-TVARCHIVE /media/wctech/nas/TVARCHIVE cifs username=admin,password='*Rbf!fbR*',vers=1.0 0 0
# sudo mount.cifs //155.234.144.67/SPT-TVARCHIVE /media/wctech/nas/TVARCHIVE username=admin,password='*Rbf!fbR*'
