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


