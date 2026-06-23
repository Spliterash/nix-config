# Конвертация любого говна в нормальный mp4 который прочитает кто угодно
ffmp4() {
    local input="$1"
    local output="$2"
    local bitrate="${3:-8M}"
    ffmpeg -init_hw_device vaapi=drm128:/dev/dri/renderD128 \
           -hwaccel vaapi \
           -hwaccel_output_format vaapi \
           -hwaccel_device drm128 \
           -i "$input" \
           -vf "format=nv12|vaapi,hwupload" \
           -c:v h264_vaapi \
           -b:v "$bitrate" \
           -maxrate 12M \
           -bufsize 12M \
           -c:a aac \
           -b:a 192k \
           -movflags +faststart \
           "$output"
}