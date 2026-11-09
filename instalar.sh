#!/bin/bash
# =====================================================================
#  instalar.sh - Kit de TI da CAAAL (Mac)
#
#  Uso pela internet (Terminal do Mac):
#    curl -fsSL https://raw.githubusercontent.com/kit-signer/kit/main/instalar.sh | bash
#  Uso pelo pendrive:
#    dois cliques no INSTALAR.command (usa a pasta "instaladores" ao lado, sem baixar nada)
#
#  Pode rodar quantas vezes quiser: o que ja estiver instalado e pulado.
#  Compativel com o bash 3.2 que vem no macOS.
# =====================================================================

# ========================= CONFIGURACAO ==============================

EMPRESA="CAAAL"
REPOSITORIO="kit-signer/kit"   # dono/repositorio no GitHub

URL_SCRIPT="https://raw.githubusercontent.com/$REPOSITORIO/main/instalar.sh"
URL_SCRIPT_WIN="https://raw.githubusercontent.com/$REPOSITORIO/main/instalar.ps1"
URL_ARQUIVOS="https://github.com/$REPOSITORIO/releases/download/instaladores"

# Pasta local para logs e downloads (sem espacos no caminho, de proposito)
PASTA_TI="/Users/Shared/TI"

# Programas do kit, nesta ordem.  Formato:  Nome|Chave|Busca|Modo
#   Chave = liga o programa aos arquivos da lista ARQUIVOS abaixo
#   Busca = trecho (regex, sem diferenciar maiusculas) do nome do app em
#           /Applications ou do ID do pacote em "pkgutil --pkgs"
#   Modo  = o que fazer se vier um .app em vez de .pkg:
#           copiar = e o proprio programa: copia para /Applications
#           abrir  = e um INSTALADOR com janelas: abre e espera alguem concluir
PROGRAMAS=(
  "PJeOffice Pro|pjeoffice|pjeoffice|copiar"
  "SafeNet (token)|safenet|safenet|abrir"
  "Driver do token GD|safesign|safesign|abrir"
  "Driver StarSign|starsign|starsign|abrir"
  "Web Signer|websigner|web ?signer|abrir"
)

# Arquivos do kit (ficam no Release do GitHub, ou na pasta "instaladores" do pendrive).
# Formato:  Chave|Arquivo|macOS minimo|Processador|SHA256
#   macOS minimo = 0 serve para qualquer Mac. O script pega, entre os arquivos da
#                  mesma chave, o de maior "macOS minimo" que caiba neste Mac.
#   Processador  = qualquer, intel (so Mac Intel) ou arm (so M1/M2/M3...)
#   SHA256       = impressao digital. Se o arquivo baixado nao bater, NAO instala.
#                  Para gerar:  shasum -a 256 arquivo   (no Windows: Get-FileHash)
# Para o Web Signer de Mac: suba o .pkg no Release e acrescente uma linha "websigner|...".
ARQUIVOS=(
  "pjeoffice|mac-pjeoffice-2.5.16u.dmg|0|qualquer|d28bbbb91aa140f9b16f6665ab5fa03873242cd82882b93873332d0e99ed2cb5"
  "safenet|mac-safenet-10.2r4-macos12.zip|12|qualquer|a4055ed4d6584e400d86c57b744b42aa7f908b3939d7223487bfe20b2a519a86"
  "safesign|mac-safesign-3.5.0.0-macos10.13-intel.zip|10.13|intel|0e882809cc43306808e34c4950766a308604af358879be3b06a39f1c42098663"
  "safesign|mac-safesign-3.6.0-macos10.15.zip|10.15|qualquer|47818b40678dbf107da4355ce2a015ea4e89d1a181093caafb823d2a0801a9c5"
  "safesign|mac-safesign-3.7.0.1-macos11.zip|11|qualquer|6e7a5b041c4539dd0b1d7b780e37549ccdff8d6fa63b30ea0ad697ddc88e85ce"
  "safesign|mac-safesign-3.7.1.0-macos12-intel.zip|12|intel|73a2d9d00fc06b2613733233075ceed2a92ef49cc5afe439af7c7bfc9800a496"
  "starsign|mac-starsign.zip|0|qualquer|5fe2e8ed898fce5b2ff219ce223d2a0addeeae27d0fd39c1ff217031c146d192"
)

