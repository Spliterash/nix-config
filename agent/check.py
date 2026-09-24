import ipaddress
import shlex
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


def main():
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
