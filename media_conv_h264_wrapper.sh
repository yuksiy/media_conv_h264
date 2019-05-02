#!/bin/sh

# ==============================================================================
#   機能
#     media_conv_h264.sh のラッパースクリプト
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

######################################################################
# 変数定義
######################################################################
# ユーザ変数
DEST_FILE_EXT="mkv"
MEDIA_CONV_H264_OPTIONS=""

SCALE_DOWN="bilinear"
SCALE_UP="bicubic"

# システム環境 依存変数
FFMPEG="ffmpeg"
FFPROBE="ffprobe"
MEDIAINFO="mediainfo"

# プログラム内部変数
FLAG_OPT_NO_PLAY=FALSE
FLAG_OPT_VERBOSE=FALSE
FLAG_OPT_NO_HEADER=FALSE

######################################################################
# 関数定義
######################################################################
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
		    media_conv_h264_wrapper.sh ACTION [OPTIONS ...] [ARGUMENTS ...]
		
		ACTIONS:
		    info [OPTIONS ...] SRC_FILE ...
		    conv [OPTIONS ...] \\
		      VMAP AMAP DAR_S DAR PAR W H FPS FPS_MODE SCAN_TYPE SCAN_ORDER \\
		      FIELD_ORDER DURATION_V DELAY_V DELAY_SOURCE_V DURATION_A DELAY_A \\
		      DELAY_SOURCE_A SRC_FILE
		
		OPTIONS:
		    -n (no-play)
		       Print the commands that would be executed, but do not execute them.
		       (Available with: conv)
		    -v (verbose)
		       Verbose output.
		       (Available with: conv)
		    --no-header
		       (Available with: info)
		    --dest_file_ext="DEST_FILE_EXT"
		       (Available with: conv)
		    --media_conv_h264_options="MEDIA_CONV_H264_OPTIONS ..."
		       (Available with: conv)
		    --help
		       Display this help and exit.
	EOF
}

IS_NUMERIC() {
	str=$1
	echo "${str}" | grep -q '^[0-9\.]\+$'
	if [ $? -eq 0 ];then
		return 0
	else
		return 1
	fi
}

