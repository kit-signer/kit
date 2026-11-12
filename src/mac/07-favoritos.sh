# ===================== FAVORITOS NOS NAVEGADORES =====================

adicionar_favoritos_chrome() {
  local home_u="/Users/$USUARIO_TELA"
  local base_cr="$home_u/Library/Application Support/Google/Chrome"
  if [ ! -d "/Applications/Google Chrome.app" ] && [ ! -d "$base_cr" ]; then
    aviso "  Google Chrome nao encontrado neste Mac."
    return
  fi
  mkdir -p "$base_cr/Default"
  local p arq_fav arq_pref
  for p in "$base_cr"/Default "$base_cr"/Profile\ *; do
    [ -d "$p" ] || continue
    arq_fav="$p/Bookmarks"
    arq_pref="$p/Preferences"
    rm -f "$arq_fav.bak"
    /usr/bin/python3 - "$arq_fav" "$arq_pref" "${FAVORITOS[@]}" <<'PY'
import json, os, sys, time, uuid

arq_fav, arq_pref = sys.argv[1], sys.argv[2]
itens = [x.split("|", 1) for x in sys.argv[3:] if "|" in x]
agora = str(int((time.time() + 11644473600) * 1000000))

dados = None
if os.path.exists(arq_fav):
    try:
        with open(arq_fav, "r", encoding="utf-8") as f:
            dados = json.load(f)
    except Exception:
        dados = None

if not isinstance(dados, dict) or "roots" not in dados or "bookmark_bar" not in dados.get("roots", {}):
    dados = {
        "roots": {
            "bookmark_bar": {
                "children": [],
                "date_added": agora,
                "date_last_used": "0",
                "date_modified": agora,
                "guid": "0bc5d13f-2cba-5d74-951f-3f233fe6c908",
                "id": "1",
                "name": "Barra de favoritos",
                "type": "folder"
            },
            "other": {
                "children": [],
                "date_added": agora,
                "date_last_used": "0",
                "date_modified": "0",
                "guid": "82b081ec-3dd3-529c-8475-ab6c344590dd",
                "id": "2",
                "name": "Outros favoritos",
                "type": "folder"
            },
            "synced": {
                "children": [],
                "date_added": agora,
                "date_last_used": "0",
                "date_modified": "0",
                "guid": "4cf2e351-0e85-532b-bb37-df045d8f8d0f",
                "id": "3",
                "name": "Dispositivos moveis",
                "type": "folder"
            }
        },
        "version": 1
    }

def achar_max_id(obj):
    m = 10
    if isinstance(obj, dict):
        if "id" in obj and str(obj["id"]).isdigit():
            m = max(m, int(obj["id"]))
        for v in obj.values():
            m = max(m, achar_max_id(v))
    elif isinstance(obj, list):
        for v in obj:
            m = max(m, achar_max_id(v))
    return m

max_id = achar_max_id(dados)
atuais = dados["roots"]["bookmark_bar"].setdefault("children", [])
urls_existentes = {c.get("url") for c in atuais if isinstance(c, dict)}
novos = 0
for nome, url in itens:
    if url in urls_existentes:
        continue
    max_id += 1
    atuais.append({
        "date_added": agora,
        "date_last_used": "0",
        "guid": str(uuid.uuid4()),
        "id": str(max_id),
        "name": nome,
        "type": "url",
        "url": url
    })
    novos += 1

dados["roots"]["bookmark_bar"]["date_modified"] = agora
dados.pop("checksum", None)
with open(arq_fav, "w", encoding="utf-8") as f:
    json.dump(dados, f, ensure_ascii=False, indent=3)

prefs = {}
if os.path.exists(arq_pref):
    try:
        with open(arq_pref, "r", encoding="utf-8") as f:
            prefs = json.load(f)
    except Exception:
        prefs = {}
if not isinstance(prefs, dict):
    prefs = {}
prefs.setdefault("bookmark_bar", {})["show_on_all_tabs"] = True
with open(arq_pref, "w", encoding="utf-8") as f:
    json.dump(prefs, f, ensure_ascii=False)
PY
    echo "${VERDE}  [OK] Chrome ($(basename "$p")): favoritos configurados na barra de favoritos.${FIM}"
  done
  chown -R "$USUARIO_TELA" "$base_cr" 2>/dev/null
}

adicionar_favoritos_firefox() {
  if [ ! -d "$FX" ]; then
    aviso "  Mozilla Firefox nao encontrado neste Mac."
    return
  fi
  gravar_politica_firefox "manter" "true"
  garantir_perfil_firefox
  local home_u="/Users/$USUARIO_TELA"
  local base_fx="$home_u/Library/Application Support/Firefox/Profiles"
  if [ -d "$base_fx" ]; then
    local p arq
    for p in "$base_fx"/*; do
      [ -d "$p" ] || continue
      for arq in "$p/prefs.js" "$p/user.js"; do
        [ "$arq" = "$p/prefs.js" ] && [ ! -f "$arq" ] && continue
        if [ -f "$arq" ]; then
          grep -v 'browser\.toolbars\.bookmarks\.visibility' "$arq" > "$arq.tmp"
        else
          : > "$arq.tmp"
        fi
        printf 'user_pref("browser.toolbars.bookmarks.visibility", "always");\n' >> "$arq.tmp"
        mv -f "$arq.tmp" "$arq"
        chown "$USUARIO_TELA" "$arq" 2>/dev/null
      done
    done
  fi
  echo "${VERDE}  [OK] Firefox: ${#FAVORITOS[@]} favoritos adicionados na barra de favoritos.${FIM}"
}

menu_favoritos() {
  local op linha nome lista=""
  for linha in "${FAVORITOS[@]}"; do
    IFS='|' read -r nome _ <<< "$linha"
    if [ -z "$lista" ]; then lista="$nome"; else lista="$lista, $nome"; fi
  done
  while true; do
    cabecalho
    echo "${CIANO}   ADICIONAR FAVORITOS DOS TRIBUNAIS${FIM}"
    echo "${CINZA}   Adiciona na barra de favoritos sem apagar os favoritos que ja existem:${FIM}"
    echo "${CINZA}   $lista${FIM}"
    echo
    echo "   Em qual navegador voce quer adicionar os favoritos?"
    echo
    echo "   [1] Google Chrome"
    echo "   [2] Mozilla Firefox"
    echo "   [3] Nos dois (Chrome e Firefox)"
    echo "   [0] Voltar"; echo
    op="$(ler_opcao 1 2 3 0)"
    [ "$op" = "0" ] && return
    pkill -x "Google Chrome" 2>/dev/null; pkill -x firefox 2>/dev/null; sleep 1
    if [ "$op" = "1" ] || [ "$op" = "3" ]; then
      titulo "Google Chrome"
      adicionar_favoritos_chrome
    fi
    if [ "$op" = "2" ] || [ "$op" = "3" ]; then
      titulo "Mozilla Firefox"
      adicionar_favoritos_firefox
    fi
    pausar
  done
}


