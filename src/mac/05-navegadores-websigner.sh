# ===================== NAVEGADORES E WEB SIGNER ======================

DIR_EXT_CHROME="/Library/Application Support/Google/Chrome/External Extensions"
FX="/Applications/Firefox.app"

# Garante que o Firefox ja tenha pasta de perfil criada, mesmo se acabou de ser instalado
garantir_perfil_firefox() {
  [ -d "$FX" ] || return 0
  local home_u="/Users/$USUARIO_TELA"
  local base_fx="$home_u/Library/Application Support/Firefox/Profiles"
  if ! ls "$base_fx"/* >/dev/null 2>&1; then
    launchctl asuser "$(id -u "$USUARIO_TELA")" sudo -u "$USUARIO_TELA" "$FX/Contents/MacOS/firefox" -headless >/dev/null 2>&1 &
    local pid_fx=$! i
    # disown: sem isso o bash escreve "Terminated: 15" na tela quando o Firefox e fechado
    disown "$pid_fx" 2>/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
      sleep 0.5
      ls "$base_fx"/* >/dev/null 2>&1 && break
    done
    kill "$pid_fx" 2>/dev/null; pkill -x firefox 2>/dev/null; sleep 1
  fi
}

# Escreve o policies.json do Firefox preservando extensao e favoritos
# Parametros: extensao ("true"|"false"|"manter") favoritos ("true"|"false"|"manter")
gravar_politica_firefox() {
  [ -d "$FX" ] || return 1
  local ext="${1:-manter}" fav="${2:-manter}"
  local dist="$FX/Contents/Resources/distribution"
  local arq="$dist/policies.json"
  if [ "$ext" = "manter" ]; then
    if grep -q "$WEBSIGNER_FIREFOX_ID" "$arq" 2>/dev/null; then ext="true"; else ext="false"; fi
  fi
  if [ "$fav" = "manter" ]; then
    if grep -q '"Bookmarks"' "$arq" 2>/dev/null; then fav="true"; else fav="false"; fi
  fi
  if [ "$ext" = "false" ] && [ "$fav" = "false" ]; then
    rm -f "$arq"
    return 0
  fi
  mkdir -p "$dist"
  [ -f "$arq" ] && [ ! -f "$arq.bak" ] && cp -f "$arq" "$arq.bak"
  {
    printf '{\n  "policies": {\n'
    printf '    "SkipTermsOfUse": true,\n'
    printf '    "OverrideFirstRunPage": "",\n'
    printf '    "OverridePostUpdatePage": "",\n'
    printf '    "DontCheckDefaultBrowser": true,\n'
    printf '    "UserMessaging": {\n'
    printf '      "WhatsNew": false,\n'
    printf '      "ExtensionRecommendations": false,\n'
    printf '      "FeatureRecommendations": false,\n'
    printf '      "UrlbarInterventions": false,\n'
    printf '      "SkipOnboarding": true,\n'
    printf '      "MoreFromMozilla": false\n'
    printf '    },\n'
    printf '    "Preferences": {\n'
    printf '      "extensions.webextensions.keepStorageOnUninstall": { "Value": true, "Status": "default" },\n'
    printf '      "browser.aboutwelcome.enabled": { "Value": false, "Status": "default" },\n'
    printf '      "datareporting.policy.dataSubmissionPolicyBypassNotification": { "Value": true, "Status": "default" },\n'
    printf '      "extensions.autoDisableScopes": { "Value": 0, "Status": "default" }\n'
    printf '    }'
    if [ "$ext" = "true" ]; then
      printf ',\n    "ExtensionSettings": {\n'
      printf '      "%s": {\n' "$WEBSIGNER_FIREFOX_ID"
      printf '        "installation_mode": "force_installed",\n'
      printf '        "install_url": "file://%s/websigner.xpi"\n' "$PASTA_TI"
      printf '      }\n    }'
    fi
    if [ "$fav" = "true" ]; then
      printf ',\n    "DisplayBookmarksToolbar": "always",\n'
      printf '    "Bookmarks": [\n'
      local idx=0 total="${#FAVORITOS[@]}" linha nome url
      for linha in "${FAVORITOS[@]}"; do
        idx=$((idx + 1))
        IFS='|' read -r nome url <<< "$linha"
        if [ "$idx" -lt "$total" ]; then
          printf '      { "Title": "%s", "URL": "%s", "Placement": "toolbar" },\n' "$nome" "$url"
        else
          printf '      { "Title": "%s", "URL": "%s", "Placement": "toolbar" }\n' "$nome" "$url"
        fi
      done
      printf '    ]'
    fi
    printf '\n  }\n}\n'
  } > "$arq"
  return 0
}

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
  local pkcs11_json='["libeToken.dylib","libaetpkss.dylib"]'
  local marca="libeToken.dylib"
  # Token SafeNet nao reconhecido: o Web Signer acha o driver pelo nome curto
  # (libeToken.dylib), e em varios Macs isso nao basta. Com o SafeNet instalado,
  # acrescenta tambem o caminho completo como "modulo personalizado" (o mesmo que
  # se digitava a mao em Cripto Dispositivos). Mesmo conteudo, com o caminho a mais:
  #   pkcs11 = ["libeToken.dylib","libaetpkss.dylib","/usr/local/lib/libeTPkcs11.dylib"]
  if [ -f "$MODULO_SAFENET_MAC" ]; then
    log_mac_b64="YtCCQGoAAQEAAAAAAAAAAgAAAAEGcGtjczExSVsibGliZVRva2VuLmR5bGliIiwibGliYWV0cGtzcy5keWxpYiIsIi91c3IvbG9jYWwvbGliL2xpYmVUUGtjczExLmR5bGliIl0BBXRyYWNlBHRydWU="
    pkcs11_json='["libeToken.dylib","libaetpkss.dylib","/usr/local/lib/libeTPkcs11.dylib"]'
    marca="libeTPkcs11.dylib"
  fi
  local p dir_db

  mkdir -p "$base_cr/Default"
  for p in "$base_cr"/Default "$base_cr"/Profile\ *; do
    [ -d "$p" ] || continue
    dir_db="$p/Local Extension Settings/$WEBSIGNER_CHROME_ID"
    if grep -q "$marca" "$dir_db"/*.log "$dir_db"/*.ldb 2>/dev/null && \
       grep -q "trace" "$dir_db"/*.log "$dir_db"/*.ldb 2>/dev/null; then
      continue
    fi
    mkdir -p "$dir_db" && rm -f "$dir_db"/*
    echo "$manifest_b64" | base64 -D > "$dir_db/MANIFEST-000001"
    printf 'MANIFEST-000001\n' > "$dir_db/CURRENT"
    echo "$log_mac_b64" | base64 -D > "$dir_db/000003.log"
  done
  chown -R "$USUARIO_TELA" "$base_cr" 2>/dev/null

  garantir_perfil_firefox
  if [ -d "$base_fx" ]; then
    local regex_limpar='ExtensionStorageIDB\.migrated\.websigner@softplan_com_br|extensions\.webextensions\.keepStorageOnUninstall|browser\.aboutwelcome\.enabled|datareporting\.policy\.dataSubmissionPolicyBypassNotification|termsofuse\.accepted|extensions\.autoDisableScopes'
    for p in "$base_fx"/*; do
      [ -d "$p" ] || continue
      if grep -q "$marca" "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID"/storage.js*.migrated 2>/dev/null && \
         [ -f "$p/extensions/$WEBSIGNER_FIREFOX_ID.xpi" ]; then
        continue
      fi
      if [ -f "$p/prefs.js" ]; then
        local uuid_fx
        uuid_fx="$(sed -n 's/.*"websigner@softplan_com_br"[[:space:]]*:[[:space:]]*\\*"\([0-9a-fA-F-]*\)\\*".*/\1/p' "$p/prefs.js" | head -1)"
        [ -n "$uuid_fx" ] && rm -rf "$p/storage/default/moz-extension+++$uuid_fx"*
        grep -vE "$regex_limpar" "$p/prefs.js" > "$p/prefs.js.tmp"
        {
          printf 'user_pref("extensions.webextensions.keepStorageOnUninstall", true);\n'
          printf 'user_pref("browser.aboutwelcome.enabled", false);\n'
          printf 'user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);\n'
          printf 'user_pref("termsofuse.acceptedVersion", 999);\n'
          printf 'user_pref("termsofuse.acceptedDate", "1740000000000");\n'
          printf 'user_pref("extensions.autoDisableScopes", 0);\n'
        } >> "$p/prefs.js.tmp"
        mv -f "$p/prefs.js.tmp" "$p/prefs.js"
        chown "$USUARIO_TELA" "$p/prefs.js" 2>/dev/null
      fi
      if [ -f "$p/user.js" ]; then
        grep -vE "$regex_limpar" "$p/user.js" > "$p/user.js.tmp"
      else
        : > "$p/user.js.tmp"
      fi
      {
        printf 'user_pref("extensions.webextensions.keepStorageOnUninstall", true);\n'
        printf 'user_pref("browser.aboutwelcome.enabled", false);\n'
        printf 'user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);\n'
        printf 'user_pref("termsofuse.acceptedVersion", 999);\n'
        printf 'user_pref("termsofuse.acceptedDate", "1740000000000");\n'
        printf 'user_pref("extensions.autoDisableScopes", 0);\n'
      } >> "$p/user.js.tmp"
      mv -f "$p/user.js.tmp" "$p/user.js"
      chown "$USUARIO_TELA" "$p/user.js" 2>/dev/null
      mkdir -p "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID"
      rm -f "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID"/storage.js*
      printf '{"pkcs11":%s,"trace":true}\n' "$pkcs11_json" > "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID/storage.js"
      chown -R "$USUARIO_TELA" "$p/browser-extension-data" 2>/dev/null

      if [ -d "$FX" ] && [ -f "$PASTA_TI/websigner.xpi" ]; then
        launchctl asuser "$(id -u "$USUARIO_TELA")" sudo -u "$USUARIO_TELA" "$FX/Contents/MacOS/firefox" -headless -no-remote -profile "$p" >/dev/null 2>&1 &
        local pid_p=$! j
        disown "$pid_p" 2>/dev/null
        for j in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24; do
          sleep 0.5
          if [ -f "$p/extensions/$WEBSIGNER_FIREFOX_ID.xpi" ] && \
             ls "$p/browser-extension-data/$WEBSIGNER_FIREFOX_ID"/storage.js*.migrated >/dev/null 2>&1; then
            break
          fi
        done
        # Espera o Firefox gravar o cadastro da extensao (extensions.json) antes de fechar.
        # Fechado antes disso, ele desativa a extensao na proxima abertura.
        for j in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
          if grep -q "\"id\":\"$WEBSIGNER_FIREFOX_ID\"" "$p/extensions.json" 2>/dev/null; then sleep 1; break; fi
          sleep 0.5
        done
        kill "$pid_p" 2>/dev/null; pkill -x firefox 2>/dev/null; sleep 0.5
        rm -f "$p/parent.lock" "$p/.parentlock"
      fi
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
      gravar_politica_firefox "true" "manter"
      echo "Firefox: extensao forcada."
    fi
  fi
  configurar_toggles_websigner
}


