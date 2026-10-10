#!/usr/bin/env python3
"""Run the built network policy in disposable namespaces; never touch the VM."""
import contextlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
GUEST = "172.30.42.2"
GATEWAY = "172.30.42.1"
LAN = "192.168.0.25"
CLIENT = "192.168.0.20"
ENDPOINT = "10.99.0.1"
PORT = 18080

SERVER = '''
import http.server, json, socketserver, sys
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps([self.server.server_address[0], self.client_address[0]]).encode()
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args):
        pass
socketserver.TCPServer((sys.argv[1], int(sys.argv[2])), Handler).serve_forever()
'''
FETCH = '''
import http.client, json, sys
connection = http.client.HTTPConnection(sys.argv[1], int(sys.argv[2]), timeout=2,
                                       source_address=(sys.argv[3], 0))
connection.request('GET', '/')
response = connection.getresponse()
assert response.status == 200, response.status
print(response.read().decode())
'''


def run(*command, check=True):
    return subprocess.run(command, check=check, capture_output=True, text=True, timeout=20)


def ip(namespace, *args):
    return run("ip", "-n", namespace, *args)


def fetch(namespace, address, source=None):
    result = run("ip", "netns", "exec", namespace, sys.executable,
                 "-c", FETCH, address, str(PORT), source or (CLIENT if namespace == "router" else GUEST),
                 check=False)
    return json.loads(result.stdout) if result.returncode == 0 else None


def wait_for(predicate):
    deadline = time.monotonic() + 20
    while not predicate():
        assert time.monotonic() < deadline, "network readiness timeout"
        time.sleep(0.1)


def stop_proxy(network):
    children = Path(f"/proc/{network.pid}/task/{network.pid}/children").read_text().split()
    for pid in children:
        executable = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")[0]
        if executable.rsplit(b"/", 1)[-1] in (b"sing-box", b".sing-box-wrapped"):
            os.kill(int(pid), signal.SIGTERM)
            wait_for(lambda: run("ip", "-n", "avm", "link", "show", "tun0", check=False).returncode != 0)
            return
    raise AssertionError("network runner has no sing-box child")


@contextlib.contextmanager
def process(command, log):
    with log.open("w") as output:
        child = subprocess.Popen(command, stdout=output, stderr=output)
        try:
            yield child
        finally:
            child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=5)


def assert_no_lan_bypass(temporary, namespace="router", address=CLIENT):
    receiver = '''
import json, pathlib, socket, sys, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind((sys.argv[1], 18081))
pathlib.Path(sys.argv[2] + '.ready').touch()
messages = []
deadline = time.monotonic() + 3
while time.monotonic() < deadline:
    s.settimeout(max(0.01, deadline - time.monotonic()))
    try:
        messages.append(s.recv(1024).decode())
    except TimeoutError:
        break
pathlib.Path(sys.argv[2]).write_text(json.dumps(messages))
'''
    sender = "import socket,sys;socket.socket(socket.AF_INET,socket.SOCK_DGRAM).sendto(sys.argv[2].encode(),(sys.argv[1],18081))"
    received = temporary / (namespace + "-udp.json")
    with process(["ip", "netns", "exec", namespace, sys.executable, "-c", receiver,
                  address, str(received)], temporary / (namespace + "-udp.log")) as listener:
        wait_for(lambda: Path(str(received) + ".ready").exists())
        for sender_namespace, payload in [(namespace, "control"), ("guest", "bypass")]:
            run("ip", "netns", "exec", sender_namespace, sys.executable, "-c", sender, address, payload)
        listener.wait(timeout=5)
    assert json.loads(received.read_text()) == ["control"], "new guest traffic leaked directly onto LAN"


