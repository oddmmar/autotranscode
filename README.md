# Transcode Script

This is a Bash script that performs transcoding of video files from a source directory to a destination directory. Here's an overview of what the script does:

**Declarations**: The script defines several variables, such as the source and destination paths, log file path, database file path, and default bit rate.

**Functions**:

* `printToLog:` Prints messages to a log file with a timestamp and message type (Info or Warning).
* `printToConsole:` Prints messages to the console with a timestamp and message type.
* `sourceDirectoryList:` Generates a list of files in a given directory that match a specific pattern (raw files with .mov extension).

**Helper Functions:**

* The script checks for command-line arguments (-f for input file and -l for directory listing).
* If an input file is provided, it sets the source path, creates a directory listing file, and populates it with the files in the source directory.

**Initialization Function:**

* `init:` Creates a file named after the archive directory and recursively searches for files in the source directory matching the filter pattern.
  
**File Processing Functions:**

* `sanitizeFilename:` Cleans the filename by removing spaces and non-alphanumeric characters.
* `getNames:` Extracts the filename and directory name from the input file path.
* `getDate:` Extracts the date from the filename using a regular expression.
* `getSize:` Gets the size of the input file in megabytes.
* `getResolution:` Determines the resolution of the input file and sets the appropriate bit rate.
* `getStreamCount:` Counts the number of audio streams in the input file.
* `transcode:` Performs the transcoding of the input file to the destination file using FFmpeg, mapping both video and audio streams.
  
**Database Functions:**

* `createTable:` Creates a table named "tracker" in the database if it doesn't exist.
* `createRecord:` Inserts a new record into the "tracker" table with various details about the transcoded file.
  
**Process Function:**

* `process:` Orchestrates the entire transcoding process by calling the helper functions, performing the transcoding, and creating a record in the database.

**Execution:**

* The script checks if the database file exists. If not, it creates the file.
* If an input file is provided and matches the expected pattern, the script calls the process function to transcode the file.

The script is designed to automate the transcoding of news TV material from a specific input format (dvvideo) to H.264/x264 video and PCM audio (pcm_s16le) with an MP4 container. It maintains a SQLite database to keep track of the transcoded files and their metadata.
Note: The script assumes that the required dependencies (FFmpeg, SQLite) are installed and accessible in the system's PATH.

## House Formats

```
IMX 30
IMX 50
XDCAM HD 50
AVC-Intra 100
```
