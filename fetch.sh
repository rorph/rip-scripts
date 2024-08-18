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
# for i in $(cat list.txt | sort -R | tail -n10) ; do ./fetch.sh $i &> /dev/null & done

while true; do
    FN="${OUTPUT_PATH}/$(echo $URL | cut -d'/' -f3 | cut -d':' -f1- | sed 's/[:@]/_/g')_$(date +%y%m%d%H%M%S).mp4"
    DURATION=$((MAX_DURATION - SECONDS))
    # -movflags +frag_keyframe+empty_moov+faststart
    ffmpeg -thread_queue_size 1024 -i $URL \
        -t $DURATION -movflags +frag_keyframe+faststart \
        -fflags +genpts \
        -frag_duration 120000000 -max_delay 100000000 \
        -reorder_queue_size 1024 -bufsize 256M \
        -rtsp_transport tcp -c:v copy -nostdin $FN
    
    if [ "$SECONDS" -lt "$MAX_DURATION" ] ; then
        sleep 1
    else
        break
    fi
done

echo "-- Completed, $URL"

