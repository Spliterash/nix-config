import functools
import http.server
import json
from pathlib import Path
import subprocess
import tempfile
import threading


SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'


def run(*args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def test_yta():
    with tempfile.TemporaryDirectory(prefix='yta-test-') as temporary:
        root = Path(temporary)
        (root / 'config').mkdir()
        (root / 'config' / 'shell').symlink_to(SCRIPTS, target_is_directory=True)
        run('ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.2',
            '-c:a', 'libopus', str(root / 'audio.opus'))
        server = http.server.ThreadingHTTPServer(
            ('127.0.0.1', 0), functools.partial(Handler, directory=str(root)))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base = f'http://127.0.0.1:{server.server_port}'
            cases = [
                ('padded.jpg', 'color=black:s=480x360,drawbox=x=112:y=52:w=256:h=256:color=white:t=fill', 360),
                ('landscape.webp', 'color=white:s=480x360,drawbox=x=0:y=0:w=60:h=360:color=red:t=fill,drawbox=x=420:y=0:w=60:h=360:color=blue:t=fill', 360),
                ('portrait.png', 'color=white:s=320x480,drawbox=x=0:y=0:w=320:h=80:color=red:t=fill,drawbox=x=0:y=400:w=320:h=80:color=blue:t=fill', 320),
                ('square.jpg', 'color=white:s=300x300', 300),
                ('black.png', 'color=black:s=480x360', 360),
                ('black-background.png', 'color=black:s=480x270,drawbox=x=136:y=98:w=208:h=22:color=white:t=fill,drawbox=x=184:y=152:w=108:h=14:color=white:t=fill', 270),
                ('detailed.webp', 'testsrc2=s=300x300', 300),
                ('detailed.jpg', 'testsrc2=s=300x300', 300),
                (None, None, None),
            ]
            for index, (thumbnail, image, side) in enumerate(cases):
                if thumbnail:
                    run('ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', image,
                        '-frames:v', '1', str(root / thumbnail))
                info = {
                    'id': str(index), 'title': 'Track \'quoted\' "double"',
                    'artist': 'Artist', 'album': 'Album',
                    'url': f'{base}/audio.opus', 'ext': 'opus',
                    'extractor': 'generic', 'webpage_url': f'{base}/track/{index}',
                }
                if thumbnail:
                    info['thumbnails'] = [{'url': f'{base}/{thumbnail}'}]
                info_path = root / 'info.json'
                info_path.write_text(json.dumps(info))
                output = root / f'output-{index}'
                output.mkdir()
                run('zsh', '-fc', 'source "$1"; export XDG_CONFIG_HOME="$2"; '
                    'eval \'yta --ignore-config --no-progress --load-info-json "$3"\'',
                    'test-yta', str(SCRIPTS / 'media.sh'), str(root / 'config'),
                    str(info_path), cwd=output)
                files = list(output.iterdir())
                assert len(files) == 1 and files[0].suffix == '.opus', files
                streams = json.loads(run('ffprobe', '-v', 'error', '-show_streams',
                                         '-of', 'json', str(files[0])))['streams']
                assert streams[0]['codec_name'] == 'opus', streams
                assert streams[0]['tags']['title'] == info['title'], streams
                covers = [stream for stream in streams if stream['codec_type'] == 'video']
                if thumbnail:
                    assert len(covers) == 1, covers
                    assert (covers[0]['width'], covers[0]['height']) == (side, side), covers
                    pixels = subprocess.check_output([
                        'ffmpeg', '-v', 'error', '-i', str(files[0]), '-map', '0:v:0',
                        '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-',
                    ])
                    source = root / thumbnail
                    width, height = map(int, run(
                        'ffprobe', '-v', 'error', '-select_streams', 'v:0',
                        '-show_entries', 'stream=width,height', '-of', 'csv=p=0:s=x', str(source),
                    ).strip().split('x'))
                    original = subprocess.check_output([
                        'ffmpeg', '-v', 'error', '-i', str(source),
                        '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-',
                    ])
                    left, top = (width - side) // 2, (height - side) // 2
                    expected = b''.join(
                        original[((top + y) * width + left) * 3:((top + y) * width + left + side) * 3]
                        for y in range(side)
                    )
                    assert pixels == expected, f'{thumbnail}: embedded cover is not an unchanged center crop'
                else:
                    assert not covers, covers
                print(f'OK: {thumbnail or "no thumbnail"}; cover={side}; flat output')
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == '__main__':
    test_yta()
