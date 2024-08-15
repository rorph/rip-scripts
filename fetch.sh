#!/bin/bash

if [ -z "$1" ] ; then
    echo "Usage: $0 <rtsp-url> [max-duration] [output-path]"
    exit 1
fi

URL=$1
MAX_DURATION=${2-${MAX_DURATION-28800}}
OUTPUT_PATH=${3-${OUTPUT_PATH-data}}

if [ ! -e "$OUTPUT_PATH" ] ; then
    mkdir -p "$OUTPUT_PATH" &> /dev/null
fi

# for i in $(cat list.txt | sort -R | tail -n1000) ; do nohup ./fetch.sh $i > /tmp/nohup.out 2>&1 & done

while true; do
    FN="${OUTPUT_PATH}/$(echo $URL | cut -d'/' -f3 | cut -d':' -f1- | sed 's/[:@]/_/g')_$(date +%y%m%d%H%M%S).mp4"
    DURATION=$((MAX_DURATION - SECONDS))
    
    ffmpeg -thread_queue_size 1024 -i $URL \
        -t $DURATION -movflags +frag_keyframe+empty_moov+faststart \
        -frag_duration 60000000 -max_delay 60000000 \
        -reorder_queue_size 1024 -bufsize 128M \
        -rtsp_transport tcp -c:v copy $FN
    
    if [ "$SECONDS" -lt "$MAX_DURATION" ] ; then
        sleep 1
    else
        break
    fi
done

echo "-- Completed, $URL"

