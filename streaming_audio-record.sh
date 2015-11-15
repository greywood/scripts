#!/bin/bash
#
# Created at keystreams.net (2014.6)
#
# Description
# -----------
# Streaming Audio: Record - Record streaming audio w/ mplayer, encode into mp3 with lame, tag with id3v2.
#
# Usage
# -----
# streaming_audio-record.sh URL ARTIST ALBUM DURATION GENRE
#
# Example
# -------
# Record the radio station CKUA's "World Spinning" broadcast, a 2 hour program of World Music:
#
# streaming_audio-record.sh "http://ckua.streamon.fm:8000/CKUA-64k-m.mp3" "CKUA" "World Spinning" "02:00:00" "World Music"

# set some variables
SAVE_DIR="/path/to/dir"
TMP_DIR="/tmp"

#-----------

DATE_START=$(date +"%Y.%m.%d.%H.%M.%S")
YEAR=$(date +"%Y")
STREAM="${1}"
ARTIST="${2}"
ALBUM="${3}"
DURATION="${4}" # format: hh:mm:ss. eg: 2 hours = 02:00:00
TITLE="${DATE_START} +${DURATION}"
GENRE="${5}"
MAILTO="greywood@localhost"

# mplayer cache settings
MPLAYER_CACHE=2048
MPLAYER_CACHE_MIN=25

function format_dir_name() {

  dir_name="${1}"
  dir_name=$(echo "${dir_name//[^a-zA-Z0-9-]/ }" | tr [:upper:] [:lower:]) # make POSIX friendly and all characters to lower case
  dir_name="${dir_name//  /-}" # make double spaces (put in by the previous line of script) a hyphen (-)
  dir_name="${dir_name// /_}" # make spaces underscores (_)
  dir_name="${dir_name//_-_/-}" # make underscore hyphen underscore (_-_) only a hyphen
  
  echo "${dir_name}"

}

# format the save directory, adding the stream info
dir_name=$(format_dir_name "${ARTIST}-${ALBUM}")
SAVE_DIR="${SAVE_DIR}/${dir_name}"

# create tmp file
TMP_FILE=$(mktemp --suffix=".wav" -p "${TMP_DIR}")

# process the duration and get the date_end
OIFS=$IFS
IFS=':'
darray=($DURATION)
IFS=$OIFS
DATE_END=$(date --date="+${darray[0]} hour +${darray[1]} minute +${darray[2]} second" +"%Y.%m.%d.%H.%M.%S")

# set SAVE_FILE
SAVE_FILE="${SAVE_DIR}/${DATE_START}-${DATE_END}"

# create the save dir
mkdir -p "${SAVE_DIR}"

#  trap to remove on signal
trap_handler() {

  # mp3 encoding
  lame -m s "${TMP_FILE}" -o "${SAVE_FILE}.mp3"

  # tag
  id3v2 -a "${ARTIST}" -A "${ALBUM}" -t "${TITLE}" -g "${GENRE}" -y "${YEAR}" "${SAVE_FILE}.mp3"

  # move the tracklist
  mv "${TMP_DIR}/${DATE_START}-${DATE_END}-tracklist.txt" "${SAVE_DIR}/${DATE_START}-${DATE_END}-tracklist.txt"

  rm -fr "${TMP_FILE}"
  #rm -fr "${TMP_DIR}/${DATE_START}-${DATE_END}-tracklist.txt"
  
  cat "${SAVE_DIR}/${DATE_START}-${DATE_END}-tracklist.txt" | mail -s "${ARTIST} - ${ALBUM} (tracklist)" "${MAILTO}"

  }
trap trap_handler EXIT SIGINT SIGTERM SIGQUIT SIGHUP

# record stream
# without cache, forces ffmp3 (ffmpeg mp3 codec) to get rid of errors
mplayer -quiet -nocache -ac ffmp3 "${STREAM}" -ao pcm:waveheader:file="${TMP_FILE}" -vc dummy -vo null -endpos "${DURATION}" | tee "${TMP_DIR}/${DATE_START}-${DATE_END}-tracklist.txt"
