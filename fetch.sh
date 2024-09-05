#!/bin/bash

ME=$0
MUTE=${MUTE-0}
NO_COLOR=${NO_COLOR-0}

#shellcheck disable=SC2034,SC2086
log () {
    if [ "$MUTE" = "1" ] ; then
        return
    fi
    if [ "$NO_COLOR" = "1" ] ; then
        ERROR=
        INFO=
        WARN=
        SQL=
        C_N=
    else
        ERROR='\033[1;31m'
        INFO='\033[1;32m'
        WARN='\033[1;33m'
        TRACE='\033[1;35m'
        DEBUG='\033[1;36m'
        SQL='\033[1;34m'
        C_N='\033[0m'
    fi
    level=INFO
    
    if [ -n "$1" ] ; then
        level=$1
        IN="${*:2}"
    else
        read -r IN
    fi

    local TS
    TS=$(date +%Y-%m-%d\ %H:%M:%S.%N)
    MM=
    
    if [ -n "$ME" ]; then
        MM=":$ME"
    fi

    echo -e "${C_N}${!level}${TS::-6} $HOSTNAME $level [$$$MM] $IN${C_N}"
}

if [ -z "$1" ] ; then
    log INFO "Usage: $0 <rtsp-url> [max-duration] [output-path] [tmp-output-path] [min-size]"
    exit 1
fi

URL=$1
MAX_DURATION=${2-${MAX_DURATION-28800}}
OUTPUT_PATH=${3-${OUTPUT_PATH-data}}
TMP_OUTPUT_PATH=${4-${TMP_OUTPUT_PATH-tmp}}
MIN_SIZE=${5-262144}
SKIP_FFPROBE=${SKIP_FFPROBE-0}
COOLDOWN=${COOLDOWN-1}
FILES=0

for i in OUTPUT_PATH TMP_OUTPUT_PATH; do
    if [ ! -e "${!i}" ] ; then
        mkdir -p "${!i}" &> /dev/null
    fi
done

# for i in $(cat list.txt | sort -R | grep -v admin | tail -n500) ; do ./fetch.sh $i &> /dev/null & done
# for i in $(cat list.txt | sort -R | tail -n10) ; do ./fetch.sh $i &> /dev/null & done

while true; do
    FN=$(echo "$URL" | cut -d'/' -f3 | cut -d':' -f1- | sed 's/[:@]/_/g')_$(date +%y%m%d%H%M%S).mp4
    TFN="${TMP_OUTPUT_PATH}/$FN"
    FFN="${OUTPUT_PATH}/$FN"
    DURATION=$((MAX_DURATION - SECONDS))
    
    log INFO "-- [$FILES] Fetching $URL to $TFN for ${DURATION}s"
    
    # -movflags +frag_keyframe+empty_moov+faststart    
    ffmpeg -thread_queue_size 1024 -i "$URL" \
        -t $DURATION -movflags +frag_keyframe+faststart \
        -fflags +genpts \
        -frag_duration 120000000 -max_delay 100000000 \
        -reorder_queue_size 1024 -bufsize 256M \
        -rtsp_transport tcp -c:v copy -nostdin "$TFN"
    
    if [ ! -e "$TFN" ] ; then
        log WARN "-- [$FILES] Failed to get any data from $URL"
        continue
    fi
    
    FSZ=$(stat -c %s "$TFN")

    if [ -z "$FSZ" ] || [ "$FSZ" -lt "$MIN_SIZE" ] ; then
        log WARN "-- [$FILES] File size is too small (less than $MIN_SIZE bytes), $URL"
        rm -f "$TFN" &> /dev/null
        continue
    fi

    FILES=$((FILES + 1))

    (
        if [ "$SKIP_FFPROBE" -eq "0" ] ; then
            log INFO "-- [$FILES] Testing: $TFN"
            ffprobe "$TFN"
            RT=$?
            
            if [ "$RT" -ne "0" ] ; then
                log ERROR "-- [$FILES] Failed to ffprobe $TFN"
                rm -f "$TFN" &> /dev/null
                exit 1
            fi
            log INFO "-- [$FILES] Test successful for: $TFN"
        fi
        
        log INFO "-- [$FILES] Moving $TFN to $FFN"
        mv -vf "$TFN" "$FFN"
    ) &
    
    if [ "$SECONDS" -lt "$MAX_DURATION" ] ; then
        log DEBUG "-- [$FILES] Sleeping for $COOLDOWN seconds"
        sleep "${COOLDOWN}"
    else
        break
    fi
done

wait
log INFO "-- Completed, $URL total duration: ${SECONDS}s, ${FILES} files."

