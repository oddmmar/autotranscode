sourcePath="/Volumes/DATA/media/transcoding/SRC"
touch contentfiile.txt

find "$sourcePath" -type f -print0 | while IFS= read -r -d $'\0' file; do
    echo "$file" >>contentfiile.txt
done

# $ find "AAA TO BE ARCHIVED 2 AAA" -type f -name "*raw*" -print0 | xargs -0 ls -l > /media/wctech/internal/500SSD/Transcoding/raw2.txt