# "${MEDIAINFO}" --Info-Parameters | dos2unix | sed -n '1p; /^ $/{N;p}; /キーワード/Ip'
MEDIA_INFO() {
	# 引数のチェック
	if [ $# -lt 1 ];then
		echo "-E Missing SRC_FILE argument" 1>&2
		USAGE;return 1
	fi

	HDR="VMAP"                  ; FMT="%-4s"
	HDR="${HDR} AMAP"           ; FMT="${FMT} %-4s"
	HDR="${HDR} DAR_S"          ; FMT="${FMT} %-6s" ; INFORM_1="Video;%DisplayAspectRatio/String%"
	HDR="${HDR} DAR"            ; FMT="${FMT} %5s"  ; INFORM_1="${INFORM_1} %DisplayAspectRatio%"
	HDR="${HDR} PAR"            ; FMT="${FMT} %5s"  ; INFORM_1="${INFORM_1} %PixelAspectRatio%"
	HDR="${HDR} W"              ; FMT="${FMT} %4s"  ; INFORM_1="${INFORM_1} %Width%"
	HDR="${HDR} H"              ; FMT="${FMT} %4s"  ; INFORM_1="${INFORM_1} %Height%"
	HDR="${HDR} FPS"            ; FMT="${FMT} '%s'" ; INFORM_1="${INFORM_1} '%FrameRate%'"
	HDR="${HDR} FPS_MODE"       ; FMT="${FMT} '%s'" ; INFORM_1="${INFORM_1} '%FrameRate_Mode%'"
	HDR="${HDR} SCAN_TYPE"      ; FMT="${FMT} '%s'" ; INFORM_1="${INFORM_1} '%ScanType%'"
	HDR="${HDR} SCAN_ORDER"     ; FMT="${FMT} '%s'" ; INFORM_1="${INFORM_1} '%ScanOrder%'"
	HDR="${HDR} FIELD_ORDER"    ; FMT="${FMT} '%s'"
	HDR="${HDR} DURATION_V"     ; FMT="${FMT} '%s'" ; INFORM_2="Video;'%Duration/String3%'"
	HDR="${HDR} DELAY_V"        ; FMT="${FMT} '%s'" ; INFORM_2="${INFORM_2} '%Delay%'"
	HDR="${HDR} DELAY_SOURCE_V" ; FMT="${FMT} '%s'" ; INFORM_2="${INFORM_2} '%Delay_Source%'"
	HDR="${HDR} DURATION_A"     ; FMT="${FMT} '%s'" ; INFORM_3="Audio;'%Duration/String3%'"
	HDR="${HDR} DELAY_A"        ; FMT="${FMT} '%s'" ; INFORM_3="${INFORM_3} '%Delay%'"
	HDR="${HDR} DELAY_SOURCE_A" ; FMT="${FMT} '%s'" ; INFORM_3="${INFORM_3} '%Delay_Source%'"
	HDR="${HDR} SRC_FILE"       ; FMT="${FMT} '%s'\n"

	# NO_HEADER オプションが指定されていない場合
	if [ "${FLAG_OPT_NO_HEADER}" = "FALSE" ];then
		eval "printf \"${FMT}\" ${HDR}"
	fi

	for SRC_FILE in "$@" ; do
		if [ ! -f "${SRC_FILE}" ];then
			echo "-W \"${SRC_FILE}\" file not exist, or not a file, skipped" 1>&2
			continue
		fi
		if [ "$("${MEDIAINFO}" --Inform="Video;%Format%" "${SRC_FILE}" 2>&1 | dos2unix | grep -v 'E: File read error' | grep -v 'E: File read error')" = "" ];then
			echo "-W \"${SRC_FILE}\" invalid video format, skipped" 1>&2
			continue
		fi
		VMAP="0:$("${FFPROBE}" -v error -of default=nk=1:nw=1 -select_streams v:0 -show_entries "stream=index" "${SRC_FILE}" | dos2unix | head -1)"
		AMAP="0:$("${FFPROBE}" -v error -of default=nk=1:nw=1 -select_streams a:0 -show_entries "stream=index" "${SRC_FILE}" | dos2unix | head -1)"
		MEDIA_INFO_1="$("${MEDIAINFO}" --Inform="${INFORM_1}" "${SRC_FILE}" 2>&1 | dos2unix | grep -v 'E: File read error' | head -1)"
		FIELD_ORDER="$("${FFPROBE}" -v error -of default=nk=1:nw=1 -select_streams v:0 -show_entries "stream=field_order" "${SRC_FILE}" | dos2unix | head -1)"
		MEDIA_INFO_2="$("${MEDIAINFO}" --Inform="${INFORM_2}" "${SRC_FILE}" 2>&1 | dos2unix | grep -v 'E: File read error' | head -1)"
		MEDIA_INFO_3="$("${MEDIAINFO}" --Inform="${INFORM_3}" "${SRC_FILE}" 2>&1 | dos2unix | grep -v 'E: File read error' | head -1)"
		eval "printf \"${FMT}\" ${VMAP} ${AMAP} ${MEDIA_INFO_1} '${FIELD_ORDER}' ${MEDIA_INFO_2} ${MEDIA_INFO_3} '${SRC_FILE}'"
	done
}

MEDIA_CONV() {
	# 引数のチェック
	if [ $# -lt 19 ];then
		echo "-E Too few arguments" 1>&2
		USAGE;return 1
	fi
	VMAP="${1}"
	AMAP="${2}"
	DAR_S="${3}"
	DAR="${4}"
	PAR="${5}"
	W="${6}"
	H="${7}"
	FPS="${8}"
	FPS_MODE="${9}"
	SCAN_TYPE="${10}"
	SCAN_ORDER="${11}"
	FIELD_ORDER="${12}"
	DURATION_V="${13}"
	DELAY_V="${14}"
	DELAY_SOURCE_V="${15}"
	DURATION_A="${16}"
	DELAY_A="${17}"
	DELAY_SOURCE_A="${18}"
	SRC_FILE="${19}"

	DEST_FILE="${SRC_FILE}.${DEST_FILE_EXT}"

	# IN_TYPE,OUT_TYPE の初期化
	if [ \( "${SCAN_TYPE}" = "Progressive" \) -a \( "${SCAN_ORDER}" = "2:3 Pulldown" \) ];then
		IN_TYPE="23pulldown"
		case "${FIELD_ORDER}" in
		tt)	OUT_TYPE="tff";;
		bb)	OUT_TYPE="bff";;
		*)
			echo "-E Invalid FIELD_ORDER -- \"${FIELD_ORDER}\"" 1>&2
			return 1
			;;
		esac
	elif [ "${SCAN_TYPE}" = "Interlaced" ];then
		case "${SCAN_ORDER}" in
		TFF)	IN_TYPE="tff" ; OUT_TYPE="tff";;
		BFF)	IN_TYPE="bff" ; OUT_TYPE="bff";;
		*)
			echo "-E Invalid SCAN_ORDER -- \"${SCAN_ORDER}\"" 1>&2
			return 1
			;;
		esac
	else
		IN_TYPE="prog" ; OUT_TYPE="prog"
	fi

	# VIDEO_FILTER_SCALE の初期化
	# W が数値でない場合
	IS_NUMERIC "${W}"
	if [ $? -ne 0 ];then
		echo "-E W not numeric -- \"${W}\"" 1>&2
		return 1
	fi
	# H が数値でない場合
	IS_NUMERIC "${H}"
	if [ $? -ne 0 ];then
		echo "-E H not numeric -- \"${H}\"" 1>&2
		return 1
	fi
	# 解像度変更が不要である場合
	if [ \( ${W} -eq 720 \) -a \( ${H} -eq 480 \) ];then
		VIDEO_FILTER_SCALE=""
	# 解像度縮小が必要である場合
	elif [ \( ${W} -ge 720 \) -a \( ${H} -ge 480 \) ];then
		VIDEO_FILTER_SCALE="scale=720x480:flags=${SCALE_DOWN}"
	# 解像度拡大が必要である場合
	elif [ \( ${W} -le 720 \) -a \( ${H} -le 480 \) ];then
		VIDEO_FILTER_SCALE="scale=720x480:flags=${SCALE_UP}"
	# 解像度変更の要否を判定できない場合
	else
		echo "-E Invalid W or H" 1>&2
		echo "     W : ${W}" 1>&2
		echo "     H : ${H}" 1>&2
		return 1
	fi

	# VIDEO_FILTER_FPS の初期化
	if [ "${IN_TYPE}" = "23pulldown" ];then
		VIDEO_FILTER_FPS=""
	else
		VIDEO_FILTER_FPS="fps=fps=30000/1001"
	fi

	# VIDEO_FILTER の初期化
	VIDEO_FILTER="\
${VIDEO_FILTER_SCALE:+${VIDEO_FILTER_SCALE},}\
${VIDEO_FILTER_FPS:+${VIDEO_FILTER_FPS}}"

	# VIDEO_ASPECT の初期化
	case "${DAR_S}" in
	4:3)	VIDEO_ASPECT="10:11";;
	16:9)	VIDEO_ASPECT="40:33";;
	*)
		echo "-E Invalid DAR_S -- \"${DAR_S}\"" 1>&2
		return 1
		;;
	esac

	# AUDIO_DELAY の初期化
	# DELAY_V, DELAY_SOURCE_V, DELAY_A, DELAY_SOURCE_A のすべてが「空文字」でない場合
	if [ \( -n "${DELAY_V}" \) -a \( -n "${DELAY_SOURCE_V}" \) -a \
		\( -n "${DELAY_A}" \) -a \( -n "${DELAY_SOURCE_A}" \) ];then
		# DELAY_SOURCE_V, DELAY_SOURCE_A のいずれかが「Container」でない場合
		if [ \( ! "${DELAY_SOURCE_V}" = "Container" \) -o \
			\( ! "${DELAY_SOURCE_A}" = "Container" \) ];then
			echo "-E Either DELAY_SOURCE_V or DELAY_SOURCE_A is not \"Container\"" 1>&2
			echo "     DELAY_SOURCE_V : ${DELAY_SOURCE_V}" 1>&2
			echo "     DELAY_SOURCE_A : ${DELAY_SOURCE_A}" 1>&2
			return 1
		fi
		# DELAY_V が数値でない場合
		IS_NUMERIC "${DELAY_V}"
		if [ $? -ne 0 ];then
			echo "-E DELAY_V not numeric -- \"${DELAY_V}\"" 1>&2
			return 1
		fi
		# DELAY_A が数値でない場合
		IS_NUMERIC "${DELAY_A}"
		if [ $? -ne 0 ];then
			echo "-E DELAY_A not numeric -- \"${DELAY_A}\"" 1>&2
			return 1
		fi
		AUDIO_DELAY="$(echo "${DELAY_A} - ${DELAY_V}" | bc)"
		# AUDIO_DELAY < 0 である場合
		if [ $(echo "${AUDIO_DELAY} < 0" | bc) -eq 1 ];then
			echo "-E DELAY_V > DELAY_A" 1>&2
			echo "     DELAY_V : ${DELAY_V}" 1>&2
			echo "     DELAY_A : ${DELAY_A}" 1>&2
			return 1
		# AUDIO_DELAY = 0 である場合
		elif [ ${AUDIO_DELAY} -eq 0 ];then
			AUDIO_DELAY=""
		# AUDIO_DELAY > 0 である場合
		else
			# 何もしない
			:
		fi
	fi

	CMD_V "\
media_conv_h264.sh ${IN_TYPE} ${OUT_TYPE} \
${MEDIA_CONV_H264_OPTIONS:+${MEDIA_CONV_H264_OPTIONS} }\
--vmap=${VMAP} \
--amap=${AMAP} \
${VIDEO_FILTER:+--vfilter=\"${VIDEO_FILTER}\" }\
--vaspect=${VIDEO_ASPECT} \
--x264-options=\"--no-progress --open-gop\" \
${AUDIO_FILTER:+--afilter=\"${AUDIO_FILTER}\" }\
${AUDIO_DELAY:+--adelay=\"${AUDIO_DELAY}\" }\
--mkg=\"--disable-track-statistics-tags\" \
\"${SRC_FILE}\" \"${DEST_FILE}\""
}

######################################################################
# メインルーチン
######################################################################

# ACTIONのチェック
if [ "$1" = "" ];then
	echo "-E Missing ACTION" 1>&2
	USAGE;exit 1
else
	case "$1" in
	info|conv)
		ACTION="$1"
		;;
	*)
		echo "-E Invalid ACTION -- \"$1\"" 1>&2
		USAGE;exit 1
		;;
	esac
fi

# ACTIONをシフト
shift 1

# オプションのチェック
CMD_ARG="`getopt -o nv -l no-header,dest_file_ext:,media_conv_h264_options:,help -- \"$@\" 2>&1`"
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
	--no-header)	FLAG_OPT_NO_HEADER=TRUE ; shift 1;;
	--dest_file_ext)	DEST_FILE_EXT="$2" ; shift 2;;
	--media_conv_h264_options)	MEDIA_CONV_H264_OPTIONS="$2" ; shift 2;;
	--help)
		USAGE;exit 0
		;;
	--)
		shift 1;break
		;;
	esac
done

case ${ACTION} in
info)
	MEDIA_INFO "$@"
	;;
conv)
	MEDIA_CONV "$@"
	;;
esac

