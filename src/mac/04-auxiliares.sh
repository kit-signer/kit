# ========================== AUXILIARES ===============================

# Instalado se achar o app em /Applications ou o pacote no pkgutil
instalado() {
  ls /Applications 2>/dev/null | grep -qiE "$1" && return 0
  pkgutil --pkgs 2>/dev/null | grep -qiE "$1" && return 0
  return 1
}

# Converte "12.4.1" em numero comparavel (120401)
ver2num() {
  local a b c
  IFS=. read -r a b c <<< "$1"
  echo $(( 10#${a:-0} * 10000 + 10#${b:-0} * 100 + 10#${c:-0} ))
}
MACOS_VER="$(sw_vers -productVersion)"
MACOS_NUM="$(ver2num "$MACOS_VER")"
if [ "$(uname -m)" = "arm64" ]; then ARQ="arm"; else ARQ="intel"; fi

sha_confere() { [ -f "$1" ] && [ "$(shasum -a 256 "$1" | awk '{print $1}')" = "$2" ]; }

# Escolhe, entre os arquivos da chave, o certo para este Mac. Devolve "arquivo|sha256".
escolher_arquivo() {
  local chave="$1" linha c arq min proc sha minnum pontos melhor="" melhorpontos=-1
  for linha in "${ARQUIVOS[@]}"; do
    IFS='|' read -r c arq min proc sha <<< "$linha"
    [ "$c" = "$chave" ] || continue
    [ "$proc" = "qualquer" ] || [ "$proc" = "$ARQ" ] || continue
    minnum="$(ver2num "$min")"
    [ "$minnum" -le "$MACOS_NUM" ] || continue
    # empate: prefere o arquivo feito para o processador deste Mac
    pontos=$((minnum * 2)); [ "$proc" = "$ARQ" ] && pontos=$((pontos + 1))
    if [ "$pontos" -gt "$melhorpontos" ]; then melhorpontos=$pontos; melhor="$arq|$sha"; fi
  done
  echo "$melhor"
}

# Devolve o caminho de um arquivo do kit ja conferido, ou vazio.
# Usa o pendrive se tiver; senao baixa do Release do GitHub.
obter_arquivo() {
  local arq="$1" sha="$2" destino="$PASTA_TI/instaladores/$1"
  if [ -n "$PASTA_LOCAL" ] && sha_confere "$PASTA_LOCAL/$arq" "$sha"; then echo "$PASTA_LOCAL/$arq"; return; fi
  if ! sha_confere "$destino" "$sha"; then
    echo "  Baixando $arq..." >&2
    curl -fL --retry 5 --progress-bar -o "$destino" "$URL_ARQUIVOS/$arq" >&2
  fi
  if sha_confere "$destino" "$sha"; then echo "$destino"; return; fi
  echo "${VERMELHO}  [BLOQUEADO] $arq nao confere com a impressao digital (SHA256). Nao vou instalar.${FIM}" >&2
  echo "${VERMELHO}  Pode ser download incompleto ou arquivo trocado.${FIM}" >&2
  rm -f "$destino"
}

# Usuario logado na tela (para abrir instaladores com janela)
USUARIO_TELA="$(stat -f%Su /dev/console)"

# Instala o que estiver dentro de uma pasta (montada ou extraida)
instalar_conteudo() {
  local pasta="$1" modo="${2:-copiar}" item
  item="$(find "$pasta" -maxdepth 3 \( -name '*.pkg' -o -name '*.mpkg' \) -not -path '*/__MACOSX/*' | head -1)"
  if [ -n "$item" ]; then
    installer -pkg "$item" -target /; return $?
  fi
  item="$(find "$pasta" -maxdepth 3 -name '*.app' -not -path '*/__MACOSX/*' -prune | head -1)"
  [ -n "$item" ] || return 1
  xattr -dr com.apple.quarantine "$item" 2>/dev/null
  if [ "$modo" = "abrir" ] || basename "$item" | grep -qi 'install'; then
    # e um "instalador.app": precisa de cliques. Abre e espera fechar.
    aviso "  Abrindo $(basename "$item") - conclua a instalacao na tela do Mac..."
    cp -R "$item" /tmp/ && chmod -R a+rX "/tmp/$(basename "$item")"
    launchctl asuser "$(id -u "$USUARIO_TELA")" sudo -u "$USUARIO_TELA" open -W "/tmp/$(basename "$item")"
    rm -rf "/tmp/$(basename "$item")"
    return 0
  fi
  ditto "$item" "/Applications/$(basename "$item")"
}

# Instala um .pkg, .dmg ou .zip
instalar_arquivo() {
  local arq="$1" modo="${2:-copiar}" ok=1 mnt tmp dmg
  case "$arq" in
    *.pkg)
      installer -pkg "$arq" -target / && ok=0 ;;
    *.dmg)
      mnt="$(mktemp -d /tmp/ti-dmg.XXXX)"
      if hdiutil attach "$arq" -nobrowse -noverify -noautoopen -mountpoint "$mnt" >/dev/null; then
        instalar_conteudo "$mnt" "$modo" && ok=0
        hdiutil detach "$mnt" -quiet || hdiutil detach "$mnt" -force -quiet
      fi
      rmdir "$mnt" 2>/dev/null ;;
    *.zip)
      tmp="$(mktemp -d /tmp/ti-zip.XXXX)"
      ditto -x -k "$arq" "$tmp"
      # zip que tem um .dmg dentro
      dmg="$(find "$tmp" -maxdepth 3 -name '*.dmg' -not -path '*/__MACOSX/*' | head -1)"
      if [ -n "$dmg" ]; then instalar_arquivo "$dmg" "$modo" && ok=0
      else instalar_conteudo "$tmp" "$modo" && ok=0; fi
      rm -rf "$tmp" ;;
  esac
  return $ok
}

