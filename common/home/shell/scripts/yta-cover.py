from pathlib import Path
import re
import subprocess
import sys
import tempfile


def crop_cover(filename):
    path = Path(filename).resolve()
    # ponytail: чёрные поля определяются эвристически; тёмные края рисунка требуют ручной обрезки.
    detected = subprocess.run(
        ['ffmpeg', '-nostdin', '-hide_banner', '-i', str(path),
         '-vf', 'cropdetect=limit=0.04:round=2:skip=0', '-frames:v', '1', '-f', 'null', '-'],
        check=True, capture_output=True, text=True,
    )
    crops = re.findall(r'crop=(\d+):(\d+):(\d+):(\d+)', detected.stderr)
    filters = []
    if crops:
        filters.append('crop=' + ':'.join(crops[-1]))
    filters.extend(["crop='min(iw,ih)':'min(iw,ih)'", 'setsar=1'])
    with tempfile.TemporaryDirectory(prefix='.yta-cover-', dir=path.parent) as temporary:
        output = Path(temporary) / path.name
        subprocess.run(
            ['ffmpeg', '-nostdin', '-v', 'error', '-i', str(path),
             '-vf', ','.join(filters), '-frames:v', '1', '-update', '1', '-q:v', '2', str(output)],
            check=True,
        )
        output.replace(path)


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1]:
    crop_cover(sys.argv[1])
