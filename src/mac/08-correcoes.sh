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
  gravar_politica_firefox "false" "manter"
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
    "corrigir_$op"
    pausar
  done
}


