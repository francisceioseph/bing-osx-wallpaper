#!/bin/bash

# Parse opts
while getopts ":d:v:b:" opt; do
  case $opt in
    d) IMAGE_DIR="$OPTARG"
    ;;
    v) VERBOSE="$OPTARG"
    ;;
    b) DATABASE_FILE="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# Not set default to non-verbose
if [ -z $VERBOSE ]; then
	VERBOSE=0
else
	VERBOSE=1
fi

# Need an image dir
if [ -z $IMAGE_DIR ]; then
	echo ""
	echo "-(d)irectory required to read latest image from"
	echo ""
	exit
fi

if [ -z "$DATABASE_FILE" ]; then
	echo ""
	echo "-data(b)ase) required to set desktop image"
	echo ""
	exit
fi

if [ $VERBOSE == 1 ]; then echo "Using image dir: $IMAGE_DIR"; fi


###################
#    FUNCTIONs    #
###################

# Function to grab image from bing
get_image ()
{

	# Make dir if it doesn't exist
	mkdir -p $IMAGE_DIR

	base_url="http://bing.com"
	base_image_url=`/usr/bin/curl -s "http://www.bing.com/HPImageArchive.aspx?format=xml&idx=0&n=1&mkt=en-US" |grep "url" | sed 's/^.*<urlBase>//' | sed 's/<\/urlBase>.*$//'`
	ext="_1920x1080.jpg"

	if [ $VERBOSE == 1 ]; then echo "Downloading $base_url$base_image_url$ext"; fi

	# Setup new latest file info
	LATEST_FILE=`echo "$base_url$base_image_url$ext" | sed 's/.*\///'`
	LATEST="$IMAGE_DIR/$LATEST_FILE"

	# Get and touch to change modify date
	/usr/local/bin/wget -q -O $LATEST "$base_url$base_image_url$ext"; sleep 15; touch $LATEST;

	if [ $VERBOSE == 1 ]; then echo "Created $LATEST"; fi
}


#####################
#       MAIN        #
#####################

# Get latest file from image dir
LATEST_FILE=`ls -tp $IMAGE_DIR | grep -v /$ | head -1`
LATEST="$IMAGE_DIR/$LATEST_FILE"
if [ $VERBOSE == 1 ]; then echo "Latest wallpaper: $LATEST"; fi

# Get current desktop image
CURRENT=`sqlite3 ~/Library/Application\ Support/Dock/desktoppicture.db "select value from data WHERE value !='$LATEST' limit 1" | cat`
if [ $VERBOSE == 1 ]; then echo "Current wallpaper: $CURRENT"; fi

# Figure out last update date
TODAY=`date +%F`
LAST_UPDATE=`stat -t '%Y-%m-%d' -f '%Sm' $LATEST`
if [ $VERBOSE == 1 ]; then echo "Last update was $LAST_UPDATE - today is $TODAY"; fi

# Last update wasn't today, get a new image
if [ "$LAST_UPDATE" != "$TODAY" ]; then
	if [ $VERBOSE == 1 ]; then echo "No image found for today, fetching new image"; fi
	get_image
fi

# If current is blank, nothing to update
# If we have a new file in the directory OR the date changed, update
if [ "$CURRENT" != "" ] && [ "$LATEST" != "$CURRENT" ] || [ "$LAST_UPDATE" != "$TODAY" ]; then
	if [ $VERBOSE == 1 ] && [ "$LATEST" != "$CURRENT" ]; then
		echo "Latest != Current - $LATEST != $CURRENT"
	fi
	if [ $VERBOSE == 1 ] && [ "$LAST_UPDATE" != "$TODAY" ]; then
		echo "Last update != Today - $LAST_UPDATE != $TODAY"
	fi
	if [ $VERBOSE == 1 ]; then echo "Newer image found, updating..."; fi
	`/usr/bin/sqlite3 "$DATABASE_FILE" "update data set value = '$LATEST'" && killall Dock`
fi