# Navegadores baixados direto do site oficial.  Formato: Nome|App|URL do .dmg
NAVEGADORES=(
  "Google Chrome|Google Chrome.app|https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
  "Mozilla Firefox|Firefox.app|https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=pt-BR"
)

# Extensao Web Signer (Softplan)
WEBSIGNER_CHROME_ID="bbafmabaelnnkondpfpjmdklbmfnbmol"
CHROME_STORE_UPDATE="https://clients2.google.com/service/update2/crx"
WEBSIGNER_FIREFOX_ID="websigner@softplan_com_br"
WEBSIGNER_XPI="websigner.xpi|2c16afbfb80dff721e2796ffae262093a8558d68ac15b77af5f8169085ea5c6a"

# Tipos de token reconhecidos no cabecalho, pelo nome que o aparelho USB informa.
# Formato:  padrao;Tipo;busca do driver;nome do driver   (separado por ponto e virgula)
#   padrao = trecho do nome (expressao regular, sem diferenciar maiusculas)
#   busca do driver = como a funcao "instalado" acha o driver (vazio = nao vem no kit)
TIPOS_TOKEN=(
  "etoken|token jc|safenet|aladdin;SafeNet eToken;safenet;SafeNet"
  "idprime|gemalto;Thales/Gemalto IDPrime;safenet;SafeNet"
  "starsign|giesecke|g&d|g\+d|smart ?cafe|sm@rtcafe;G+D StarSign;safesign;SafeSign"
  "watchdata|proxkey;Watchdata;;"
  "epass|feitian;Feitian ePass;;"
)

# ====================== FIM DA CONFIGURACAO ==========================


# Rodando de um arquivo (pendrive) ou pela internet (curl | bash)?
PASTA_LOCAL=""
case "$0" in
  *instalar.sh)
    DIR_SCRIPT="$(cd "$(dirname "$0")" && pwd)"
    [ -d "$DIR_SCRIPT/instaladores" ] && PASTA_LOCAL="$DIR_SCRIPT/instaladores" ;;
esac

# --- Garante que esta rodando como administrador (root) ---
if [ "$(id -u)" -ne 0 ]; then
  echo "Precisa de permissao de administrador. Digite a senha do Mac (nao aparece enquanto digita):"
  case "$0" in
    *instalar.sh) exec sudo bash "$0" "$@" < /dev/tty ;;
    *)
      # Veio pelo "curl | bash": baixa uma copia do script e roda ela como administrador
      COPIA="$(mktemp /tmp/kit-ti.XXXXXX)" || exit 1
      curl -fsSL --retry 3 -o "$COPIA" "$URL_SCRIPT" || { echo "Nao consegui baixar o kit."; exit 1; }
      exec sudo bash "$COPIA" --copia < /dev/tty ;;
  esac
fi
[ "$1" = "--copia" ] && trap 'rm -f "$0"' EXIT

mkdir -p "$PASTA_TI/logs" "$PASTA_TI/instaladores"

CIANO=$'\033[36m'; VERDE=$'\033[32m'; AMARELO=$'\033[33m'; VERMELHO=$'\033[31m'; CINZA=$'\033[90m'; FIM=$'\033[0m'
titulo() { echo; echo "${CIANO}=== $1 ===${FIM}"; }
aviso()  { echo "${AMARELO}$1${FIM}"; }

# Perguntas leem direto do teclado (no "curl | bash" a entrada padrao e o proprio script)
perguntar() { local r; read -r -p "   $1" r < /dev/tty; echo "$r"; }


# ============================ TELA ===================================

cabecalho() {
  clear
  printf '\033]0;%s - Kit de TI\007' "$EMPRESA"
  echo
  echo "${AMARELO}     ____    _        _        _      _     "
  echo "    / ___|  / \\      / \\      / \\    | |    "
  echo "   | |     / _ \\    / _ \\    / _ \\   | |    "
  echo "   | |___ / ___ \\  / ___ \\  / ___ \\  | |___ "
  echo "    \\____/_/   \\_\\/_/   \\_\\/_/   \\_\\ |_____|${FIM}"
  echo
  echo "   Kit de TI  |  Configuracao de maquina"
  echo "${CINZA}   Computador: $(scutil --get ComputerName 2>/dev/null || hostname)   Usuario: $(stat -f%Su /dev/console)${FIM}"
  status_token
  echo "${CINZA}   -------------------------------------------${FIM}"
  echo
}

