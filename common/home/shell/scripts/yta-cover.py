from pathlib import Path
import subprocess
import sys
import tempfile


def crop_cover(filename):
    path = Path(filename).resolve()
    # Чёрный фон может быть частью обложки: обрезаем только края до центрального квадрата.
    with tempfile.TemporaryDirectory(prefix='.yta-cover-', dir=path.parent) as temporary:
        output = Path(temporary) / path.name
        subprocess.run(
            ['ffmpeg', '-nostdin', '-v', 'error', '-i', str(path),
             '-vf', "crop='min(iw,ih)':'min(iw,ih)',setsar=1", '-frames:v', '1', '-update', '1', str(output)],
            check=True,
        )
        output.replace(path)


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1]:
    crop_cover(sys.argv[1])
