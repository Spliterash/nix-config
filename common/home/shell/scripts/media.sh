# Конвертация любого говна в mp4, который без вопросов сожрёт телега и любой плеер:
# H.264 High/yuv420p + AAC-LC стерео 48k, moov в начале, чётные размеры,
# ключевой кадр раз в 2 секунды, ровно одна аудиодорожка (телега играет только первую).
#   ffmp4 <вход> [выход] [-q QP] [-b битрейт] [-- опции ffmpeg]
#     выход  по умолчанию — {вход_без_расширения}.ff.mp4 рядом с исходником
#     -q     качество 18..30, меньше = лучше и жирнее (по умолчанию 23)
#     -b     вместо -q: средний битрейт (8M)
ffmp4() {
    local input="$1"
    if [ -z "$input" ]; then
        echo "usage: ffmp4 <input> [output] [-q QP] [-b BITRATE] [-- ffmpeg opts]" >&2
        return 1
    fi
    shift

    local output=""
    case "$1" in
        ""|-*) ;;
        *) output="$1"; shift ;;
    esac
    [ -n "$output" ] || output="${input%.*}.ff.mp4"

    local qp=23 bitrate=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -q) qp="$2"; bitrate=""; shift 2 ;;
            -b) bitrate="$2"; shift 2 ;;
            --) shift; break ;;
            *)  bitrate="$1"; shift ;;
        esac
    done

    local -a rc
    if [ -n "$bitrate" ]; then
        rc=(-rc_mode VBR -b:v "$bitrate" -maxrate "$bitrate")
    else
        rc=(-rc_mode CQP -qp "$qp")
    fi

    ffmpeg -init_hw_device vaapi=drm128:/dev/dri/renderD128 \
           -hwaccel vaapi \
           -hwaccel_output_format vaapi \
           -hwaccel_device drm128 \
           -i "$input" \
           -vf "format=nv12|vaapi,hwupload,scale_vaapi=w=trunc(iw/2)*2:h=trunc(ih/2)*2" \
           -map 0:v:0 -map '0:a:0?' \
           -c:v h264_vaapi \
           -profile:v high \
           -g 50 \
           "${rc[@]}" \
           -c:a aac -b:a 192k -ac 2 -ar 48000 \
           -movflags +faststart \
           "$@" \
           "$output"
}
# Скачивание аудио с обложкой и конвертация в опус
alias yta='yt-dlp \
--embed-thumbnail \
--embed-metadata \
--embed-chapters \
--extract-audio \
--audio-format opus \
--audio-quality 10 \
--trim-filenames 248 \
--output "%(artist,channel,album_artist,uploader)s/%(album)s/%(track,title,track_id)s - [%(id)s].%(ext)s"'