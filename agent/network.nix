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
      chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        iifname { "lan0", "host0" } ct mark set 1
        iifname "guest0" ct direction reply ct mark 1 meta mark set 1
      }
      chain lan_input {
        type filter hook input priority filter; policy accept;
        iifname "lan0" udp sport 67 udp dport 68 accept
        iifname "lan0" drop
        iifname "host0" drop
      }
      chain forward {
        type filter hook forward priority filter; policy drop;
        iifname "guest0" oifname "tun0" accept
        iifname "tun0" oifname "guest0" accept
        iifname { "lan0", "host0" } oifname "guest0" ct status dnat accept
        iifname "guest0" oifname { "lan0", "host0" } ct status dnat ct direction reply accept
      }
      chain lan_nat {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "lan0" udp dport 68 accept
        iifname { "lan0", "host0" } fib daddr type local dnat ip to ${vm.guest}
      }
    }
  '';

  dhcpHook = pkgs.writeShellScript "avm-dhcp" ''
    set -euo pipefail
    case "$1" in
      deconfig)
        ip -4 address flush dev "$interface"
        ip -n avm-host -4 route flush dev avm0 proto static
        ;;
      bound|renew)
        ip -4 address flush dev "$interface"
        ip address add "$ip/''${subnet:-255.255.255.0}" broadcast + dev "$interface"
        if [[ -n ''${router:-} ]]; then
          ip route replace default via "''${router%% *}" dev "$interface"
        fi
        ip -n avm-host -4 route flush dev avm0 proto static
        ip -n avm-host route add "$ip/32" via ${vm.hostPeer} dev avm0 src ${vm.hostGateway} proto static
        ;;
    esac
  '';
in
{
  inherit proxyConfig;

  start = pkgs.writeShellApplication {
    name = "avm-network";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      iproute2
      jq
      nftables
      sing-box
      systemd
      util-linux
      procps
    ];
    text = ''
      host_namespace=false
      cleanup() {
        trap - EXIT TERM INT
        local -a running
        mapfile -t running < <(jobs -pr)
        if (( ''${#running[@]} )); then
          kill "''${running[@]}" 2>/dev/null || true
        fi
        wait || true
        ip -n avm link delete host0 2>/dev/null || true
        if [[ $host_namespace == true ]]; then ip netns delete avm-host; fi
      }
      ip netns add avm
      trap cleanup EXIT
      trap 'exit 143' TERM INT
      ip netns exec avm sysctl -qw net.ipv4.conf.all.rp_filter=0 net.ipv4.conf.default.rp_filter=0

      ip netns exec avm nft -f ${firewall}
      ip -n avm tuntap add guest0 mode tap user microvm
      ip -n avm address add ${vm.gateway}/30 dev guest0
      ip -n avm link set guest0 up
      ip -n avm link set lo up
      ip netns exec avm sysctl -qw net.ipv4.ip_forward=1
      ip -n avm rule add iif guest0 lookup 100 priority 100

      if [[ $(jq -r '.mode' /run/avm/network.json) == lan ]]; then
        uplink=$(jq -r '.interface' /run/avm/network.json)
        ip netns attach avm-host "$$"
        host_namespace=true
        ip link add avm0 type veth peer name host0 netns avm
        ip address add ${vm.hostGateway}/30 dev avm0
        ip link set avm0 up
        ip -n avm address add ${vm.hostPeer}/30 dev host0
        ip -n avm link set host0 up
        ip link add link "$uplink" name lan0 netns avm address ${vm.lanMac} type macvlan mode bridge
        ip netns exec avm sysctl -qw net.ipv6.conf.lan0.disable_ipv6=1
        ip -n avm link set lan0 up
        ip -n avm rule add fwmark 1 lookup main priority 90
        ip netns exec avm ${pkgs.busybox}/bin/udhcpc -f -R -i lan0 -x hostname:${vm.name} -s ${dhcpHook} -t 5 -T 2 -n &
        dhcp=$!
        for _ in $(seq 1 120); do
          if ip -n avm -4 address show dev lan0 | grep -q 'inet '; then break; fi
          kill -0 "$dhcp" 2>/dev/null || exit 1
          sleep 0.1
        done
        ip -n avm -4 address show dev lan0 | grep -q 'inet ' || exit 1
      fi

      # хост больше не доступен через user-сеть qemu: исходящие соединения идут только через tun0
      sing-box check -c /run/avm/proxy.json
      systemd-cat -t avm-proxy sing-box run -c /run/avm/proxy.json &
      proxy=$!
      for _ in $(seq 1 100); do
        ip -n avm link show tun0 >/dev/null 2>&1 && break
        kill -0 "$proxy" 2>/dev/null || exit 1
        sleep 0.1
      done
      ip -n avm route add default dev tun0 table 100

      ip netns exec avm setpriv --reuid=microvm --regid=kvm --init-groups \
        --bounding-set=-all --inh-caps=-all --ambient-caps=-all --no-new-privs \
        "$@" &
      wait "$!"
    '';
  };
}
