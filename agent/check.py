import ipaddress
import shlex
import socket
import subprocess
from pathlib import Path


def address(url, *, guest=False):
    command = [
        "curl", "--noproxy", "*", "-4fsS",
        "--connect-timeout", "10", "--max-time", "30", url,
    ]
    if guest:
        command = ["avm", "ssh", shlex.join(command)]
    return ipaddress.ip_address(subprocess.check_output(command, text=True).strip())


def check_mounts():
    subprocess.run(["avm", "ssh", "sudo bash -se"], check=True, input=r'''
systemctl is-active --quiet avm-mounts
while IFS=$'\t' read -r name guest; do
    stat -- "/run/avm/shares/$name" >/dev/null
    mountpoint -q -- "$guest"
    if [[ $name == *:ro ]]; then
        if [[ -d $guest ]]; then
            if probe=$(mktemp "$guest/.avm-ro-check.XXXXXX" 2>/dev/null); then
                rm -- "$probe"
                echo "read-only mount is writable: $guest" >&2
                exit 1
            fi
        elif (: >>"$guest") 2>/dev/null; then
            echo "read-only mount is writable: $guest" >&2
            exit 1
        fi
    fi
    printf 'mount: %s\n' "$guest"
done </run/avm/host/mounts.tsv
''', text=True)


def check_signing():
    with socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect((1, 54546))  # VMADDR_CID_LOCAL: хост не должен получать GPG-сокет VM.
        try:
            reply = client.recv(1)
        except ConnectionResetError:
            reply = b""
        assert reply == b"", "GPG bridge accepted a connection from the host"
    for key in ["user.name", "user.email", "user.signingkey"]:
        host = subprocess.check_output(["git", "config", "--global", key], text=True).strip()
        guest = subprocess.check_output(["avm", "ssh", "git", "config", "--global", key], text=True).strip()
        assert guest == host, (key, host, guest)
    subprocess.run(["avm", "ssh", "bash -se"], check=True, input=r'''
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
git init -q "$repo"
git -C "$repo" commit --allow-empty -m 'AVM GPG signing check'
git -C "$repo" verify-commit HEAD
''', text=True)


def main():
    check_mounts()
    check_signing()
    for name in ["root", "docker"]:
        disk = Path.home() / "agent-vm" / "disks" / f"{name}.qcow2"
        with disk.open("rb") as image:
            header = image.read(32)
        assert header[:4] == b"QFI\xfb", (disk, "not QCOW2")
        assert header[8:16] == bytes(8), (disk, "depends on a backing file")
        print(f"{name}: QCOW2, file {disk.stat().st_size / 2**20:.1f} MiB")

    direct = address("https://api.ipify.org")
    for url in [
        "https://api.ipify.org",
        "https://checkip.amazonaws.com",
        "https://icanhazip.com",
    ]:
        actual = address(url, guest=True)
        assert actual == direct, (url, actual, direct)
        print(f"direct: {url} -> {actual}")

    proxy = address("http://ifconfig.me/ip", guest=True)
    assert proxy != direct, ("proxy bypass", proxy)
    for url in ["https://ifconfig.me/ip", "https://www.ifconfig.me/ip"]:
        actual = address(url, guest=True)
        assert actual == proxy, (url, actual, proxy)
        print(f"proxy: {url} -> {actual}")


if __name__ == "__main__":
    main()
