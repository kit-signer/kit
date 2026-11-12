# =====================================================================
#  instalar.ps1 - Kit de TI da CAAAL
#
#  Uso pela internet (no PowerShell, de preferencia como administrador):
#    irm https://raw.githubusercontent.com/kit-signer/kit/main/instalar.ps1 | Out-String | iex
#  Use o PowerShell, nao o CMD: pelo CMD o Defender bloqueia o comando como trojan.
#  Uso pelo pendrive:
#    dois cliques no INSTALAR.bat (usa a pasta "instaladores" ao lado, sem baixar nada)
#
#  Pode rodar quantas vezes quiser: o que ja estiver instalado e pulado.
#  Arquivo propositalmente sem acentos (o PowerShell 5.1 le acentos errado).
#
#  ATENCAO: este arquivo e GERADO a partir da pasta src\windows.
#  Nao edite aqui: edite os arquivos de src\windows e rode o build.ps1
#  (veja "Como editar o kit" no README).
# =====================================================================

# ========================= CONFIGURACAO ==============================

$Empresa    = "CAAAL"
$Repositorio = "kit-signer/kit"   # dono/repositorio no GitHub

$UrlScript   = "https://raw.githubusercontent.com/$Repositorio/main/instalar.ps1"
$UrlScriptMac = "https://raw.githubusercontent.com/$Repositorio/main/instalar.sh"
$UrlArquivos = "https://github.com/$Repositorio/releases/download/instaladores"

$PastaTI = "C:\ProgramData\TI"

