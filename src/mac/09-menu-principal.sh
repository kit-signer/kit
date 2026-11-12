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
