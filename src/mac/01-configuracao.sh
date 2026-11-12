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
#
#  ATENCAO: este arquivo e GERADO a partir da pasta src/mac.
#  Nao edite aqui: edite os arquivos de src/mac e rode o build.ps1
#  (veja "Como editar o kit" no README).
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
# Driver do token SafeNet no Mac (o Web Signer recebe esse caminho completo)
MODULO_SAFENET_MAC="/usr/local/lib/libeTPkcs11.dylib"
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

# Favoritos adicionados na barra de favoritos do Chrome e do Firefox (menu "Adicionar favoritos").
# Formato: Nome|Url
FAVORITOS=(
  "e-SAJ Estadual|https://www2.tjal.jus.br/esaj/portal.do?servico=190090"
  "PJE 2.X Previdencia|https://pje1g.trf5.jus.br/pje/login.seam"
  "PJE TRF5 Federal|https://pje.trf5.jus.br/pje/login.seam"
  "PJE TRT19 1ºGrau|https://pje.trt19.jus.br/primeirograu/login.seam"
  "GERID|https://geridinss.dataprev.gov.br/cas/login?service=https%3A%2F%2Fgeridinss.dataprev.gov.br%2Fcas%2Foauth2.0%2FcallbackAuthorize%3Fclient_id%3DSAG%26redirect_uri%3Dhttps%253A%252F%252Fnovorequerimento.inss.gov.br%26response_type%3Dtoken%26client_name%3DCasOAuthClient"
  "SEEU|https://seeu.pje.jus.br/seeu/"
  "CAA - AL|https://www.caa-al.org.br/"
  "OAB - AL|https://www.oab-al.org.br/"
  "WhatsAppWeb|https://web.whatsapp.com/"
  "iLOVE PDF|https://www.ilovepdf.com/pt"
)

# ====================== FIM DA CONFIGURACAO ==========================