# Nomes dos aparelhos USB conectados (o token informa o proprio nome, ex.: "StarSign CUT S")
nomes_usb() {
  ioreg -p IOUSB -l -w0 2>/dev/null | sed -n 's/.*"USB Product Name" = "\(.*\)"/\1/p'
}

# Linha do token no cabecalho
status_token() {
  local nome linha padrao tipo busca driver achou=0
  while IFS= read -r nome; do
    [ -n "$nome" ] || continue
    for linha in "${TIPOS_TOKEN[@]}"; do
      IFS=';' read -r padrao tipo busca driver <<< "$linha"
      echo "$nome" | grep -qiE "$padrao" || continue
      achou=1
      if [ -z "$busca" ]; then echo "${CINZA}   Token: $tipo conectado ${AMARELO}(driver nao vem no kit)${FIM}"
      elif instalado "$busca"; then echo "${CINZA}   Token: $tipo conectado ${VERDE}(driver $driver instalado)${FIM}"
      else echo "${CINZA}   Token: $tipo conectado ${VERMELHO}(FALTA o driver $driver: use Instalar programas)${FIM}"; fi
      break
    done
  done <<< "$(nomes_usb)"
  [ "$achou" = "1" ] || echo "${CINZA}   Token: nenhum conectado${FIM}"
}

ler_opcao() {
  local op v
  while true; do
    op="$(perguntar "Escolha uma opcao: ")"
    for v in "$@"; do [ "$op" = "$v" ] && { echo "$op"; return; }; done
    echo "${AMARELO}   Opcao invalida. Digite: $*${FIM}" >&2
  done
}

pausar() { echo; perguntar "Pressione Enter para voltar ao menu" > /dev/null; }


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

DIR_EXT_CHROME="/Library/Application Support/Google/Chrome/External Extensions"
FX="/Applications/Firefox.app"

# Ativa automaticamente os toggles internos da extensao Web Signer:
#   - Cripto Dispositivos (PKCS #11): Tokens SafeNet, Dispositivos SafeSign AET
#   - Avancadas: Habilitar logs detalhados (trace = true)
configurar_toggles_websigner() {
  local home_u="/Users/$USUARIO_TELA"
  local base_cr="$home_u/Library/Application Support/Google/Chrome"
  local base_fx="$home_u/Library/Application Support/Firefox/Profiles"
  pkill -x "Google Chrome" 2>/dev/null; pkill -x firefox 2>/dev/null; sleep 1

  local manifest_b64="lXy5xSIAAQEabGV2ZWxkYi5CeXRld2lzZUNvbXBhcmF0b3ICAAMCBAA="
  local log_mac_b64="XSYwaUcAAQEAAAAAAAAAAgAAAAEGcGtjczExJlsibGliZVRva2VuLmR5bGliIiwibGliYWV0cGtzcy5keWxpYiJdAQV0cmFjZQR0cnVl"
  local p dir_db

  mkdir -p "$base_cr/Default"
  for p in "$base_cr"/Default "$base_cr"/Profile\ *; do
    [ -d "$p" ] || continue
    dir_db="$p/Local Extension Settings/$WEBSIGNER_CHROME_ID"
    if grep -q "libeToken.dylib" "$dir_db"/*.log "$dir_db"/*.ldb 2>/dev/null && \
       grep -q "trace" "$dir_db"/*.log "$dir_db"/*.ldb 2>/dev/null; then
      continue
    fi
    mkdir -p "$dir_db" && rm -f "$dir_db"/*
    echo "$manifest_b64" | base64 -D > "$dir_db/MANIFEST-000001"
    printf 'MANIFEST-000001\n' > "$dir_db/CURRENT"
    echo "$log_mac_b64" | base64 -D > "$dir_db/000003.log"
  done
  chown -R "$USUARIO_TELA" "$base_cr" 2>/dev/null

  if [ -d "$base_fx" ]; then
    for p in "$base_fx"/*; do
      [ -d "$p" ] || continue
      ls "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID"/storage.js*.migrated >/dev/null 2>&1 && continue
      if [ -f "$p/prefs.js" ]; then
        local uuid_fx
        uuid_fx="$(sed -n 's/.*"websigner@softplan_com_br"[[:space:]]*:[[:space:]]*\\*"\([0-9a-fA-F-]*\)\\*".*/\1/p' "$p/prefs.js" | head -1)"
        [ -n "$uuid_fx" ] && rm -rf "$p/storage/default/moz-extension+++$uuid_fx"*
        grep -vE 'ExtensionStorageIDB\.migrated\.websigner@softplan_com_br|extensions\.webextensions\.keepStorageOnUninstall' "$p/prefs.js" > "$p/prefs.js.tmp"
        printf 'user_pref("extensions.webextensions.keepStorageOnUninstall", true);\n' >> "$p/prefs.js.tmp"
        mv -f "$p/prefs.js.tmp" "$p/prefs.js"
        chown "$USUARIO_TELA" "$p/prefs.js" 2>/dev/null
      fi
      mkdir -p "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID"
      printf '{"pkcs11":["libeToken.dylib","libaetpkss.dylib"],"trace":true}\n' > "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID/storage.js"
      chown -R "$USUARIO_TELA" "$p/browser-extension-data" 2>/dev/null
    done
  fi
  echo "Web Signer: toggles (SafeNet, SafeSign e logs detalhados) ativados."
}

