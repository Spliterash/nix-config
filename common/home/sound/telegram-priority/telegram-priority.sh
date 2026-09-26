declare -A clients=() owners=() node_binary=() active=() paused=()

pause_players() {
  local player status track
  while IFS= read -r player; do
    case "${player,,}" in
      *telegram*|*ayugram*|plasma-browser-integration) continue ;;
    esac
    status=$(playerctl -p "$player" status 2>/dev/null) || continue
    [[ $status == Playing ]] || continue
    if [[ -v paused[$player] ]]; then
      playerctl -p "$player" pause || true
      continue
    fi
    track=$(playerctl -p "$player" metadata mpris:trackid 2>/dev/null) || track=
    if playerctl -p "$player" pause && [[ $(playerctl -p "$player" status 2>/dev/null) == Paused ]]; then
      paused[$player]=$track
    fi
  done < <(playerctl --list-all 2>/dev/null)
}

resume_players() {
  local player track
  for player in "${!paused[@]}"; do
    track=$(playerctl -p "$player" metadata mpris:trackid 2>/dev/null) || track=
    if [[ $(playerctl -p "$player" status 2>/dev/null) == Paused && $track == "${paused[$player]}" ]]; then
      playerctl -p "$player" play || true
    fi
    unset 'paused[$player]'
  done
}

trap resume_players EXIT
trap 'exit 0' TERM INT

while true; do
  if IFS=$'\t' read -r -t 1 id kind owner binary state corked; then
    case $kind in
      client) clients[$id]=$binary ;;
      node)
        owners[$id]=$owner
        node_binary[$id]=$binary
        if [[ $state == running && $corked != true ]]; then
          active[$id]=1
        else
          unset 'active[$id]'
        fi
        ;;
      removed)
        unset 'clients[$id]' 'owners[$id]' 'node_binary[$id]' 'active[$id]'
        ;;
    esac
  elif [[ $? == 1 ]]; then
    break
  fi

  telegram=0
  for id in "${!active[@]}"; do
    source="${node_binary[$id]} ${clients[${owners[$id]}]-}"
    case "${source,,}" in
      *ayugram*|*telegram*) telegram=1; break ;;
    esac
  done

  if (( telegram )); then
    pause_players
  else
    resume_players
  fi
done < <(
  pw-dump -m -N | jq --unbuffered -r '
    .[] |
    if .info == null then [.id, "removed", "-", "-", "-", "-"] | @tsv
    elif .type == "PipeWire:Interface:Client" then
      [.id, "client", "-", (.info.props."application.process.binary" // .info.props."application.name" // "-"), "-", "-"] | @tsv
    elif .type == "PipeWire:Interface:Node" and .info.props."media.class" == "Stream/Output/Audio" then
      [.id, "node", (.info.props."client.id" // "-"), (.info.props."application.process.binary" // .info.props."application.name" // "-"), (.info.state // "-"), (.info.props."pulse.corked" // false | tostring)] | @tsv
    else empty end
  '
)
