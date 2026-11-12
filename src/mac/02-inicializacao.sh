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