def test(runtime, temporary):
    # Only guest transport, journal logging and the QEMU uid switch are substituted.
    script = (runtime / "bin/avm-network").read_text()
    substitutions = [
        (r'ip -n avm tuntap add guest0 mode tap user microvm',
         'ip -n avm link add guest0 type veth peer name eth0 netns guest'),
        (r'systemd-cat -t avm-proxy ', ''),
        (r'ip netns exec avm setpriv[^\n]*\\\n[^\n]*\\\n', ''),
    ]
    for pattern, replacement in substitutions:
        script, count = re.subn(pattern, replacement, script)
        assert count == 1, f"network runner changed: {pattern}"
    runner = temporary / "avm-network"
    runner.write_text(script)
    runner.chmod(0o700)

    run("mount", "--make-rprivate", "/")
    run("mount", "-t", "tmpfs", "tmpfs", "/run")
    Path("/run/avm").mkdir()
    Path("/run/avm/proxy.json").write_text((runtime / "proxy.json").read_text())
    run("ip", "link", "set", "lo", "up")
    run("ip", "address", "add", ENDPOINT + "/32", "dev", "lo")
    for namespace in ["guest", "router"]:
        run("ip", "netns", "add", namespace)
        ip(namespace, "link", "set", "lo", "up")
    run("ip", "link", "add", "uplink0", "type", "veth", "peer", "name", "eth0",
        "netns", "router")
    run("ip", "link", "set", "uplink0", "up")
    ip("router", "link", "set", "eth0", "up")
    ip("router", "address", "add", "192.168.0.1/24", "dev", "eth0")
    ip("router", "address", "add", CLIENT + "/24", "dev", "eth0")

    vm = json.loads((runtime / "vm.json").read_text())
    dnsmasq = ["ip", "netns", "exec", "router", str(runtime / "dnsmasq/bin/dnsmasq"),
               "--no-daemon", "--user=root", "--group=root", "--port=0", "--interface=eth0",
               "--bind-interfaces", "--dhcp-range=" + LAN + "," + LAN + ",12h",
               "--dhcp-host=" + vm["lanMac"] + "," + LAN,
               "--dhcp-option=3,192.168.0.1", "--dhcp-leasefile=" + str(temporary / "leases")]
    with process(dnsmasq, temporary / "dhcp.log"), process(
            [sys.executable, "-c", SERVER, ENDPOINT, str(PORT)], temporary / "endpoint.log"):
        for mode in ["isolated", "lan"]:
            Path("/run/avm/network.json").write_text(json.dumps({"mode": mode, "interface": "uplink0"}))
            try:
                with process([str(runner), "sleep", "300"], temporary / (mode + ".log")) as network:
                    def ready():
                        assert network.poll() is None, "network runner exited"
                        return run("ip", "-n", "avm", "link", "show", "tun0", check=False).returncode == 0
                    wait_for(ready)
                    ip("guest", "link", "set", "eth0", "up")
                    ip("guest", "address", "add", GUEST + "/30", "dev", "eth0")
                    ip("guest", "route", "replace", "default", "via", GATEWAY, "dev", "eth0")
                    wait_for(lambda: fetch("guest", ENDPOINT) is not None)
                    assert fetch("guest", ENDPOINT) == [ENDPOINT, ENDPOINT], "proxy source mismatch"
                    if mode == "isolated":
                        assert run("ip", "-n", "avm", "link", "show", "lan0", check=False).returncode != 0
                    else:
                        addresses = json.loads(ip("avm", "-j", "address", "show", "lan0").stdout)[0]["addr_info"]
                        assert [(a["family"], a["local"]) for a in addresses] == [("inet", LAN)], addresses
                        assert f"{vm['lanMac']} {LAN} " in (temporary / "leases").read_text(), "router has no guest DHCP lease"
                        with process(["ip", "netns", "exec", "guest", sys.executable, "-c", SERVER,
                                      GUEST, str(PORT)], temporary / "guest.log"):
                            wait_for(lambda: fetch("router", LAN) is not None)
                            assert fetch("router", LAN) == [GUEST, CLIENT], "LAN DNAT/reply failed"
                            assert fetch("avm-host", LAN, vm["hostGateway"]) == [GUEST, vm["hostGateway"]], "host cannot access LAN IP"
                            stop_proxy(network)
                            assert fetch("guest", ENDPOINT) is None, "direct egress bypassed missing TUN"
                            assert_no_lan_bypass(temporary)
                            assert_no_lan_bypass(temporary, "avm-host", vm["hostGateway"])
                            assert fetch("router", LAN) == [GUEST, CLIENT], "LAN replies need working TUN"
                            assert fetch("avm-host", LAN, vm["hostGateway"]) == [GUEST, vm["hostGateway"]], "host access needs working TUN"
                        print("lan: DHCP .25, host + LAN HTTP; outbound via sing-box; no direct egress with TUN stopped", flush=True)
                    if mode == "isolated":
                        stop_proxy(network)
                        assert fetch("guest", ENDPOINT) is None, "isolated egress bypassed missing TUN"
                        print("isolated: no LAN interface; outbound via sing-box; no TUN bypass", flush=True)
                if mode == "lan":
                    wait_for(lambda: vm["lanMac"] not in (temporary / "leases").read_text())
                    print("lan stop: router DHCP lease released", flush=True)
            finally:
                run("ip", "netns", "delete", "avm", check=False)
                assert run("ip", "link", "show", "avm0", check=False).returncode != 0, "host link leaked after stop"
                assert json.loads(run("ip", "-j", "route", "show", LAN + "/32").stdout) == [], "host route leaked after stop"


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--inside":
        parent_namespaces = json.loads(os.environ["AVM_NETWORK_PARENT_NAMESPACES"])
        assert all(os.stat("/proc/self/ns/" + name).st_ino != inode
                   for name, inode in parent_namespaces.items()), "requires fresh namespaces"
        sys.executable = str(Path(sys.executable).resolve())
        os.environ["PATH"] = os.pathsep.join(str(Path(p).resolve())
                                             for p in os.environ["PATH"].split(os.pathsep))
        with tempfile.TemporaryDirectory(prefix="avm-network-check-") as directory:
            temporary = Path(directory)
            try:
                test(Path(sys.argv[2]), temporary)
            except BaseException:
                for log in temporary.glob("*.log"):
                    print(log.name + ":\n" + "\n".join(log.read_text().splitlines()[-30:]))
                raise
        return
    expression = '''
let
  f = builtins.getFlake (toString ./.);
  pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
  vm = import ./agent/vm.nix { username = "spliterash"; };
  network = import ./agent/network.nix { inherit pkgs vm; };
in pkgs.linkFarm "avm-network-check" [
  { name = "bin"; path = "${network.start}/bin"; }
  { name = "proxy.json"; path = network.proxyConfig; }
  { name = "vm.json"; path = pkgs.writeText "avm-vm.json" (builtins.toJSON vm); }
  { name = "dnsmasq"; path = pkgs.dnsmasq; }
]
'''
    result = subprocess.check_output(["nix", "build", "--impure", "--no-link", "--print-out-paths",
                                      "--expr", expression], cwd=ROOT, text=True).strip()
    environment = os.environ | {"AVM_NETWORK_PARENT_NAMESPACES": json.dumps({
        name: os.stat("/proc/self/ns/" + name).st_ino for name in ["net", "mnt", "user"]})}
    subprocess.run(["unshare", "--user", "--map-root-user", "--net", "--mount",
                    sys.executable, str(Path(__file__).resolve()), "--inside", result],
                   env=environment, check=True, timeout=180)


if __name__ == "__main__":
    main()
