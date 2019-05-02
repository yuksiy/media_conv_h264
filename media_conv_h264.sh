#!/bin/sh

# ==============================================================================
#   機能
#     メディア形式を変換する (H.264)
#   構文
#     USAGE 参照
#
#   Copyright (c) 2017-2019 Yukio Shiiya
#
#   This software is released under the MIT License.
#   https://opensource.org/licenses/MIT
# ==============================================================================

######################################################################
# 基本設定
######################################################################
trap "" 28				# TRAP SET
trap "POST_PROCESS;exit 1" 1 2 15	# TRAP SET

SCRIPT_FULL_NAME=`realpath $0`
SCRIPT_ROOT=`dirname ${SCRIPT_FULL_NAME}`
SCRIPT_NAME=`basename ${SCRIPT_FULL_NAME}`
PID=$$

######################################################################
# 変数定義
######################################################################
# ユーザ変数
VIDEO_MAP="0:0"
AUDIO_MAP="0:1"

VIDEO_FILTER=""
VIDEO_ASPECT=""
VIDEO_BITRATE="1000"
VIDEO_MAXRATE="8000"

AUDIO_FILTER=""
AUDIO_FREQUENCY="48000"
AUDIO_CHANNEL="2"
AUDIO_BITRATE="256K"
AUDIO_DELAY=""
AUDIO_LANGUAGE="jpn"

# システム環境 依存変数
FFMPEG="ffmpeg"
X264="x264"
MKVMERGE="mkvmerge"

# プログラム内部変数
FLAG_OPT_NO_PLAY=FALSE
FLAG_OPT_VERBOSE=FALSE

FFMPEG_GLOBAL_OPTIONS=""
FFMPEG_INPUT_OPTIONS=""

X264_OPTIONS=""

MKVMERGE_GLOBAL_OPTIONS=""

#DEBUG=TRUE
#TMP_DIR="/tmp"
TMP_DIR="."
SCRIPT_TMP_DIR="${TMP_DIR}/${SCRIPT_NAME}.${PID}"

######################################################################
# 関数定義
######################################################################
PRE_PROCESS() {
	# 一時ディレクトリの作成
	mkdir -p "${SCRIPT_TMP_DIR}"
}

POST_PROCESS() {
	# 一時ディレクトリの削除
	if [ ! ${DEBUG} ];then
		rm -fr "${SCRIPT_TMP_DIR}"
	fi
}

CMD_V() {
	if [ "${FLAG_OPT_NO_PLAY}" = "FALSE" ];then
		if [ "${FLAG_OPT_VERBOSE}" = "TRUE" ];then
			printf "+ %s\n" "$@"
		fi
		eval "$@"
	else
		printf "+ %s\n" "$@"
	fi
}

USAGE() {
	cat <<- EOF 1>&2
		Usage:
		    media_conv_h264.sh IN_TYPE OUT_TYPE [OPTIONS ...] [ARGUMENTS ...]
		
		IN_TYPES:
		    23pulldown {tff|bff} [OPTIONS ...] SRC_FILE DEST_FILE
		    tff        {tff}     [OPTIONS ...] SRC_FILE DEST_FILE
		    bff        {bff}     [OPTIONS ...] SRC_FILE DEST_FILE
		    prog       {prog}    [OPTIONS ...] SRC_FILE DEST_FILE
		
		ARGUMENTS:
		    SRC_FILE  : Specify source file.
		    DEST_FILE : Specify destination file.
		       Following destination file types are supported now.
		         *.mkv
		
		OPTIONS:
		    -n (no-play)
		       Print the commands that would be executed, but do not execute them.
		    -v (verbose)
		       Verbose output.
		
		    --ffg="FFMPEG_GLOBAL_OPTIONS ..."
		    --ffi="FFMPEG_INPUT_OPTIONS ..."
		
		    --vmap=VIDEO_MAP
		    --amap=AUDIO_MAP
		
		    --vfilter="VIDEO_FILTER,..."
		    --vaspect=VIDEO_ASPECT
		    --vbitrate=VIDEO_BITRATE
		    --vmaxrate=VIDEO_MAXRATE
		
		    --x264-options="X264_OPTIONS ..."
		
		    --afilter="AUDIO_FILTER,..."
		    --afrequency=AUDIO_FREQUENCY
		    --achannel=AUDIO_CHANNEL
		    --abitrate=AUDIO_BITRATE
		    --adelay=AUDIO_DELAY
		    --alanguage=AUDIO_LANGUAGE
		
		    --mkg="MKVMERGE_GLOBAL_OPTIONS ..."
		    --help
		       Display this help and exit.
	EOF
}

######################################################################
# メインルーチン
######################################################################

# IN_TYPEのチェック
if [ "$1" = "" ];then
	echo "-E Missing IN_TYPE" 1>&2
	USAGE;exit 1
else
	case "$1" in
	23pulldown|tff|bff|prog)
		IN_TYPE="$1"
		;;
	*)
		echo "-E Invalid IN_TYPE -- \"$1\"" 1>&2
		USAGE;exit 1
		;;
	esac
