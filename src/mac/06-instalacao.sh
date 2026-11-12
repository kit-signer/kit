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
    echo "   [3] Adicionar favoritos nos navegadores"
    echo "   [0] Voltar"; echo
    case "$(ler_opcao 1 2 3 0)" in
      1) instalar_com_log; pausar ;;
      2) menu_correcoes ;;
      3) menu_favoritos ;;
      0) return ;;
    esac
  done
}