# Programas instalados pelo winget (catalogo da Microsoft: baixa do site do fabricante
# e confere a impressao digital do arquivo).
#   Busca   = trecho do nome que aparece em "Aplicativos instalados"
#   Versao  = versao fixa. Sem Versao, instala a mais nova. Para atualizar, troque aqui
#             (veja as versoes com: winget show --id ID --versions).
#   Escopo  = "machine": instala para a maquina toda (Arquivos de Programas). Sem isso o
#             winget pode instalar so para o usuario, em outra pasta.
#   Reserva = plano B quando o winget nao existe (Windows 10 antigo) ou falha:
#               Url + Assinante: baixa do site do fabricante e SO instala se o arquivo
#                                estiver assinado digitalmente por esse fabricante
#               Release + Sha256: usa o arquivo do Release do kit (ou do pendrive)
$ProgramasWinget = @(
    @{ Nome = "WinRAR"; Id = "RARLab.WinRAR"; Escopo = "machine"; Busca = "WinRAR"
       Reserva = @{ Url = "https://www.rarlab.com/rar/winrar-x64-723br.exe"; Arquivo = "winrar.exe"; Argumentos = "/S"; Assinante = "win.rar GmbH" } },
    @{ Nome = "Google Chrome"; Id = "Google.Chrome"; Escopo = "machine"; Busca = "Google Chrome"
       Reserva = @{ Url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"; Arquivo = "chrome.msi"; Argumentos = "/qn /norestart"; Assinante = "Google LLC" } },
    @{ Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox"; Escopo = "machine"; Busca = "Mozilla Firefox"
       Reserva = @{ Url = "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=pt-BR"; Arquivo = "firefox.msi"; Argumentos = "/qn /norestart"; Assinante = "Mozilla Corporation" } },
    @{ Nome = "Web Signer"; Id = "SoftplanSistemas.WebSigner"; Versao = "2.15.0.0"; Busca = "Web Signer"
       Reserva = @{ Release = "websigner.msi"; Argumentos = "/qn /norestart"; Sha256 = "e66d0df97ff28272d4535b19f1ac3c67b13bc7ab3fb695e27ba72e5a1f4be0a3" } }
)

# Instaladores baixados do Release do GitHub (ou da pasta "instaladores" do pendrive).
# Aqui ficam os que nao estao no winget e os que no winget dao problema: o SafeNet
# do winget vem num pacote de 142 MB da DigiCert (o nosso tem 15 MB), e o SafeSign do
# winget vem de um link que o fabricante altera, o que fazia a instalacao falhar.
#   Arquivo    = nome exato do arquivo no Release (sem espacos)
#   Sha256     = impressao digital do arquivo. Se o arquivo baixado nao bater, NAO instala.
#                Para gerar: Get-FileHash .\arquivo.exe -Algorithm SHA256
#   Argumentos = parametros de instalacao silenciosa
#   Busca      = trecho do nome em "Aplicativos instalados"
# Ao atualizar um programa: troque o arquivo no Release "instaladores" (mesmo nome)
# e troque Versao e Sha256 aqui.
$InstaladoresKit = @(
    # PJeOffice usa instalador "Inno Setup": o modo silencioso e /VERYSILENT (o /S e de outro tipo e abria a janela)
    @{ Nome = "PJeOffice Pro";      Versao = "2.5.16u"; Arquivo = "pjeoffice.exe"; Argumentos = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-";
       Busca = "PJeOffice"; Sha256 = "8237999eff5313607daf53558b4a0b8f3aba4da670c6438ee34eb25120b45bc4" },
    @{ Nome = "SafeNet (token)";    Versao = "10.7";    Arquivo = "safenet.msi";   Argumentos = "/qn /norestart";
       Busca = "SafeNet Authentication Client"; Sha256 = "a998da33cab2d70675d5de9a8a114f870f643dba1f676f9586b263030c395e12" },
    # No fim, o SafeSign abre a janela "Instalador Firefox": pode clicar em Fechar (o kit ja configura
    # o token no Firefox). Pular essa janela com REMOVE=Firefox NAO funciona no 3.0.124: ele diz que
    # instalou e nao instala nada.
    @{ Nome = "Driver do token GD"; Versao = "3.0.124"; Arquivo = "safesign.exe";  Argumentos = '/s /v"/qn /norestart"';
       Busca = "SafeSign"; Sha256 = "0dad976c832526f494f665661fb8b47a93c5f9b969bc9b7d5496d6dd87ae6dfe" }
)

# Tipos de token reconhecidos no cabecalho, pelo aparelho USB conectado.
#   Padrao = trecho do nome que o USB informa (expressao regular, sem diferenciar maiusculas)
#   Vid    = codigo do fabricante no USB (ajuda quando o nome e generico)
#   Driver = como o driver aparece em "Aplicativos instalados" ($null = nao vem no kit)
$TiposToken = @(
    @{ Padrao = 'etoken|token jc|safenet|aladdin';                Vid = "0529"; Tipo = "SafeNet eToken";         Driver = "SafeNet Authentication Client"; DriverNome = "SafeNet" },
    @{ Padrao = 'idprime|gemalto';                                Vid = "08E6"; Tipo = "Thales/Gemalto IDPrime"; Driver = "SafeNet Authentication Client"; DriverNome = "SafeNet" },
    @{ Padrao = 'starsign|giesecke|g&d|g\+d|smart ?cafe|sm@rtcafe'; Vid = "";   Tipo = "G+D StarSign";           Driver = "SafeSign";                      DriverNome = "SafeSign" },
    @{ Padrao = 'watchdata|proxkey';                              Vid = "";     Tipo = "Watchdata";              Driver = $null;                           DriverNome = $null },
    @{ Padrao = 'epass|feitian';                                  Vid = "";     Tipo = "Feitian ePass";          Driver = $null;                           DriverNome = $null }
)

# Programas de uso pessoal que o kit instala mas NUNCA desinstala
# (nem aparecem na opcao "Desinstalar programas"). Use o Nome exatamente como acima.
$NaoDesinstalar = @("WinRAR", "Google Chrome", "Mozilla Firefox")

# Extensao Web Signer (Softplan)
$WebSignerChromeId  = "bbafmabaelnnkondpfpjmdklbmfnbmol"   # mesmo ID no Chrome e no Edge
$ChromeStoreUpdate  = "https://clients2.google.com/service/update2/crx"
$WebSignerFirefoxId = "websigner@softplan_com_br"
$WebSignerXpi       = @{ Arquivo = "websigner.xpi"; Sha256 = "2c16afbfb80dff721e2796ffae262093a8558d68ac15b77af5f8169085ea5c6a" }

# Cadeia de certificados ICP-Brasil (pacote oficial do ITI)
$UrlCadeiaIcp = "https://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil/ACcompactado.zip"
# Raizes que o kit instala (as aceitas pelo certificado-sso do TJAL). So entra no Windows
# a raiz cuja impressao digital esta AQUI; uma raiz nova no pacote do ITI e ignorada ate
# alguem conferir e acrescentar. Conferidas em 08/11/2026 no site oficial do ITI;
# v5 e v10 tambem batem com a lista de raizes confiaveis da Microsoft.
# v12 e a raiz da AC OAB G4 (certificados novos da OAB).
$RaizesIcp = [ordered]@{
    "4ACADAB14B74BF4FBA7BACE64B91801C44B8CC66" = "Raiz Brasileira v5"
    "6C155ED7271A904A0DC040F0C857FF53BF6DB290" = "Raiz Brasileira v10"
    "02FE43BA8401D92265DA3735592EF37DCD5174C3" = "Raiz Brasileira v11"
    "B8F21E4D86618E16787A4DE258142FDF2D61823C" = "Raiz Brasileira v12"
}
# Modulos dos tokens que o Firefox precisa carregar (so entra o que existir na maquina)
$ModulosToken = [ordered]@{
    "SafeNet"  = "C:\Windows\System32\eTPKCS11.dll"
    "SafeSign" = "C:\Windows\System32\aetpkss1.dll"
}

# Favoritos adicionados na barra de favoritos do Chrome e do Firefox (menu "Adicionar favoritos").
# Para incluir outro site, copie uma linha e troque Nome e Url.
$Favoritos = @(
    @{ Nome = "e-SAJ Estadual";                 Url = "https://www2.tjal.jus.br/esaj/portal.do?servico=190090" },
    @{ Nome = "PJE 2.X Previdencia";            Url = "https://pje1g.trf5.jus.br/pje/login.seam" },
    @{ Nome = "PJE TRF5 Federal";               Url = "https://pje.trf5.jus.br/pje/login.seam" },
    @{ Nome = "PJE TRT19 1$([char]0x00BA)Grau"; Url = "https://pje.trt19.jus.br/primeirograu/login.seam" },
    @{ Nome = "GERID";                          Url = "https://geridinss.dataprev.gov.br/cas/login?service=https%3A%2F%2Fgeridinss.dataprev.gov.br%2Fcas%2Foauth2.0%2FcallbackAuthorize%3Fclient_id%3DSAG%26redirect_uri%3Dhttps%253A%252F%252Fnovorequerimento.inss.gov.br%26response_type%3Dtoken%26client_name%3DCasOAuthClient" },
    @{ Nome = "SEEU";                           Url = "https://seeu.pje.jus.br/seeu/" },
    @{ Nome = "CAA - AL";                       Url = "https://www.caa-al.org.br/" },
    @{ Nome = "OAB - AL";                       Url = "https://www.oab-al.org.br/" },
    @{ Nome = "WhatsAppWeb";                    Url = "https://web.whatsapp.com/" },
    @{ Nome = "iLOVE PDF";                      Url = "https://www.ilovepdf.com/pt" }
)

# ====================== FIM DA CONFIGURACAO ==========================