fi

# IN_TYPEをシフト
shift 1

# OUT_TYPEのチェック
if [ "$1" = "" ];then
	echo "-E Missing OUT_TYPE" 1>&2
	USAGE;exit 1
else
	case "${IN_TYPE}" in
	23pulldown)
		case "$1" in
		tff|bff)
			OUT_TYPE="$1"
			;;
		*)
			echo "-E Invalid OUT_TYPE -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	tff)
		case "$1" in
		tff)
			OUT_TYPE="$1"
			;;
		*)
			echo "-E Invalid OUT_TYPE -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	bff)
		case "$1" in
		bff)
			OUT_TYPE="$1"
			;;
		*)
			echo "-E Invalid OUT_TYPE -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	prog)
		case "$1" in
		prog)
			OUT_TYPE="$1"
			;;
		*)
			echo "-E Invalid OUT_TYPE -- \"$1\"" 1>&2
			USAGE;exit 1
			;;
		esac
		;;
	esac
fi

# OUT_TYPEをシフト
shift 1

# オプションのチェック
CMD_ARG="`getopt -o nv -l ffg:,ffi:,vmap:,amap:,vfilter:,vaspect:,vbitrate:,vmaxrate:,x264-options:,afilter:,afrequency:,achannel:,abitrate:,adelay:,alanguage:,mkg:,help -- \"$@\" 2>&1`"
if [ $? -ne 0 ];then
	echo "-E ${CMD_ARG}" 1>&2
	USAGE;exit 1
fi
eval set -- "${CMD_ARG}"
while true ; do
	opt="$1"
	case "${opt}" in
	-n)	FLAG_OPT_NO_PLAY=TRUE ; shift 1;;
	-v)	FLAG_OPT_VERBOSE=TRUE ; shift 1;;
	--ffg)	FFMPEG_GLOBAL_OPTIONS="${FFMPEG_GLOBAL_OPTIONS:+${FFMPEG_GLOBAL_OPTIONS} }$2" ; shift 2;;
	--ffi)	FFMPEG_INPUT_OPTIONS="${FFMPEG_INPUT_OPTIONS:+${FFMPEG_INPUT_OPTIONS} }$2" ; shift 2;;
	--vmap)	VIDEO_MAP="$2" ; shift 2;;
	--amap)	AUDIO_MAP="$2" ; shift 2;;
	--vfilter)	VIDEO_FILTER="${VIDEO_FILTER:+${VIDEO_FILTER},}$2" ; shift 2;;
	--vaspect)	VIDEO_ASPECT="$2" ; shift 2;;
	--vbitrate)	VIDEO_BITRATE="$2" ; shift 2;;
	--vmaxrate)	VIDEO_MAXRATE="$2" ; shift 2;;
	--x264-options)	X264_OPTIONS="${X264_OPTIONS:+${X264_OPTIONS} }$2" ; shift 2;;
	--afilter)	AUDIO_FILTER="${AUDIO_FILTER:+${AUDIO_FILTER},}$2" ; shift 2;;
	--afrequency)	AUDIO_FREQUENCY="$2" ; shift 2;;
	--achannel)	AUDIO_CHANNEL="$2" ; shift 2;;
	--abitrate)	AUDIO_BITRATE="$2" ; shift 2;;
	--adelay)	AUDIO_DELAY="$2" ; shift 2;;
	--alanguage)	AUDIO_LANGUAGE="$2" ; shift 2;;
	--mkg)	MKVMERGE_GLOBAL_OPTIONS="${MKVMERGE_GLOBAL_OPTIONS:+${MKVMERGE_GLOBAL_OPTIONS} }$2" ; shift 2;;
	--help)
		USAGE;exit 0
		;;
	--)
		shift 1;break
		;;
	esac
done

# 第1引数のチェック
if [ "$1" = "" ];then
	echo "-E Missing SRC_FILE argument" 1>&2
	USAGE;exit 1
else
	SRC_FILE="$1"
	# 変換元ファイルのチェック
	#if [ ! -f "${SRC_FILE}" ];then
	#	echo "-E SRC_FILE not a file -- \"${SRC_FILE}\"" 1>&2
	#	USAGE;exit 1
	#fi
fi

# 第2引数のチェック
if [ "$2" = "" ];then
	echo "-E Missing DEST_FILE argument" 1>&2
	USAGE;exit 1
else
	DEST_FILE="$2"
	DEST_FILE_TYPE="$(echo "${DEST_FILE##*.}" | tr '[A-Z]' '[a-z]')"
	case "${DEST_FILE_TYPE}" in
	mkv)
		# 何もしない
		:
		;;
	*)
		echo "-E Invalid DEST_FILE_TYPE -- \"${DEST_FILE_TYPE}\"" 1>&2
		USAGE;exit 1
		;;
	esac
fi

# 変数定義(引数のチェック後)
VIDEO_FILE_TMP="${SCRIPT_TMP_DIR}/video_file_tmp.264"
AUDIO_FILE_TMP="${SCRIPT_TMP_DIR}/audio_file_tmp.ac3"