aplicar_extensao() {
  # Chrome: "extensao externa" -> o Chrome instala e pede para o usuario ATIVAR
  mkdir -p "$DIR_EXT_CHROME"
  printf '{\n  "external_update_url": "%s"\n}\n' "$CHROME_STORE_UPDATE" > "$DIR_EXT_CHROME/$WEBSIGNER_CHROME_ID.json"
  chmod 644 "$DIR_EXT_CHROME/$WEBSIGNER_CHROME_ID.json"
  echo "Chrome: extensao registrada (ao abrir, clique em 'Ativar extensao')."

  # Firefox: policies.json dentro do app (forcada, sem o usuario precisar aceitar)
  if [ ! -d "$FX" ]; then
    aviso "Firefox nao encontrado; politica nao aplicada."
  else
    local xpi_arq xpi_sha xpi
    IFS='|' read -r xpi_arq xpi_sha <<< "$WEBSIGNER_XPI"
    xpi="$(obter_arquivo "$xpi_arq" "$xpi_sha")"
    if [ -n "$xpi" ]; then
      cp -f "$xpi" "$PASTA_TI/websigner.xpi" && chmod 644 "$PASTA_TI/websigner.xpi"
      local DIST="$FX/Contents/Resources/distribution"
      mkdir -p "$DIST"
      [ -f "$DIST/policies.json" ] && cp -f "$DIST/policies.json" "$DIST/policies.json.bak"
      cat > "$DIST/policies.json" <<JSON
{
  "policies": {
    "ExtensionSettings": {
      "$WEBSIGNER_FIREFOX_ID": {
        "installation_mode": "force_installed",
        "install_url": "file://$PASTA_TI/websigner.xpi"
      }
    }
  }
}
JSON
      echo "Firefox: extensao forcada."
    fi
  fi
  configurar_toggles_websigner
}


# ======================= 1. INSTALACAO ===============================

