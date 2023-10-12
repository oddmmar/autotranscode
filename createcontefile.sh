sourcePath="/Volumes/DATA/media/transcoding/SRC"
touch contentfiile.txt

find "$sourcePath" -type f -print0 | while IFS= read -r -d $'\0' file; do
    echo "$file" >>contentfiile.txt
done