case "${IN_TYPE}" in
23pulldown)
	case "${OUT_TYPE}" in
	tff)
		TELECINE_FIRST_FIELD="top"
		;;
	bff)
		TELECINE_FIRST_FIELD="bottom"
		;;
	esac
	VIDEO_FILTER="${VIDEO_FILTER:+${VIDEO_FILTER},}fps=fps=24000/1001,telecine=first_field=${TELECINE_FIRST_FIELD}:pattern=23"
	X264_OPTIONS="${X264_OPTIONS:+${X264_OPTIONS} }--keyint 30 --${OUT_TYPE}"
	#VIDEO_FILTER="${VIDEO_FILTER:+${VIDEO_FILTER},}fps=fps=24000/1001,setfield=mode=prog"
	#X264_OPTIONS="${X264_OPTIONS:+${X264_OPTIONS} }--keyint 24 --pulldown 32 --fake-interlaced"
	;;
tff|bff)
	X264_OPTIONS="${X264_OPTIONS:+${X264_OPTIONS} }--keyint 30 --${OUT_TYPE}"
	;;
prog)
	X264_OPTIONS="${X264_OPTIONS:+${X264_OPTIONS} }--keyint 30"
	;;
esac

# 作業開始前処理
PRE_PROCESS

#####################
# メインループ 開始 #
#####################

# 映像ストリームの変換
echo "-I Converting video stream..."
CMD_V "\
${FFMPEG} \
${FFMPEG_GLOBAL_OPTIONS:+${FFMPEG_GLOBAL_OPTIONS} }\
${FFMPEG_INPUT_OPTIONS:+${FFMPEG_INPUT_OPTIONS} }\
-i \"${SRC_FILE}\" \
-map ${VIDEO_MAP} \
-map_metadata -1 \
${VIDEO_FILTER:+-filter:v:0 \"${VIDEO_FILTER}\" }\
-f yuv4mpegpipe -pix_fmt yuv420p - | \
${X264} \
--profile high \
--preset medium \
--bitrate ${VIDEO_BITRATE} \
--vbv-maxrate ${VIDEO_MAXRATE} \
--vbv-bufsize ${VIDEO_MAXRATE} \
--colorprim smpte170m \
--transfer smpte170m \
--colormatrix smpte170m \
--sar ${VIDEO_ASPECT} \
--level 3.2 \
--bluray-compat \
${X264_OPTIONS:+${X264_OPTIONS} }\
-o \"${VIDEO_FILE_TMP}\" \
--demuxer y4m -"
if [ $? -ne 0 ];then
	echo "-E Command has ended unsuccessfully." 1>&2
	POST_PROCESS;exit 1
fi
echo

# 音声ストリームの変換
if [ ! "${AUDIO_MAP}" = "" ];then
	echo "-I Converting audio stream..."
	CMD_V "\
${FFMPEG} \
${FFMPEG_GLOBAL_OPTIONS:+${FFMPEG_GLOBAL_OPTIONS} }\
${FFMPEG_INPUT_OPTIONS:+${FFMPEG_INPUT_OPTIONS} }\
-i \"${SRC_FILE}\" \
-map ${AUDIO_MAP} \
-map_metadata -1 \
${AUDIO_FILTER:+-filter:a:0 \"${AUDIO_FILTER}\" }\
-c:a:0 ac3 \
-ar:a:0 ${AUDIO_FREQUENCY} \
-ac:a:0 ${AUDIO_CHANNEL} \
-b:a:0 ${AUDIO_BITRATE} \
\"${AUDIO_FILE_TMP}\""
	if [ $? -ne 0 ];then
		echo "-E Command has ended unsuccessfully." 1>&2
		POST_PROCESS;exit 1
	fi
else
	echo "-I AUDIO_MAP not specified, audio stream skipped"
fi
echo

# 映像・音声ストリームの多重化
echo "-I Muxing video/audio stream..."
case "${DEST_FILE_TYPE}" in
mkv)
	if [ ! "${AUDIO_MAP}" = "" ];then
		CMD_V "${MKVMERGE} ${MKVMERGE_GLOBAL_OPTIONS:+${MKVMERGE_GLOBAL_OPTIONS} }-o \"${DEST_FILE}\" \"${VIDEO_FILE_TMP}\" ${AUDIO_DELAY:+-y 0:${AUDIO_DELAY} }${AUDIO_LANGUAGE:+--language 0:${AUDIO_LANGUAGE} }\"${AUDIO_FILE_TMP}\""
	else
		CMD_V "${MKVMERGE} ${MKVMERGE_GLOBAL_OPTIONS:+${MKVMERGE_GLOBAL_OPTIONS} }-o \"${DEST_FILE}\" \"${VIDEO_FILE_TMP}\""
	fi
	;;
esac
if [ $? -ne 0 ];then
	echo "-E Command has ended unsuccessfully." 1>&2
	POST_PROCESS;exit 1
fi
echo

#####################
# メインループ 終了 #
#####################

# 作業終了後処理
POST_PROCESS;exit 0

