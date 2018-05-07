#!/bin/bash

# sync_images.sh: Sync collection of JPEG2000s to a directory of TIFF files

# TODO:
# CRON schedule: weekly (Mon at 3am?)

SRC_DIR="/path/to/PM-Tiffs"
DEST_DIR="/path/to/JP2s"
TEMP_DIR="/var/tmp"

OVERWRITE=false

KAKADU_OPTS="-rate 2.4,1.48331273,.91673033,.56657224,.35016049,.21641118,.13374944,.08266171 \
 Creversible=yes Clevels=7 Cblk={64,64} \
 Cuse_sop=yes Cuse_eph=yes Corder=RLCP ORGgen_plt=yes ORGtparts=R \
 Stiles={1024,1024} \
 -double_buffering 10 \
 -num_threads 4 \
 -no_weights"

KAKADU_PATH="/opt/kakadu/bin"

try_compress() {

    source_image="$1"
    destination_image="$2"

    temp_file="$TEMP_DIR/$( basename "$destination_image" )"

    set +e
    "$KAKADU_PATH"/kdu_compress -quiet $KAKADU_OPTS -i "$source_image" -o "$temp_file"
    file_size_kb=`du -k "$temp_image" | cut -f1`

    if [ "$?" -ne 0 ] || [ "$file_size_kb" -lt 8 ]; then # Kakadu failed or something went wrong

        # If kakadu failed, retry with a stripped profile (and force TIFF decompression)
        rm "$temp_file"

        name=$(basename "$source_image")
        temp_file="$TEMP_DIR/${name%.*}.tif"

        depth=`identify -quiet -format "%z" "$source_image[0]"`

        if [[ $depth == 16 ]]; then
            temp_8bit="$TEMP_DIR/8_bit${name%.*}.tif"
            convert "$source_image" -depth 8 "$temp_8bit"
            ./convert_profile.py "$temp_8bit" --output "$temp_file"
            rm "$temp_8bit"
        else 
            ./convert_profile.py "$source_image" --output "$temp_file"
        fi

        "$KAKADU_PATH"/kdu_compress -quiet $KAKADU_OPTS -i "$temp_file" -o "$destination_image"
        
        if [ "$?" -ne 0 ]; then
            echo "*** sync_images.sh $source_image: Compression failed even after profile stripping, skipping this file"
            rm "$destination_image"
        fi

        rm "$temp_file"

    else # Everything went well so copy into place
        mv "$temp_file" "$destination_image"
    fi

    set -e

}

# MARK: - Parse args

for i in "$@" ; do

    case "$i" in
        --source-dir=*)
        SRC_DIR="${i#*=}"
        shift
        ;;
        --destination-dir=*)
        DEST_DIR="${i#*=}"
        shift
        ;;
        --overwrite)
        OVERWRITE=true
        shift
        ;;
        *)
        echo "sync_images.sh: sync a directory of source images to a directory of compressed JPEG2000 files."
        echo ""
        echo "./sync_images.sh"
        echo "==================="
        echo "--source-dir=DIR , Source directory (with images to be copied), should be an absolute path"
        echo "--destination-dir=DIR , Destination directory (where to copy/compress the files), should be an absolute path"
        echo "--overwrite , Overwrite existing files in destination"
        echo "" 
        exit
    esac
done

for image in "$SRC_DIR"/* ; do

    image_name=$(basename "$image")
    jp2="$DEST_DIR"/"${image_name%.*}.jp2"

    if [ -f "$jp2" ] && [ "$OVERWRITE" = false ]; then
        echo "A file named $jp2 already exists, skipping"
        continue
    else
        echo "Compressing $image"
        try_compress "$image" "$jp2"
    fi

done