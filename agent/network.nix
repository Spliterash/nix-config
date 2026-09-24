{ pkgs, vm, ... }:
let
  proxyConfig = (pkgs.formats.json { }).generate "avm-sing-box.json" {
    log.level = "info";
    dns = {
      servers = [
        {
          type = "udp";
          tag = "local";
          server = "1.1.1.1";
        }
      ];
      strategy = "ipv4_only";
      reverse_mapping = true;
    };
    inbounds = [
      {
        type = "tun";
        interface_name = "tun0";
        netns = "/run/netns/avm";
        address = [ "172.19.0.1/30" ];
        mtu = 1500;
        auto_route = false;
        stack = "system";
      }
    ];
    outbounds = [
      {
        type = "direct";
        tag = "direct";
      }
    ];
    route = {
      default_domain_resolver = "local";
      auto_detect_interface = true;
      final = "direct";
      rules = [
        { action = "sniff"; }
        {
          protocol = "dns";
          action = "hijack-dns";
        }
      ];
    };
  };

  #! kill switch: наружу ходит только сам sing-box. Упал он или outbound
  #! недоступен — трафик не идёт напрямую. Правило живёт вне гостя и никогда
  #! не снимается до выключения VM, включая случай исчезновения tun0.
  firewall = pkgs.writeText "avm-killswitch.nft" ''
    table inet avm {
      chain input {
        type filter hook input priority filter; policy accept;
        iifname "guest0" drop
      }
      chain forward {
        type filter hook forward priority filter; policy drop;
        iifname "guest0" oifname "tun0" accept
        iifname "tun0" oifname "guest0" accept
      }
    }
  '';
in
{
  inherit proxyConfig;

  start = pkgs.writeShellApplication {
    name = "avm-network";
    runtimeInputs = with pkgs; [
      coreutils
      iproute2
      nftables
      sing-box
      systemd
      util-linux
      procps
    ];
    text = ''
      children=()
      cleanup() {
        trap - EXIT TERM INT
        local -a running
        mapfile -t running < <(jobs -pr)
        if (( ''${#running[@]} )); then
          kill "''${running[@]}" 2>/dev/null || true
        fi
        wait || true
      }
      ip netns add avm
      trap cleanup EXIT
      trap 'exit 143' TERM INT

      ip netns exec avm nft -f ${firewall}
      ip -n avm tuntap add guest0 mode tap user microvm
      ip -n avm address add ${vm.gateway}/30 dev guest0
      ip -n avm link set guest0 up
      ip -n avm link set lo up
      ip netns exec avm sysctl -qw net.ipv4.ip_forward=1
      ip -n avm rule add iif guest0 lookup 100 priority 100

      # хост больше не доступен через user-сеть qemu: в namespace только guest0 и tun0
      sing-box check -c /run/avm/proxy.json
      systemd-cat -t avm-proxy sing-box run -c /run/avm/proxy.json &
      children+=("$!")
      for _ in $(seq 1 100); do
        ip -n avm link show tun0 >/dev/null 2>&1 && break
        kill -0 "''${children[0]}" 2>/dev/null || exit 1
        sleep 0.1
      done
      ip -n avm route add default dev tun0 table 100

      ip netns exec avm setpriv --reuid=microvm --regid=kvm --init-groups \
        --bounding-set=-all --inh-caps=-all --ambient-caps=-all --no-new-privs \
        "$@" &
      children+=("$!")
      wait "''${children[1]}"
    '';
  };
}