instalar_mac() {
  local linha nome app url dmg chave busca modo escolhido arq sha caminho item ok det
  local RESULTADO=()
  registrar() { RESULTADO+=("$1|$2|$3"); }   # item|ok(1/0)|detalhe

  titulo "0/4 Preparacao"
  echo "Mac: macOS $MACOS_VER - processador $ARQ"
  if [ "$ARQ" = "arm" ]; then
    if /usr/bin/pgrep -q oahd; then
      echo "${CINZA}[ja instalado] Rosetta 2${FIM}"
    else
      echo "Instalando Rosetta 2 (necessario para programas feitos para Intel)..."
      softwareupdate --install-rosetta --agree-to-license
    fi
  else
    echo "Mac Intel: Rosetta nao necessario."
  fi

  titulo "1/4 Navegadores"
  for linha in "${NAVEGADORES[@]}"; do
    IFS='|' read -r nome app url <<< "$linha"
    if [ -d "/Applications/$app" ]; then echo "${CINZA}[ja instalado] $nome${FIM}"; continue; fi
    echo "Baixando $nome..."
    dmg="$PASTA_TI/$(echo "$nome" | tr ' ' '-').dmg"
    if curl -fL --retry 5 --progress-bar -o "$dmg" "$url"; then
      instalar_arquivo "$dmg" || aviso "  Falha ao instalar $nome."
      rm -f "$dmg"
    else
      aviso "  Falha no download de $nome."
    fi
  done

  titulo "2/4 Programas do kit"
  for linha in "${PROGRAMAS[@]}"; do
    IFS='|' read -r nome chave busca modo <<< "$linha"
    if instalado "$busca"; then echo "${CINZA}[ja instalado] $nome${FIM}"; continue; fi
    escolhido="$(escolher_arquivo "$chave")"
    if [ -z "$escolhido" ]; then
      aviso "Nao tem instalador de $nome para macOS $MACOS_VER ($ARQ) no kit."; continue
    fi
    IFS='|' read -r arq sha <<< "$escolhido"
    caminho="$(obter_arquivo "$arq" "$sha")"
    [ -n "$caminho" ] || continue
    echo "Instalando $nome ($arq)..."
    instalar_arquivo "$caminho" "$modo" || aviso "  Falha ao instalar $nome - confira o instalador."
  done
  # libera os apps novos do Gatekeeper (evita o aviso "nao pode ser aberto")
  xattr -dr com.apple.quarantine /Applications/*.app 2>/dev/null

  titulo "3/4 Extensao Web Signer nos navegadores"
  aplicar_extensao

  titulo "4/4 Checagem final"
  for linha in "${NAVEGADORES[@]}"; do
    IFS='|' read -r nome app url <<< "$linha"
    if [ -d "/Applications/$app" ]; then registrar "$nome" 1 "instalado"; else registrar "$nome" 0 "NAO encontrado"; fi
  done
  for linha in "${PROGRAMAS[@]}"; do
    IFS='|' read -r nome chave busca modo <<< "$linha"
    if instalado "$busca"; then registrar "$nome" 1 "instalado"; else registrar "$nome" 0 "NAO encontrado"; fi
  done
  if [ -f "$DIR_EXT_CHROME/$WEBSIGNER_CHROME_ID.json" ]; then registrar "Extensao no Chrome" 1 "registrada"; else registrar "Extensao no Chrome" 0 "ausente"; fi
  if grep -q "$WEBSIGNER_FIREFOX_ID" "$FX/Contents/Resources/distribution/policies.json" 2>/dev/null; then
    registrar "Extensao no Firefox" 1 "politica aplicada"
  else
    registrar "Extensao no Firefox" 0 "politica ausente"
  fi

  echo
  for linha in "${RESULTADO[@]}"; do
    IFS='|' read -r item ok det <<< "$linha"
    if [ "$ok" = "1" ]; then printf "  ${VERDE}[OK]     %-22s %s${FIM}\n" "$item" "$det"
    else                     printf "  ${VERMELHO}[FALHOU] %-22s %s${FIM}\n" "$item" "$det"; fi
  done
  echo
  echo "${CIANO}Feche e abra os navegadores para a extensao aparecer.${FIM}"
  echo "${CIANO}Token: se o macOS pedir, libere o driver em Ajustes do Sistema > Privacidade e Seguranca.${FIM}"
}

instalar_com_log() {
  local log="$PASTA_TI/logs/setup-$(scutil --get ComputerName 2>/dev/null | tr ' ' '-')-$(date +%Y%m%d-%H%M).txt"
  instalar_mac 2>&1 | tee -a "$log"
  echo "Log salvo em: $log"
}

mostrar_comando_windows() {
  echo
  echo "${CIANO}   Este kit esta aberto num Mac. Para configurar um Windows, abra o${FIM}"
  echo "${CIANO}   PowerShell como administrador (nao o CMD) no Windows e cole:${FIM}"
  echo
  echo "   irm $URL_SCRIPT_WIN | Out-String | iex"
  echo
}

# Opcoes do Mac (so aparecem depois de escolher Mac na primeira tela)
menu_mac() {
  while true; do
    cabecalho
    echo "${CIANO}   MAC${FIM}"; echo
    echo "   [1] Instalar programas"
    echo "   [2] Correcao de erros"
    echo "   [0] Voltar"; echo
    case "$(ler_opcao 1 2 0)" in
      1) instalar_com_log; pausar ;;
      2) menu_correcoes ;;
      0) return ;;
    esac
  done
}


# ===================== 2. CORRECAO DE ERROS ==========================
# Para adicionar uma correcao: crie uma funcao corrigir_N e acrescente
# "Nome|Descricao" na lista CORRECOES, na mesma posicao N.

CORRECOES=(
  "Token nao reconhecido|Reinicia o servico de leitor de token do macOS. Tire e coloque o token depois."
  "Extensao Web Signer sumiu|Registra de novo a extensao no Chrome e no Firefox."
  "Navegador ou PJeOffice travado|Fecha Chrome, Firefox e PJeOffice (salve o que estiver aberto antes)."
  "Programa 'nao pode ser aberto'|Libera os apps de /Applications bloqueados pelo Gatekeeper."
  "Remover extensao Web Signer|Desfaz o passo 3 da instalacao no Chrome e no Firefox."
)

corrigir_1() {
  killall -9 com.apple.ctkpcscd 2>/dev/null   # o macOS liga o servico de novo sozinho
  echo "${VERDE}  Servico reiniciado. Tire o token, espere 5 segundos e coloque de novo.${FIM}"
}
corrigir_2() { aplicar_extensao; echo "${CIANO}  Feche e abra os navegadores.${FIM}"; }
corrigir_3() {
  pkill -x "Google Chrome"; pkill -x firefox; pkill -f -i pjeoffice
  echo "${VERDE}  Programas fechados. Pode abrir de novo.${FIM}"
}
corrigir_4() {
  xattr -dr com.apple.quarantine /Applications/*.app 2>/dev/null
  echo "${VERDE}  Apps liberados. Tente abrir de novo.${FIM}"
}
corrigir_5() {
  rm -f "$DIR_EXT_CHROME/$WEBSIGNER_CHROME_ID.json"
  rm -f "$FX/Contents/Resources/distribution/policies.json"
  echo "${VERDE}  Extensao removida. Feche e abra os navegadores.${FIM}"
}

menu_correcoes() {
  local i op nome desc validas
  while true; do
    cabecalho
    echo "${CIANO}   CORRECAO DE ERROS${FIM}"; echo
    validas="0"
    for i in "${!CORRECOES[@]}"; do
      IFS='|' read -r nome desc <<< "${CORRECOES[$i]}"
      echo "   [$((i + 1))] $nome"
      echo "${CINZA}       $desc${FIM}"
      validas="$validas $((i + 1))"
    done
    echo "   [0] Voltar"; echo
    op="$(ler_opcao $validas)"
    [ "$op" = "0" ] && return
    IFS='|' read -r nome desc <<< "${CORRECOES[$((op - 1))]}"
    titulo "$nome"
    if [ "$(perguntar "Confirmar? (S/N) " | tr '[:lower:]' '[:upper:]')" = "S" ]; then "corrigir_$op"; else echo "  Cancelado."; fi
    pausar
  done
}


# =========================== MENU ====================================

while true; do
  cabecalho
  echo "${CIANO}   Qual computador voce vai configurar?${FIM}"; echo
  echo "   [1] Windows"
  echo "   [2] Mac   (este computador)"
  echo "   [0] Sair"; echo
  case "$(ler_opcao 1 2 0)" in
    1) mostrar_comando_windows; pausar ;;
    2) menu_mac ;;
    0) echo; echo "${AMARELO}   Ate logo!${FIM}"; exit 0 ;;
  esac
done
