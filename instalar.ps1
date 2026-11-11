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


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Apaga do historico do PowerShell as linhas do kit, para ninguem repetir o comando
# com a seta para cima. Roda ao abrir o kit e ao sair.
function Limpar-Historico {
    $arquivos = @("$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt")
    try { $arquivos += (Get-PSReadLineOption -ErrorAction Stop).HistorySavePath } catch { }
    try {
        # usuario da tela, se o kit estiver rodando com outra conta de administrador
        $u = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName
        if ($u) {
            $sid = (New-Object Security.Principal.NTAccount($u)).Translate([Security.Principal.SecurityIdentifier]).Value
            $perfil = (Get-CimInstance Win32_UserProfile | Where-Object { $_.SID -eq $sid }).LocalPath
            if ($perfil) { $arquivos += "$perfil\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" }
        }
    } catch { }
    foreach ($a in ($arquivos | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not (Test-Path $a)) { continue }
        $linhas = @(Get-Content $a -ErrorAction SilentlyContinue)
        $ficam = @($linhas | Where-Object { $_ -notmatch 'kit-signer|kit-ti\.ps1' })
        if ($ficam.Count -ne $linhas.Count) { Set-Content -Path $a -Value $ficam -Encoding UTF8 -ErrorAction SilentlyContinue }
    }
    # memoria da janela (seta para cima): o PowerShell nao deixa tirar uma linha so, entao limpa a lista da janela
    try { [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() } catch { }
    Clear-History -ErrorAction SilentlyContinue
}
Limpar-Historico

# Rodando de um arquivo (pendrive) ou pela internet (irm | iex)?
$ArquivoDoScript = $PSCommandPath
$PastaLocal = $null
if ($ArquivoDoScript) {
    $candidata = Join-Path (Split-Path $ArquivoDoScript) "instaladores"
    if (Test-Path $candidata) { $PastaLocal = $candidata }
}

# --- Garante que esta rodando como administrador ---
$ehAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ehAdmin) {
    Write-Host "Pedindo permissao de administrador..." -ForegroundColor Yellow
    if (-not $ArquivoDoScript) {
        # Veio pelo "irm | iex": salva uma copia do script e reabre ela como administrador.
        # Reabrir com -File (e nao passando o download como -Command): o Defender bloqueia o outro jeito.
        $ArquivoDoScript = Join-Path $env:TEMP "kit-ti.ps1"
        try {
            Invoke-WebRequest -Uri $UrlScript -OutFile $ArquivoDoScript -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host "Nao consegui baixar o kit: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ArquivoDoScript`""
    } catch {
        Write-Host "Permissao de administrador negada. Abra o PowerShell como administrador e rode de novo." -ForegroundColor Red
    }
    return
}

New-Item -ItemType Directory -Path "$PastaTI\logs", "$PastaTI\instaladores" -Force | Out-Null

# Funcoes do Windows usadas pelo kit:
#   Console = desligar a "Edicao Rapida" (com ela ligada, um clique na janela congela o kit)
#   Cartao  = saber se a chave de um certificado esta no token conectado AGORA, sem pedir PIN
$CodigoKitTI = @'
using System;
using System.Runtime.InteropServices;
namespace KitTI {
    public static class Console {
        [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
        [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint modo);
        [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint modo);
    }
    public static class Cartao {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct InfoChave { public string Recipiente; public string Provedor; public uint TipoProvedor; public uint Flags; public uint QtdParam; public IntPtr Params; public uint TipoChave; }
        [DllImport("crypt32.dll", SetLastError = true)] static extern bool CertGetCertificateContextProperty(IntPtr ctx, uint id, IntPtr dados, ref uint tam);
        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool CryptAcquireContext(out IntPtr h, string recipiente, string provedor, uint tipo, uint flags);
        [DllImport("advapi32.dll")] static extern bool CryptReleaseContext(IntPtr h, uint flags);
        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode)] static extern int NCryptOpenStorageProvider(out IntPtr h, string nome, uint flags);
        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode)] static extern int NCryptOpenKey(IntPtr prov, out IntPtr chave, string nome, uint tipo, uint flags);
        [DllImport("ncrypt.dll")] static extern int NCryptFreeObject(IntPtr h);
        const uint SILENCIOSO = 0x40;   // nunca abre janela nem pede PIN
        public static bool ChavePresente(IntPtr ctx) {
            uint tam = 0;
            if (!CertGetCertificateContextProperty(ctx, 2, IntPtr.Zero, ref tam)) return false;
            IntPtr buf = Marshal.AllocHGlobal((int)tam);
            try {
                if (!CertGetCertificateContextProperty(ctx, 2, buf, ref tam)) return false;
                InfoChave i = (InfoChave)Marshal.PtrToStructure(buf, typeof(InfoChave));
                if (i.TipoProvedor == 0) {
                    IntPtr prov, chave;
                    if (NCryptOpenStorageProvider(out prov, i.Provedor, 0) != 0) return false;
                    try {
                        if (NCryptOpenKey(prov, out chave, i.Recipiente, i.TipoChave, SILENCIOSO) != 0) return false;
                        NCryptFreeObject(chave);
                        return true;
                    } finally { NCryptFreeObject(prov); }
                }
                IntPtr h;
                if (!CryptAcquireContext(out h, i.Recipiente, i.Provedor, i.TipoProvedor, SILENCIOSO)) return false;
                CryptReleaseContext(h, 0);
                return true;
            } finally { Marshal.FreeHGlobal(buf); }
        }
    }
}
'@
if (-not ('KitTI.Cartao' -as [type])) {
    try { Add-Type -TypeDefinition $CodigoKitTI -ErrorAction Stop } catch { }
}

function Desligar-EdicaoRapida {
    if (-not ('KitTI.Console' -as [type])) { return }
    $h = [KitTI.Console]::GetStdHandle(-10)
    $modo = [uint32]0
    if ([KitTI.Console]::GetConsoleMode($h, [ref]$modo)) {
        # tira ENABLE_QUICK_EDIT_MODE (0x40) e liga ENABLE_EXTENDED_FLAGS (0x80) para valer
        $novo = [uint32](([uint32]$modo -band [uint32]4294967231) -bor [uint32]128)
        [void][KitTI.Console]::SetConsoleMode($h, $novo)
    }
}
Desligar-EdicaoRapida

# A copia em %TEMP% (usada so para pedir administrador) ja foi lida inteira: pode apagar
if ($ArquivoDoScript -and (Split-Path $ArquivoDoScript -Leaf) -eq "kit-ti.ps1") {
    Remove-Item $ArquivoDoScript -Force -ErrorAction SilentlyContinue
}


# ============================ TELA ===================================

function Mostrar-Cabecalho {
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$Empresa - Kit de TI"
    Write-Host ""
    Write-Host "     ____    _        _        _      _     " -ForegroundColor DarkYellow
    Write-Host "    / ___|  / \      / \      / \    | |    " -ForegroundColor DarkYellow
    Write-Host "   | |     / _ \    / _ \    / _ \   | |    " -ForegroundColor DarkYellow
    Write-Host "   | |___ / ___ \  / ___ \  / ___ \  | |___ " -ForegroundColor DarkYellow
    Write-Host "    \____/_/   \_\/_/   \_\/_/   \_\ |_____|" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "   Kit de TI  |  Configuracao de maquina" -ForegroundColor Gray
    Write-Host "   Computador: $env:COMPUTERNAME   Usuario: $env:USERNAME" -ForegroundColor DarkGray
    Mostrar-StatusToken
    Write-Host "   -------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

# Tokens conectados agora. O tipo vem do nome que o USB informa (o Windows costuma
# chamar todos de "Usbccid Smartcard Reader") ou do codigo do fabricante no USB.
# So conta aparelho FISICO no USB: o driver do SafeNet cria leitores virtuais
# ("Aladdin VR/IFD Handler", com Id ROOT\...) que existem mesmo sem token nenhum.
# Cada token aparece uma vez so, mesmo que o Windows o divida em varias partes.
function Ler-Tokens {
    $itens = @()
    $vistos = @{}
    $vids = @($TiposToken | Where-Object { $_.Vid } | ForEach-Object { $_.Vid })
    foreach ($d in @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'USB\VID_*' })) {
        $vid = $(if ($d.InstanceId -match 'VID_([0-9A-F]{4})') { $Matches[1] } else { "" })
        $leitor = $d.Class -in "SmartCardReader", "SmartCard"
        $porNome = [bool]($TiposToken | Where-Object { "$($d.FriendlyName) $($d.Manufacturer)" -match $_.Padrao })
        if (-not ($leitor -or $porNome -or ($vids -contains $vid))) { continue }
        # mesmo aparelho = mesmo fabricante/modelo (VID/PID), sem o pedaco "&MI_xx" de cada parte
        $chave = (($d.InstanceId -split '\\')[1] -replace '&MI_[0-9A-F]{2}', '')
        if ($vistos.ContainsKey($chave)) { continue }
        $vistos[$chave] = $true
        $usb = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_BusReportedDeviceDesc' -ErrorAction SilentlyContinue).Data
        $itens += Classificar-Token $usb $d.FriendlyName $d.Manufacturer $vid
    }
    return $itens
}

function Classificar-Token($usb, $nomeWindows, $fabricante, $vid = "") {
    $texto = "$usb $nomeWindows $fabricante"
    $tipo = $TiposToken | Where-Object { $texto -match $_.Padrao } | Select-Object -First 1
    if (-not $tipo -and $vid) { $tipo = $TiposToken | Where-Object { $_.Vid -eq $vid } | Select-Object -First 1 }
    return [pscustomobject]@{
        Nome       = (@($usb, $nomeWindows) | Where-Object { $_ } | Select-Object -First 1)
        Tipo       = $(if ($tipo) { $tipo.Tipo } else { $null })
        Driver     = $(if ($tipo) { $tipo.Driver } else { $null })
        DriverNome = $(if ($tipo) { $tipo.DriverNome } else { $null })
    }
}

# Linha do token no cabecalho. Guarda a leitura por 10 s para as telas nao ficarem lentas.
function Mostrar-StatusToken {
    if (-not $script:CacheToken -or ((Get-Date) - $script:CacheToken.Hora).TotalSeconds -gt 10) {
        $script:CacheToken = @{ Hora = Get-Date; Tokens = @(Ler-Tokens) }
    }
    $tokens = $script:CacheToken.Tokens
    if ($tokens.Count -eq 0) {
        Write-Host "   Token: nenhum conectado" -ForegroundColor DarkGray
        return
    }
    foreach ($t in $tokens) {
        if (-not $t.Tipo) { Write-Host "   Leitor/token conectado: $($t.Nome)" -ForegroundColor Gray; continue }
        Write-Host "   Token: $($t.Tipo) conectado " -ForegroundColor Gray -NoNewline
        if (-not $t.Driver) { Write-Host "(driver nao vem no kit)" -ForegroundColor Yellow }
        elseif (Test-Instalado $t.Driver) { Write-Host "(driver $($t.DriverNome) instalado)" -ForegroundColor Green }
        else { Write-Host "(FALTA o driver $($t.DriverNome): use Instalar programas)" -ForegroundColor Red }
    }
    if ($null -eq $script:CacheToken.Certificados) { $script:CacheToken.Certificados = @(Certificados-NoToken) }
    foreach ($cert in $script:CacheToken.Certificados) {
        $nome = ($cert.GetNameInfo("SimpleName", $false) -split ':')[0]
        $vence = $cert.NotAfter.ToString('dd/MM/yyyy')
        if ($cert.NotAfter -lt (Get-Date)) { Write-Host "   Certificado: $nome - VENCIDO em $vence" -ForegroundColor Red }
        else { Write-Host "   Certificado: $nome - vale ate $vence" -ForegroundColor Gray }
    }
}

# Certificados ICP-Brasil cuja chave esta no token conectado AGORA.
# O Windows guarda os certificados de todo token que ja foi usado na maquina; aqui so
# entram os que tem a chave presente (perguntado em modo silencioso: sem janela, sem PIN).
function Certificados-NoToken {
    $todos = @(Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue |
        Where-Object { $_.Issuer -match "ICP-Brasil" -and $_.HasPrivateKey })
    if (-not ('KitTI.Cartao' -as [type])) { return @() }
    return @($todos | Where-Object { try { [KitTI.Cartao]::ChavePresente($_.Handle) } catch { $false } } | Sort-Object NotAfter -Descending)
}

function Ler-Opcao($validas) {
    while ($true) {
        $op = (Read-Host "   Escolha uma opcao").Trim().ToUpper()
        if ($validas -contains $op) { return $op }
        Write-Host "   Opcao invalida. Digite: $($validas -join ', ')" -ForegroundColor Yellow
    }
}

function Pausar {
    Write-Host ""
    Read-Host "   Pressione Enter para voltar ao menu" | Out-Null
}

function Titulo($texto) {
    Write-Host ""
    Write-Host "=== $texto ===" -ForegroundColor Cyan
}


# ========================== AUXILIARES ===============================

function Test-Instalado($busca) {
    $chaves = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $achados = Get-ItemProperty $chaves -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$busca*" }
    return [bool]$achados
}

function Hash-Confere($caminho, $esperado) {
    if (-not (Test-Path $caminho)) { return $false }
    return ((Get-FileHash $caminho -Algorithm SHA256).Hash -eq $esperado.ToUpper())
}

# Devolve o caminho de um arquivo do kit ja conferido, ou $null.
# Usa o pendrive se tiver; senao baixa do Release do GitHub.
function Obter-Arquivo($arquivo, $sha256) {
    if ($PastaLocal) {
        $local = Join-Path $PastaLocal $arquivo
        if (Hash-Confere $local $sha256) { return $local }
        Write-Host "  $arquivo no pendrive esta diferente do esperado. Vou baixar." -ForegroundColor Yellow
    }
    $destino = Join-Path "$PastaTI\instaladores" $arquivo
    if (Hash-Confere $destino $sha256) { return $destino }
    if (Aguardar-DownloadEmSegundoPlano $arquivo) {
        if (Hash-Confere $destino $sha256) { return $destino }
        Write-Host "  O download em segundo plano de $arquivo falhou. Baixando de novo..." -ForegroundColor Yellow
    }

    Write-Host "  Baixando $arquivo..."
    $url = "$UrlArquivos/$arquivo"
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --fail --retry 5 --retry-delay 3 -# -o $destino $url
    } else {
        try { Invoke-WebRequest -Uri $url -OutFile $destino -UseBasicParsing } catch { }
    }
    if (Hash-Confere $destino $sha256) { return $destino }

    Write-Host "  [BLOQUEADO] $arquivo baixado nao confere com a impressao digital (SHA256)." -ForegroundColor Red
    Write-Host "  Pode ser download incompleto ou arquivo trocado. Nao vou instalar." -ForegroundColor Red
    Remove-Item $destino -Force -ErrorAction SilentlyContinue
    return $null
}

# Roda um instalador e espera SO ele terminar.
# Nao usar "Start-Process -Wait": no PowerShell 5.1 ele espera tambem tudo que o
# instalador abrir. O PJeOffice abre sozinho no fim da instalacao e fica em segundo
# plano, e o -Wait travava a instalacao ate alguem fechar o PJeOffice.
# Devolve o codigo de saida, ou $null se passar do tempo limite.
$MinutosLimite = 20
function Executar-Instalador($arquivo, $argumentos) {
    if ($arquivo -like "*.msi") {
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$arquivo`" $argumentos" -PassThru
    } elseif ($argumentos) {
        $proc = Start-Process $arquivo -ArgumentList $argumentos -PassThru
    } else {
        $proc = Start-Process $arquivo -PassThru
    }
    $null = $proc.Handle   # sem isso o PowerShell 5.1 as vezes perde o codigo de saida
    if (-not $proc.WaitForExit($MinutosLimite * 60 * 1000)) { return $null }
    return $proc.ExitCode
}

function Add-ListaForcada($chave, $valor) {
    if (-not (Test-Path $chave)) { New-Item -Path $chave -Force | Out-Null }
    $props = (Get-ItemProperty -Path $chave).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
    if ($props -and ($props.Value -contains $valor)) { return }
    $n = 1
    while ($props -and ($props.Name -contains "$n")) { $n++ }
    New-ItemProperty -Path $chave -Name "$n" -Value $valor -PropertyType String -Force | Out-Null
}

function Pasta-Firefox {
    # tambem a instalacao "so do usuario" (AppData\Local), que o winget as vezes escolhe
    $perfil = Perfil-UsuarioTela
    return @("C:\Program Files\Mozilla Firefox", "C:\Program Files (x86)\Mozilla Firefox", "$perfil\AppData\Local\Mozilla Firefox") |
        Where-Object { Test-Path "$_\firefox.exe" } | Select-Object -First 1
}

# Garante que o Firefox ja tenha pasta de perfil criada, mesmo se acabou de ser instalado
# e nunca foi aberto na maquina (evita ter que abrir a tela de introducao e rodar o kit 2 vezes).
function Garantir-PerfilFirefox($perfil) {
    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) { return @() }
    $baseFx = "$perfil\AppData\Roaming\Mozilla\Firefox"
    $perfisFx = @(Get-ChildItem "$baseFx\Profiles" -Directory -ErrorAction SilentlyContinue)
    if ($perfisFx.Count -eq 0 -and $perfil -eq $env:USERPROFILE) {
        try {
            $proc = Start-Process "$pastaFirefox\firefox.exe" -ArgumentList "-headless" -WindowStyle Hidden -PassThru -ErrorAction Stop
            for ($i = 0; $i -lt 16; $i++) {
                Start-Sleep -Milliseconds 500
                $perfisFx = @(Get-ChildItem "$baseFx\Profiles" -Directory -ErrorAction SilentlyContinue)
                if ($perfisFx.Count -gt 0) { break }
            }
            if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
            Fechar-Navegadores
        } catch { }
    }
    $perfisFx = @(Get-ChildItem "$baseFx\Profiles" -Directory -ErrorAction SilentlyContinue)
    if ($perfisFx.Count -eq 0) {
        $novoPerfil = "$baseFx\Profiles\padrao.default-release"
        New-Item -ItemType Directory -Path $novoPerfil -Force | Out-Null
        $utf8SemBom = New-Object Text.UTF8Encoding($false)
        $installsIni = "[308046B0AF4A39CB]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n`r`n[E7CF176E110C211B]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n"
        $profilesIni = "[Install308046B0AF4A39CB]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n`r`n[InstallE7CF176E110C211B]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n`r`n[Profile0]`r`nName=default-release`r`nIsRelative=1`r`nPath=Profiles/padrao.default-release`r`nDefault=1`r`n`r`n[General]`r`nStartWithLastProfile=1`r`nVersion=2`r`n"
        [IO.File]::WriteAllText("$baseFx\installs.ini", $installsIni, $utf8SemBom)
        [IO.File]::WriteAllText("$baseFx\profiles.ini", $profilesIni, $utf8SemBom)
        $perfisFx = @(Get-Item $novoPerfil)
    }
    return $perfisFx
}

# Ativa automaticamente os toggles internos da extensao Web Signer:
#   - Cripto Dispositivos (PKCS #11): Tokens SafeNet, Dispositivos SafeSign AET, Smartcards Athena IDProtect
#   - Avancadas: Habilitar logs detalhados (trace = true)
function Configurar-TogglesWebSigner {
    $perfil = Perfil-UsuarioTela
    Fechar-Navegadores

    # LevelDB (MANIFEST-000001 + 000003.log) com:
    #   pkcs11 = ["eTPKCS11.dll","aetpkss1.dll","asepkcs.dll"]
    #   trace  = true
    $manifestB64 = "lXy5xSIAAQEabGV2ZWxkYi5CeXRld2lzZUNvbXBhcmF0b3ICAAMCBAA="
    $logWinB64   = "O4Mwm04AAQEAAAAAAAAAAgAAAAEGcGtjczExLVsiZVRQS0NTMTEuZGxsIiwiYWV0cGtzczEuZGxsIiwiYXNlcGtjcy5kbGwiXQEFdHJhY2UEdHJ1ZQ=="

    $perfis = @(Pastas-PerfisChromium $perfil)
    # Navegador recem-instalado ainda nao tem perfil (so cria ao abrir pela primeira vez).
    # Cria o perfil "Default" para os toggles ja estarem la quando ele abrir.
    $navegadores = @(
        @{ Base = "$perfil\AppData\Local\Google\Chrome\User Data"; Exe = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$perfil\AppData\Local\Google\Chrome\Application\chrome.exe" },
        @{ Base = "$perfil\AppData\Local\Microsoft\Edge\User Data"; Exe = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" }
    )
    foreach ($n in $navegadores) {
        $instalado = [bool]($n.Exe | Where-Object { Test-Path $_ })
        if (($instalado -or (Test-Path $n.Base)) -and ($perfis -notcontains "$($n.Base)\Default")) { $perfis += "$($n.Base)\Default" }
    }

    foreach ($p in ($perfis | Select-Object -Unique)) {
        $dirDb = Join-Path $p "Local Extension Settings\$WebSignerChromeId"
        $jaConfigurado = Get-ChildItem $dirDb -Include *.log, *.ldb -File -ErrorAction SilentlyContinue |
            Where-Object {
                $txt = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($_.FullName))
                $txt -match 'eTPKCS11\.dll' -and $txt -match 'aetpkss1\.dll' -and $txt -match 'asepkcs\.dll' -and $txt -match 'trace'
            }
        if ($jaConfigurado) { continue }

        New-Item -ItemType Directory -Path $dirDb -Force | Out-Null
        Remove-Item "$dirDb\*" -Force -ErrorAction SilentlyContinue
        [IO.File]::WriteAllBytes("$dirDb\MANIFEST-000001", [Convert]::FromBase64String($manifestB64))
        [IO.File]::WriteAllBytes("$dirDb\CURRENT", [Text.Encoding]::ASCII.GetBytes("MANIFEST-000001`n"))
        [IO.File]::WriteAllBytes("$dirDb\000003.log", [Convert]::FromBase64String($logWinB64))
    }

    # Firefox: grava storage.js e habilita keepStorageOnUninstall no user.js/prefs.js e policies.json.
    # Sem keepStorageOnUninstall=true, no primeiro ADDON_INSTALL o Firefox marca a extensao
    # como ja migrada antes de abrir o storage.js (Extension.sys.mjs) e ignora o arquivo.
    $jsonFx = '{"pkcs11":["eTPKCS11.dll","aetpkss1.dll","asepkcs.dll"],"trace":true}'
    $pastaFirefox = Pasta-Firefox
    $perfisFx = @(Garantir-PerfilFirefox $perfil)
    $prefsExtrasFx = @(
        'user_pref("extensions.webextensions.keepStorageOnUninstall", true);',
        'user_pref("browser.aboutwelcome.enabled", false);',
        'user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);',
        'user_pref("termsofuse.acceptedVersion", 999);',
        'user_pref("termsofuse.acceptedDate", "1740000000000");'
    )
    $regexLimparFx = 'ExtensionStorageIDB\.migrated\.websigner@softplan_com_br|extensions\.webextensions\.keepStorageOnUninstall|browser\.aboutwelcome\.enabled|datareporting\.policy\.dataSubmissionPolicyBypassNotification|termsofuse\.accepted'

    foreach ($d in $perfisFx) {
        $dirExt = Join-Path $d.FullName "browser-extension-data\$WebSignerFirefoxId"
        $arqXpiPerfil = Join-Path $d.FullName "extensions\$WebSignerFirefoxId.xpi"
        $jaMigrado = [bool](Get-ChildItem $dirExt -Filter "storage.js*.migrated" -File -ErrorAction SilentlyContinue)
        if ($jaMigrado -and (Test-Path $arqXpiPerfil)) { continue }

        $prefs = Join-Path $d.FullName "prefs.js"
        if (Test-Path $prefs) {
            $textoPrefs = Get-Content $prefs -Raw
            if ($textoPrefs -match '"websigner@softplan_com_br"\s*:\s*\\?"([0-9a-fA-F-]+)\\?"') {
                $uuidFx = $matches[1]
                Get-ChildItem "$($d.FullName)\storage\default" -Filter "moz-extension+++$uuidFx*" -Directory -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            $linhasPrefs = @(Get-Content $prefs | Where-Object { $_ -notmatch $regexLimparFx })
            $linhasPrefs += $prefsExtrasFx
            [IO.File]::WriteAllLines($prefs, ($linhasPrefs -as [string[]]))
        }
        $userJs = Join-Path $d.FullName "user.js"
        $linhasUser = @()
        if (Test-Path $userJs) {
            $linhasUser = @(Get-Content $userJs | Where-Object { $_ -notmatch $regexLimparFx })
        }
        $linhasUser += $prefsExtrasFx
        [IO.File]::WriteAllLines($userJs, ($linhasUser -as [string[]]))
        New-Item -ItemType Directory -Path $dirExt -Force | Out-Null
        Remove-Item "$dirExt\storage.js*" -Force -ErrorAction SilentlyContinue
        [IO.File]::WriteAllText("$dirExt\storage.js", $jsonFx)

        # Inicializa o Firefox em modo invisivel (-headless) para ja instalar o websigner.xpi
        # e migrar o storage.js na primeira instalacao, sem precisar abrir a tela de introducao.
        if ($pastaFirefox -and (Test-Path "$PastaTI\websigner.xpi")) {
            try {
                $procFx = Start-Process "$pastaFirefox\firefox.exe" -ArgumentList "-headless -no-remote -profile `"$($d.FullName)`"" -WindowStyle Hidden -PassThru -ErrorAction Stop
                for ($i = 0; $i -lt 24; $i++) {
                    Start-Sleep -Milliseconds 500
                    $temXpi = Test-Path $arqXpiPerfil
                    $temMig = [bool](Get-ChildItem $dirExt -Filter "storage.js*.migrated" -File -ErrorAction SilentlyContinue)
                    if ($temXpi -and $temMig) { break }
                }
                if (-not $procFx.HasExited) { Stop-Process -Id $procFx.Id -Force -ErrorAction SilentlyContinue }
                Start-Sleep -Milliseconds 500
                Remove-Item "$($d.FullName)\parent.lock" -Force -ErrorAction SilentlyContinue
            } catch { }
        }
    }

    Write-Host "Web Signer: toggles (SafeNet, SafeSign, Athena e logs detalhados) ativados."
}

function Aplicar-ExtensaoWebSigner {
    $valorLoja = "$WebSignerChromeId;$ChromeStoreUpdate"
    # se a extensao tinha sido excluida antes (modo "removed"), tira essa regra
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Google\Chrome" $null
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Microsoft\Edge" $null
    Add-ListaForcada "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" $valorLoja
    Write-Host "Chrome: extensao forcada."
    Add-ListaForcada "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" $valorLoja
    Write-Host "Edge: extensao forcada."

    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) {
        Write-Host "Firefox nao encontrado; politica nao aplicada." -ForegroundColor Yellow
    } else {
        $xpi = Obter-Arquivo $WebSignerXpi.Arquivo $WebSignerXpi.Sha256
        if ($xpi) {
            Copy-Item $xpi "$PastaTI\websigner.xpi" -Force
            [void](Gravar-PoliticaFirefox $true $null)
            Write-Host "Firefox: extensao forcada."
        }
    }
    Configurar-TogglesWebSigner
}

# Escreve o policies.json do Firefox com as partes do kit:
#   extensao     = Web Signer forcada
#   certificados = usar os certificados do Windows + carregar os modulos dos tokens
#   favoritos    = sites dos tribunais na barra de favoritos
# Cada parametro: $true (liga), $false (desliga) ou $null (mantem como esta).
# A extensao aceita tambem "bloqueada": o Firefox remove a extensao e nao deixa reinstalar
# (usado ao desinstalar o Web Signer; instalar de novo pelo kit volta para forcada).
# Assim uma parte nao apaga a outra. Devolve $false se nao houver Firefox.
function Gravar-PoliticaFirefox($extensao, $certificados, $favoritos = $null) {
    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) { return $false }
    $dist = Join-Path $pastaFirefox "distribution"
    $arqPol = Join-Path $dist "policies.json"
    $atual = $(if (Test-Path $arqPol) { Get-Content $arqPol -Raw } else { "" })
    if ($null -eq $extensao) {
        if ($atual -like "*$WebSignerFirefoxId*" -and $atual -like "*force_installed*") { $extensao = $true }
        elseif ($atual -like "*$WebSignerFirefoxId*" -and $atual -like "*blocked*") { $extensao = "bloqueada" }
        else { $extensao = $false }
    }
    if ($null -eq $certificados) { $certificados = $atual -like "*ImportEnterpriseRoots*" }
    if ($null -eq $favoritos) { $favoritos = $atual -like '*"Bookmarks"*' }

    $pol = @{}
    # cuidado: no PowerShell "$true -eq 'texto'" da verdadeiro, por isso confere o tipo
    if ($extensao -is [string] -and $extensao -eq "bloqueada") {
        $pol.ExtensionSettings = @{ $WebSignerFirefoxId = @{ installation_mode = "blocked" } }
    } elseif ($extensao -is [bool] -and $extensao) {
        $urlXpi = "file:///" + ("$PastaTI\websigner.xpi" -replace '\\', '/')
        $pol.ExtensionSettings = @{ $WebSignerFirefoxId = @{ installation_mode = "force_installed"; install_url = $urlXpi } }
        $pol.Preferences = @{
            "extensions.webextensions.keepStorageOnUninstall" = @{ Value = $true; Status = "default" }
            "browser.aboutwelcome.enabled" = @{ Value = $false; Status = "default" }
            "datareporting.policy.dataSubmissionPolicyBypassNotification" = @{ Value = $true; Status = "default" }
        }
    }
    if ($certificados) {
        $pol.Certificates = @{ ImportEnterpriseRoots = $true }
        $modulos = @{}
        foreach ($nome in $ModulosToken.Keys) { if (Test-Path $ModulosToken[$nome]) { $modulos[$nome] = $ModulosToken[$nome] } }
        if ($modulos.Count) { $pol.SecurityDevices = @{ Add = $modulos } }
    }
    if ($favoritos) {
        $pol.DisplayBookmarksToolbar = "always"
        $pol.Bookmarks = @($Favoritos | ForEach-Object {
            @{ Title = $_.Nome; URL = $_.Url; Placement = "toolbar" }
        })
    }
    if ($pol.Count -eq 0) {
        Remove-Item $arqPol -Force -ErrorAction SilentlyContinue
        return $true
    }
    # Pula a tela de introducao e o aviso de termos de uso na primeira abertura do Firefox
    $pol.SkipTermsOfUse = $true
    $pol.OverrideFirstRunPage = ""
    $pol.OverridePostUpdatePage = ""
    $pol.DontCheckDefaultBrowser = $true
    $pol.UserMessaging = @{
        WhatsNew = $false
        ExtensionRecommendations = $false
        FeatureRecommendations = $false
        UrlbarInterventions = $false
        SkipOnboarding = $true
        MoreFromMozilla = $false
    }
    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    # guarda o arquivo original (de antes do kit) uma vez so
    if ((Test-Path $arqPol) -and -not (Test-Path "$arqPol.bak")) { Copy-Item $arqPol "$arqPol.bak" -Force }
    # UTF-8 sem BOM (o Firefox exige)
    $utf8SemBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($arqPol, (@{ policies = $pol } | ConvertTo-Json -Depth 10), $utf8SemBom)
    return $true
}

function Adicionar-AoRepositorio($nome, $certs) {
    $repo = New-Object Security.Cryptography.X509Certificates.X509Store($nome, "LocalMachine")
    $repo.Open("ReadWrite")
    $existentes = @($repo.Certificates | ForEach-Object { $_.Thumbprint })
    $novos = 0
    foreach ($c in $certs) {
        if ($existentes -notcontains $c.Thumbprint) { $repo.Add($c); $novos++ }
    }
    $repo.Close()
    return $novos
}

# Baixa o pacote oficial do ITI e instala no Windows:
#   - so as raizes listadas em $RaizesIcp (pela impressao digital)
#   - as autoridades intermediarias cuja cadeia termina numa dessas raizes
# Devolve $true se instalou.
function Instalar-CadeiaIcp {
    $zip = Join-Path $PastaTI "icp-brasil.zip"
    $pasta = Join-Path $PastaTI "icp-brasil"
    Write-Host "  Baixando a cadeia oficial do ITI..."
    try {
        Invoke-WebRequest -Uri $UrlCadeiaIcp -OutFile $zip -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  Nao consegui baixar a cadeia do ITI: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    Remove-Item $pasta -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip $pasta -Force
    $certs = @()
    foreach ($a in (Get-ChildItem $pasta -Recurse -File -Include *.crt, *.cer, *.der)) {
        try { $certs += New-Object Security.Cryptography.X509Certificates.X509Certificate2 $a.FullName } catch { }
    }
    $raizes = @($certs | Where-Object { $_.Subject -eq $_.Issuer -and $RaizesIcp.Contains($_.Thumbprint) })
    foreach ($t in $RaizesIcp.Keys) {
        if (@($raizes | ForEach-Object { $_.Thumbprint }) -notcontains $t) {
            Write-Host "  [AVISO] $($RaizesIcp[$t]) nao veio no pacote do ITI." -ForegroundColor Yellow
        }
    }
    $intermediarias = @()
    foreach ($c in ($certs | Where-Object { $_.Subject -ne $_.Issuer -and $_.NotAfter -gt (Get-Date) })) {
        try {
            $cadeia = New-Object Security.Cryptography.X509Certificates.X509Chain
            $cadeia.ChainPolicy.RevocationMode = "NoCheck"
            $cadeia.ChainPolicy.VerificationFlags = "AllowUnknownCertificateAuthority"
            foreach ($x in $certs) { [void]$cadeia.ChainPolicy.ExtraStore.Add($x) }
            [void]$cadeia.Build($c)
            $topo = $cadeia.ChainElements[$cadeia.ChainElements.Count - 1].Certificate
            if ($topo.Subject -eq $topo.Issuer -and $RaizesIcp.Contains($topo.Thumbprint)) { $intermediarias += $c }
        } catch { }   # alguns certificados usam algoritmos que o Windows nao le: ficam de fora
    }
    $novasRaizes = Adicionar-AoRepositorio "Root" $raizes
    $novasInter = Adicionar-AoRepositorio "CA" $intermediarias
    Remove-Item $zip, $pasta -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ("  Cadeia ICP-Brasil: {0} raizes e {1} autoridades intermediarias ({2} novas nesta maquina)." -f $raizes.Count, $intermediarias.Count, ($novasRaizes + $novasInter)) -ForegroundColor Green
    return $true
}

function Cadeia-IcpInstalada {
    $raizes = @(Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object { $_.Thumbprint })
    return -not ($RaizesIcp.Keys | Where-Object { $raizes -notcontains $_ })
}

function Corrigir-CertificadoDigital {
    Titulo "1/4 Certificado do token"
    $meus = @(Certificados-NoToken)
    if ($meus.Count -eq 0) {
        Write-Host "  Nenhum certificado do token conectado apareceu no Windows." -ForegroundColor Red
        Write-Host "  Confira se o token esta conectado e se o driver esta instalado ('Token nao reconhecido')." -ForegroundColor Red
        Write-Host "  (Se o kit foi aberto com outra conta de administrador, o certificado do usuario nao aparece aqui.)" -ForegroundColor DarkGray
    }
    foreach ($c in $meus) {
        $nome = $c.GetNameInfo("SimpleName", $false)
        $emissor = $c.GetNameInfo("SimpleName", $true)
        $dias = [int]($c.NotAfter - (Get-Date)).TotalDays
        if ($dias -lt 0) { Write-Host "  [VENCIDO] $nome ($emissor) venceu em $($c.NotAfter.ToString('dd/MM/yyyy')). Precisa renovar." -ForegroundColor Red }
        elseif ($dias -le 30) { Write-Host "  [VENCE LOGO] $nome ($emissor) vence em $dias dias ($($c.NotAfter.ToString('dd/MM/yyyy')))." -ForegroundColor Yellow }
        else { Write-Host "  [OK] $nome ($emissor), vale ate $($c.NotAfter.ToString('dd/MM/yyyy'))" -ForegroundColor Green }
    }

    Titulo "2/4 Cadeia de certificados ICP-Brasil"
    [void](Instalar-CadeiaIcp)

    Titulo "3/4 Firefox"
    if (Gravar-PoliticaFirefox $null $true) {
        Write-Host "  Firefox passa a usar os certificados do Windows e o modulo do token." -ForegroundColor Green
    } else {
        Write-Host "  Firefox nao instalado; nada a fazer." -ForegroundColor DarkGray
    }

    Titulo "4/4 Fechando os navegadores"
    Fechar-Navegadores
    Write-Host "  Os navegadores guardam a escolha de certificado ate serem fechados por completo." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Agora:" -ForegroundColor Cyan
    Write-Host "   1. Conecte o token ANTES de abrir o navegador."
    Write-Host "   2. Abra o site do tribunal de novo."
    Write-Host "   3. Quando aparecer a janela, escolha o certificado do advogado e digite o PIN."
    Write-Host "   Se cancelar a janela sem querer, feche o navegador inteiro e tente de novo."
}


# ======================= DESINSTALACAO ===============================

$ChavesDesinstalacao = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Programas do kit que podem ser desinstalados (tudo, menos os de $NaoDesinstalar)
function Programas-Desinstalaveis {
    return @(($InstaladoresKit + $ProgramasWinget) | Where-Object { $NaoDesinstalar -notcontains $_.Nome })
}

function Entradas-Desinstalacao($busca) {
    return @(Get-ItemProperty $ChavesDesinstalacao -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$busca*" -and ($_.UninstallString -or $_.QuietUninstallString) })
}

# Roda um comando e espera SO ele terminar (mesmo motivo do Executar-Instalador)
function Executar-Comando($exe, $argumentos) {
    if ($argumentos) { $proc = Start-Process $exe -ArgumentList $argumentos -PassThru }
    else { $proc = Start-Process $exe -PassThru }
    $null = $proc.Handle
    if (-not $proc.WaitForExit($MinutosLimite * 60 * 1000)) { return $null }
    return $proc.ExitCode
}

# Separa "C:\caminho\programa.exe" /parametros  em  executavel + parametros
function Separar-Comando($linha) {
    $linha = $linha.Trim()
    if ($linha.StartsWith('"')) {
        $fim = $linha.IndexOf('"', 1)
        return @($linha.Substring(1, $fim - 1), $linha.Substring($fim + 1).Trim())
    }
    $i = $linha.ToLower().IndexOf(".exe")
    if ($i -lt 0) { return @($linha, "") }
    return @($linha.Substring(0, $i + 4), $linha.Substring($i + 4).Trim())
}

# Desinstala sem janelas. Devolve $true se o programa saiu.
function Desinstalar-Programa($p) {
    $entradas = Entradas-Desinstalacao $p.Busca
    if ($entradas.Count -eq 0) { Write-Host "  [nao instalado] $($p.Nome)" -ForegroundColor DarkGray; return $true }

    # fecha o programa se estiver aberto (o PJeOffice fica rodando em segundo plano)
    foreach ($e in $entradas) {
        if ($e.InstallLocation) {
            $pasta = $e.InstallLocation.Trim('"').TrimEnd('\')
            Get-Process | Where-Object { $_.Path -and $_.Path -like "$pasta\*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    Get-Process | Where-Object { $_.Name -like "*$($p.Busca -replace ' ', '')*" } | Stop-Process -Force -ErrorAction SilentlyContinue

    foreach ($e in $entradas) {
        Write-Host "  Removendo $($e.DisplayName)..."
        $guid = $e.PSChildName
        if ($e.WindowsInstaller -eq 1 -and $guid -match '^\{[0-9A-Fa-f-]+\}$') {
            $codigo = Executar-Comando "msiexec.exe" "/x $guid /qn /norestart"
        } else {
            $linha = $(if ($e.QuietUninstallString) { $e.QuietUninstallString } else { $e.UninstallString })
            $exe, $param = Separar-Comando $linha
            if (-not $e.QuietUninstallString) {
                # sem modo silencioso registrado: acrescenta o do tipo de instalador
                if ($exe -match 'unins\d+\.exe$') { $param = "$param /VERYSILENT /SUPPRESSMSGBOXES /NORESTART".Trim() }
                elseif ($exe -match 'msiexec') { $param = ($param -replace '/I', '/X') + " /qn /norestart" }
                else { $param = "$param /S".Trim() }
            } elseif ($exe -match 'unins\d+\.exe$' -and $param -notmatch 'VERYSILENT') {
                $param = "$param /VERYSILENT /SUPPRESSMSGBOXES /NORESTART".Trim()
            }
            $codigo = Executar-Comando $exe $param
        }
        if ($null -eq $codigo) { Write-Host "  O desinstalador passou de $MinutosLimite minutos sem terminar." -ForegroundColor Yellow }
        elseif ($codigo -eq 3010) { Write-Host "  Removido. O Windows pede para reiniciar." -ForegroundColor Yellow; $script:PedeReinicio = $true }
        elseif ($codigo -notin 0, 1605) { Write-Host "  Codigo de saida $codigo." -ForegroundColor Yellow }
    }

    # Web Signer: tira tambem a extensao forcada nos navegadores
    if ($p.Nome -eq "Web Signer") { Remover-ExtensaoWebSigner }
    return -not (Test-Instalado $p.Busca)
}

# Tira so a entrada do Web Signer da lista de extensoes forcadas (as outras ficam)
function Remover-ListaForcada($chave, $prefixo) {
    if (-not (Test-Path $chave)) { return }
    $props = (Get-ItemProperty $chave).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
    foreach ($pr in $props) { if ($pr.Value -like "$prefixo*") { Remove-ItemProperty -Path $chave -Name $pr.Name -Force } }
    $restam = (Get-ItemProperty $chave).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
    if (-not $restam) { Remove-Item $chave -Force }
}

# Politica "ExtensionSettings" do Chrome/Edge (texto JSON no registro), so a parte do Web Signer.
#   $modo = "removed": o navegador exclui a extensao e nao deixa instalar de novo
#   $modo = $null:     tira a regra do Web Signer (o resto da politica fica como estava)
function Definir-ModoExtensaoChromium($base, $modo) {
    if (-not (Test-Path $base)) {
        if (-not $modo) { return }
        New-Item -Path $base -Force | Out-Null
    }
    $atual = (Get-ItemProperty $base -Name ExtensionSettings -ErrorAction SilentlyContinue).ExtensionSettings
    $regras = @{}
    if ($atual) {
        try { foreach ($pr in ($atual | ConvertFrom-Json).PSObject.Properties) { $regras[$pr.Name] = $pr.Value } } catch { }
    }
    if ($modo) { $regras[$WebSignerChromeId] = @{ installation_mode = $modo } }
    else { $regras.Remove($WebSignerChromeId) }
    if ($regras.Count) {
        Set-ItemProperty -Path $base -Name ExtensionSettings -Value ($regras | ConvertTo-Json -Depth 5 -Compress) -Type String
    } else {
        Remove-ItemProperty -Path $base -Name ExtensionSettings -ErrorAction SilentlyContinue
    }
}

# Tira so a trava do Web Signer: a extensao continua no navegador e o usuario pode remover
function Liberar-ExtensaoWebSigner {
    Remover-ListaForcada "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" $WebSignerChromeId
    Remover-ListaForcada "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" $WebSignerChromeId
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Google\Chrome" $null
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Microsoft\Edge" $null
    [void](Gravar-PoliticaFirefox $false $null)
}

# Exclui a extensao Web Signer dos navegadores (usado ao desinstalar o Web Signer)
function Remover-ExtensaoWebSigner {
    Remover-ListaForcada "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" $WebSignerChromeId
    Remover-ListaForcada "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" $WebSignerChromeId
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Google\Chrome" "removed"
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "removed"
    [void](Gravar-PoliticaFirefox "bloqueada" $null)
    Remove-Item "$PastaTI\websigner.xpi" -Force -ErrorAction SilentlyContinue
    $perfil = Perfil-UsuarioTela
    foreach ($d in (Get-ChildItem "$perfil\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue)) {
        Remove-Item "$($d.FullName)\browser-extension-data\$WebSignerFirefoxId" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  Extensao Web Signer excluida do Chrome, Edge e Firefox (some ao abrir o navegador)."
}

function Menu-Desinstalar {
    while ($true) {
        Mostrar-Cabecalho
        Write-Host "   DESINSTALAR PROGRAMAS" -ForegroundColor Cyan
        Write-Host "   So os programas do kit. Navegadores e WinRAR nao sao removidos." -ForegroundColor DarkGray
        Write-Host ""
        $lista = Programas-Desinstalaveis
        $instalados = @()
        for ($i = 0; $i -lt $lista.Count; $i++) {
            $ok = Test-Instalado $lista[$i].Busca
            if ($ok) { $instalados += $lista[$i] }
            $estado = $(if ($ok) { "instalado" } else { "nao instalado" })
            Write-Host ("   [{0}] {1,-22} " -f ($i + 1), $lista[$i].Nome) -NoNewline
            Write-Host "($estado)" -ForegroundColor $(if ($ok) { "Green" } else { "DarkGray" })
        }
        Write-Host "   [T] Todos os que estao instalados"
        Write-Host "   [0] Voltar"
        Write-Host ""
        $op = Ler-Opcao (@("0", "T") + (1..$lista.Count | ForEach-Object { "$_" }))
        if ($op -eq "0") { return }
        $alvo = $(if ($op -eq "T") { $instalados } else { @($lista[[int]$op - 1]) })
        if ($alvo.Count -eq 0) { Write-Host "  Nenhum programa do kit instalado." -ForegroundColor DarkGray; Pausar; continue }

        Write-Host ""
        Write-Host "   Removendo: $(($alvo | ForEach-Object { $_.Nome }) -join ', ')" -ForegroundColor Yellow

        $log = "$PastaTI\logs\desinstalar-$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        Start-Transcript -Path $log | Out-Null
        $script:PedeReinicio = $false
        $resultado = @()
        foreach ($p in $alvo) {
            Titulo $p.Nome
            $saiu = Desinstalar-Programa $p
            $resultado += [pscustomobject]@{ Item = $p.Nome; OK = $saiu }
        }
        Write-Host ""
        foreach ($r in $resultado) {
            if ($r.OK) { Write-Host ("  [OK]     {0,-22} removido" -f $r.Item) -ForegroundColor Green }
            else       { Write-Host ("  [FALHOU] {0,-22} ainda instalado" -f $r.Item) -ForegroundColor Red }
        }
        if ($script:PedeReinicio) { Write-Host "  Reinicie o computador para terminar a remocao." -ForegroundColor Yellow }
        Write-Host "Log salvo em: $log"
        Stop-Transcript | Out-Null
        Pausar
    }
}


# ======================= 1. INSTALACAO ===============================

function Instalar-Windows {
    $log = "$PastaTI\logs\setup-$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
    Start-Transcript -Path $log | Out-Null
    $resultado = New-Object System.Collections.ArrayList

    # Comeca a baixar os instaladores do kit em segundo plano: quando chegar a vez
    # deles, o arquivo ja esta pronto. (Instalar tem que ser um de cada vez: o Windows
    # nao deixa dois instaladores .msi rodarem juntos.)
    $paraBaixar = @($InstaladoresKit | Where-Object { -not (Test-Instalado $_.Busca) } | ForEach-Object { @{ Arquivo = $_.Arquivo; Sha256 = $_.Sha256 } })
    Iniciar-DownloadsEmSegundoPlano ($paraBaixar + @($WebSignerXpi))

    Titulo "1/4 Programas pelo winget"
    $script:Winget = Encontrar-Winget
    $temWinget = [bool]$script:Winget
    if (-not $temWinget) {
        Write-Host "winget nao encontrado (comum no Windows 10): vou baixar direto dos fabricantes." -ForegroundColor Yellow
    }
    foreach ($p in $ProgramasWinget) {
        if (Test-Instalado $p.Busca) { Write-Host "[ja instalado] $($p.Nome)" -ForegroundColor DarkGray; continue }
        Instalar-ProgramaWinget $p $temWinget
        if (-not (Test-Instalado $p.Busca)) {
            Write-Host "  Nao foi possivel instalar $($p.Nome). Confira a internet e veja o log." -ForegroundColor Red
        }
    }

    Titulo "2/4 Programas do kit"
    foreach ($p in $InstaladoresKit) {
        if (Test-Instalado $p.Busca) { Write-Host "[ja instalado] $($p.Nome)" -ForegroundColor DarkGray; continue }
        $arquivo = Obter-Arquivo $p.Arquivo $p.Sha256
        if (-not $arquivo) { continue }
        Write-Host "Instalando $($p.Nome) $($p.Versao)..."
        $codigo = Executar-Instalador $arquivo $p.Argumentos
        if ($null -eq $codigo) {
            Write-Host "  O instalador passou de $MinutosLimite minutos sem terminar. Seguindo para o proximo." -ForegroundColor Yellow
        } elseif ($codigo -notin 0, 3010) {
            Write-Host "  Codigo de saida $codigo - confira os parametros silenciosos." -ForegroundColor Yellow
        }
    }

    Titulo "3/4 Extensao Web Signer e certificados"
    Aplicar-ExtensaoWebSigner
    [void](Instalar-CadeiaIcp)
    if (Gravar-PoliticaFirefox $null $true) { Write-Host "Firefox: usa os certificados do Windows e o modulo do token." }

    Titulo "4/4 Checagem final"
    foreach ($p in ($ProgramasWinget + $InstaladoresKit)) {
        $ok = Test-Instalado $p.Busca
        [void]$resultado.Add([pscustomobject]@{ Item = $p.Nome; OK = $ok; Detalhe = $(if ($ok) { "instalado" } else { "NAO encontrado" }) })
    }
    $chavesExt = [ordered]@{
        "Extensao no Chrome" = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
        "Extensao no Edge"   = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    }
    foreach ($nome in $chavesExt.Keys) {
        $ok = $false
        if (Test-Path $chavesExt[$nome]) {
            $vals = (Get-ItemProperty $chavesExt[$nome]).PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
            $ok = [bool]($vals | Where-Object { $_.Value -like "$WebSignerChromeId*" })
        }
        [void]$resultado.Add([pscustomobject]@{ Item = $nome; OK = $ok; Detalhe = $(if ($ok) { "politica aplicada" } else { "politica ausente" }) })
    }
    $pastaFirefox = Pasta-Firefox
    $okFx = [bool]($pastaFirefox -and (Test-Path "$pastaFirefox\distribution\policies.json") -and
        ((Get-Content "$pastaFirefox\distribution\policies.json" -Raw) -like "*$WebSignerFirefoxId*"))
    [void]$resultado.Add([pscustomobject]@{ Item = "Extensao no Firefox"; OK = $okFx; Detalhe = $(if ($okFx) { "politica aplicada" } else { "politica ausente" }) })
    $okIcp = Cadeia-IcpInstalada
    [void]$resultado.Add([pscustomobject]@{ Item = "Cadeia ICP-Brasil"; OK = $okIcp; Detalhe = $(if ($okIcp) { "raizes instaladas" } else { "faltam raizes" }) })

    Write-Host ""
    foreach ($r in $resultado) {
        if ($r.OK) { Write-Host ("  [OK]     {0,-22} {1}" -f $r.Item, $r.Detalhe) -ForegroundColor Green }
        else       { Write-Host ("  [FALHOU] {0,-22} {1}" -f $r.Item, $r.Detalhe) -ForegroundColor Red }
    }
    Write-Host ""
    Limpar-DownloadsPendentes
    Write-Host "Feche e abra os navegadores para a extensao aparecer." -ForegroundColor Cyan
    Write-Host "Log salvo em: $log"
    Stop-Transcript | Out-Null
}

# O winget e instalado POR USUARIO. Quando o kit roda com a conta do tecnico (o usuario
# da maquina nao e administrador), o atalho "winget" pode nao existir para essa conta,
# mesmo com o winget instalado. Entao procura o programa direto na pasta do Windows.
function Encontrar-Winget {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $achados = @(Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue)
    if ($achados.Count -eq 0) { return $null }
    $melhor = $achados | Sort-Object {
        try { [version](($_.Directory.Name -split '_')[1]) } catch { [version]"0.0" }
    } -Descending | Select-Object -First 1
    return $melhor.FullName
}

# Downloads dos arquivos do kit (Release) em segundo plano, todos ao mesmo tempo.
$script:DownloadsEmAndamento = @{}
function Iniciar-DownloadsEmSegundoPlano($arquivos) {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { return }
    $nomes = @()
    foreach ($a in $arquivos) {
        if ($PastaLocal -and (Hash-Confere (Join-Path $PastaLocal $a.Arquivo) $a.Sha256)) { continue }
        $destino = Join-Path "$PastaTI\instaladores" $a.Arquivo
        if (Hash-Confere $destino $a.Sha256) { continue }
        if ($script:DownloadsEmAndamento.ContainsKey($a.Arquivo)) { continue }
        $parcial = "$destino.parcial"
        Remove-Item $parcial -Force -ErrorAction SilentlyContinue
        $proc = Start-Process curl.exe -WindowStyle Hidden -PassThru `
            -ArgumentList "-sL --fail --retry 5 --retry-delay 3 -o `"$parcial`" `"$UrlArquivos/$($a.Arquivo)`""
        $null = $proc.Handle
        $script:DownloadsEmAndamento[$a.Arquivo] = @{ Proc = $proc; Parcial = $parcial; Destino = $destino }
        $nomes += $a.Arquivo
    }
    if ($nomes) { Write-Host "Baixando em segundo plano: $($nomes -join ', ')" -ForegroundColor DarkGray }
}

# Se o arquivo estava sendo baixado em segundo plano, espera terminar e devolve o caminho
function Aguardar-DownloadEmSegundoPlano($arquivo) {
    $bg = $script:DownloadsEmAndamento[$arquivo]
    if (-not $bg) { return $null }
    if (-not $bg.Proc.HasExited) { Write-Host "  Esperando o download de $arquivo terminar..." }
    $bg.Proc.WaitForExit()
    $script:DownloadsEmAndamento.Remove($arquivo)
    if (Test-Path $bg.Parcial) { Move-Item $bg.Parcial $bg.Destino -Force }
    return $bg.Destino
}

# Ao terminar a instalacao: para downloads que sobraram (ex.: .xpi sem Firefox) e apaga o que ficou pela metade
function Limpar-DownloadsPendentes {
    foreach ($bg in @($script:DownloadsEmAndamento.Values)) {
        if (-not $bg.Proc.HasExited) { Stop-Process -Id $bg.Proc.Id -Force -ErrorAction SilentlyContinue }
        Remove-Item $bg.Parcial -Force -ErrorAction SilentlyContinue
    }
    $script:DownloadsEmAndamento = @{}
}

# winget primeiro; se nao tiver winget ou ele falhar, plano B (Reserva)
function Instalar-ProgramaWinget($p, $temWinget) {
    if ($temWinget) {
        $base = @("install", "-e", "--id", $p.Id, "--silent", "--source", "winget",
                  "--accept-package-agreements", "--accept-source-agreements")
        if ($p.Versao) { $base += @("--version", $p.Versao) }
        Write-Host "Instalando $($p.Nome) $($p.Versao)..."
        $parametros = $base
        if ($p.Escopo) { $parametros = $base + @("--scope", $p.Escopo) }
        & $script:Winget @parametros
        $codigo = $LASTEXITCODE
        if (-not (Test-Instalado $p.Busca) -and $p.Escopo) {
            # alguns pacotes nao tem instalador "para a maquina toda": tenta sem escolher
            & $script:Winget @base
            $codigo = $LASTEXITCODE
        }
        if (Test-Instalado $p.Busca) { return }
        Write-Host "  O winget nao conseguiu instalar (codigo $codigo)." -ForegroundColor Yellow
    }
    if (-not $p.Reserva) { return }
    $r = $p.Reserva
    if ($r.Release) { $arquivo = Obter-Arquivo $r.Release $r.Sha256 }
    else { $arquivo = Baixar-DoFabricante $r.Url $r.Arquivo $r.Assinante }
    if (-not $arquivo) { return }
    Write-Host "  Instalando $($p.Nome) pelo plano B..."
    $codigoInst = Executar-Instalador $arquivo $r.Argumentos
    if ($null -eq $codigoInst) { Write-Host "  O instalador passou de $MinutosLimite minutos sem terminar." -ForegroundColor Yellow }
    elseif ($codigoInst -notin 0, 3010) { Write-Host "  Codigo de saida $codigoInst." -ForegroundColor Yellow }
}

# Baixa do site oficial do fabricante e SO devolve o arquivo se ele estiver assinado
# digitalmente por esse fabricante (o arquivo muda a cada versao, entao nao da para
# fixar a impressao digital; a assinatura e o que garante que e o original).
function Baixar-DoFabricante($url, $arquivo, $assinante) {
    $destino = Join-Path "$PastaTI\instaladores" $arquivo
    Remove-Item $destino -Force -ErrorAction SilentlyContinue
    Write-Host "  Baixando $arquivo do site do fabricante..."
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --fail --retry 5 --retry-delay 3 -# -o $destino $url
    } else {
        try { Invoke-WebRequest -Uri $url -OutFile $destino -UseBasicParsing } catch { }
    }
    if (-not (Test-Path $destino)) { Write-Host "  Nao consegui baixar $arquivo." -ForegroundColor Red; return $null }
    $assinatura = Get-AuthenticodeSignature $destino
    if ($assinatura.Status -eq "Valid" -and $assinatura.SignerCertificate.Subject -like "*CN=$assinante*") { return $destino }
    if ($assinatura.Status -eq "Valid" -and $assinatura.SignerCertificate.Subject -like "*CN=`"$assinante*") { return $destino }
    Write-Host "  [BLOQUEADO] $arquivo nao esta assinado por $assinante (assinatura: $($assinatura.Status)). Nao vou instalar." -ForegroundColor Red
    Remove-Item $destino -Force -ErrorAction SilentlyContinue
    return $null
}

function Mostrar-ComandoMac {
    Write-Host ""
    Write-Host "   Este kit esta aberto num Windows. Para configurar um Mac," -ForegroundColor Cyan
    Write-Host "   abra o Terminal no Mac (Cmd+Espaco, digite Terminal) e cole:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   curl -fsSL $UrlScriptMac | bash" -ForegroundColor White
    Write-Host ""
}

# Opcoes do Windows (so aparecem depois de escolher Windows na primeira tela)
function Menu-Windows {
    while ($true) {
        Mostrar-Cabecalho
        Write-Host "   WINDOWS" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Instalar programas"
        Write-Host "   [2] Correcao de erros"
        Write-Host "   [3] Desinstalar programas"
        Write-Host "   [4] Adicionar favoritos nos navegadores"
        Write-Host "   [0] Voltar"
        Write-Host ""
        switch (Ler-Opcao @("1", "2", "3", "4", "0")) {
            "1" { Instalar-Windows; $script:CacheToken = $null; Pausar }
            "2" { Menu-Correcoes }
            "3" { Menu-Desinstalar; $script:CacheToken = $null }
            "4" { Menu-Favoritos }
            "0" { return }
        }
    }
}

# ===================== FAVORITOS NOS NAVEGADORES =====================

function Adicionar-FavoritosChrome {
    $perfil = Perfil-UsuarioTela
    $baseChrome = "$perfil\AppData\Local\Google\Chrome\User Data"
    $exeChrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$perfil\AppData\Local\Google\Chrome\Application\chrome.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $exeChrome -and -not (Test-Path $baseChrome)) {
        Write-Host "  Google Chrome nao encontrado nesta maquina." -ForegroundColor Yellow
        return
    }
    $perfisCr = @()
    if (Test-Path $baseChrome) {
        $perfisCr = @(Get-ChildItem $baseChrome -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" -or (Test-Path "$($_.FullName)\Preferences") -or (Test-Path "$($_.FullName)\Bookmarks") } |
            ForEach-Object { $_.FullName })
    }
    if ($perfisCr.Count -eq 0) { $perfisCr = @("$baseChrome\Default") }

    $utf8SemBom = New-Object Text.UTF8Encoding($false)
    $agoraCr = [string]([int64](([DateTime]::UtcNow - [DateTime]::new(1601, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalMilliseconds * 1000))

    foreach ($p in ($perfisCr | Select-Object -Unique)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        $arqFav = Join-Path $p "Bookmarks"
        $dados = $null
        if (Test-Path $arqFav) {
            try { $dados = [IO.File]::ReadAllText($arqFav, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $dados = $null }
        }
        if (-not $dados -or -not $dados.roots -or -not $dados.roots.bookmark_bar) {
            $dados = [pscustomobject]@{
                roots = [pscustomobject]@{
                    bookmark_bar = [pscustomobject]@{
                        children = @()
                        date_added = $agoraCr
                        date_last_used = "0"
                        date_modified = $agoraCr
                        guid = "0bc5d13f-2cba-5d74-951f-3f233fe6c908"
                        id = "1"
                        name = "Barra de favoritos"
                        type = "folder"
                    }
                    other = [pscustomobject]@{
                        children = @()
                        date_added = $agoraCr
                        date_last_used = "0"
                        date_modified = "0"
                        guid = "82b081ec-3dd3-529c-8475-ab6c344590dd"
                        id = "2"
                        name = "Outros favoritos"
                        type = "folder"
                    }
                    synced = [pscustomobject]@{
                        children = @()
                        date_added = $agoraCr
                        date_last_used = "0"
                        date_modified = "0"
                        guid = "4cf2e351-0e85-532b-bb37-df045d8f8d0f"
                        id = "3"
                        name = "Dispositivos moveis"
                        type = "folder"
                    }
                }
                version = 1
            }
        }

        $textoAtual = ($dados | ConvertTo-Json -Depth 20 -Compress)
        $maxId = 10
        foreach ($m in [regex]::Matches($textoAtual, '"id"\s*:\s*"(\d+)"')) {
            $v = [int]$m.Groups[1].Value
            if ($v -gt $maxId) { $maxId = $v }
        }

        $atuais = @($dados.roots.bookmark_bar.children)
        $urlsExistentes = @($atuais | Where-Object { $_.url } | ForEach-Object { $_.url })
        $novos = 0
        foreach ($f in $Favoritos) {
            if ($urlsExistentes -contains $f.Url) { continue }
            $maxId++
            $atuais += [pscustomobject]@{
                date_added = $agoraCr
                date_last_used = "0"
                guid = [guid]::NewGuid().ToString()
                id = "$maxId"
                name = $f.Nome
                type = "url"
                url = $f.Url
            }
            $novos++
        }
        $dados.roots.bookmark_bar.children = $atuais
        $dados.roots.bookmark_bar.date_modified = $agoraCr
        if ($dados.PSObject.Properties["checksum"]) { [void]$dados.PSObject.Properties.Remove("checksum") }
        Remove-Item "$arqFav.bak" -Force -ErrorAction SilentlyContinue
        [IO.File]::WriteAllText($arqFav, ($dados | ConvertTo-Json -Depth 20), $utf8SemBom)

        # Mostra a barra de favoritos em todas as abas
        $arqPref = Join-Path $p "Preferences"
        if (Test-Path $arqPref) {
            $rawPref = [IO.File]::ReadAllText($arqPref, [Text.Encoding]::UTF8)
            if ($rawPref -match '"bookmark_bar"\s*:\s*\{') {
                if ($rawPref -match '"show_on_all_tabs"\s*:\s*(true|false)') {
                    $rawPref = [regex]::Replace($rawPref, '"show_on_all_tabs"\s*:\s*false', '"show_on_all_tabs":true')
                } else {
                    $rawPref = [regex]::Replace($rawPref, '"bookmark_bar"\s*:\s*\{', '"bookmark_bar":{"show_on_all_tabs":true,')
                }
            } elseif ($rawPref -match '^\s*\{\s*\}') {
                $rawPref = '{"bookmark_bar":{"show_on_all_tabs":true}}'
            } else {
                $rawPref = [regex]::Replace($rawPref, '^\s*\{', '{"bookmark_bar":{"show_on_all_tabs":true},')
            }
            [IO.File]::WriteAllText($arqPref, $rawPref, $utf8SemBom)
        } else {
            [IO.File]::WriteAllText($arqPref, '{"bookmark_bar":{"show_on_all_tabs":true}}', $utf8SemBom)
        }

        Write-Host ("  [OK] Chrome ({0}): {1} favoritos adicionados na barra de favoritos ({2} no total)." -f (Split-Path $p -Leaf), $novos, $Favoritos.Count) -ForegroundColor Green
    }
}

function Adicionar-FavoritosFirefox {
    if (-not (Pasta-Firefox)) {
        Write-Host "  Mozilla Firefox nao encontrado nesta maquina." -ForegroundColor Yellow
        return
    }
    [void](Gravar-PoliticaFirefox $null $null $true)
    $perfil = Perfil-UsuarioTela
    $perfisFx = @(Garantir-PerfilFirefox $perfil)
    foreach ($d in $perfisFx) {
        foreach ($nomeArq in "prefs.js", "user.js") {
            $arq = Join-Path $d.FullName $nomeArq
            if ($nomeArq -eq "prefs.js" -and -not (Test-Path $arq)) { continue }
            $linhas = @()
            if (Test-Path $arq) {
                $linhas = @(Get-Content $arq | Where-Object { $_ -notmatch 'browser\.toolbars\.bookmarks\.visibility' })
            }
            $linhas += 'user_pref("browser.toolbars.bookmarks.visibility", "always");'
            [IO.File]::WriteAllLines($arq, ($linhas -as [string[]]))
        }
    }
    Write-Host ("  [OK] Firefox: {0} favoritos adicionados na barra de favoritos." -f $Favoritos.Count) -ForegroundColor Green
}

function Menu-Favoritos {
    while ($true) {
        Mostrar-Cabecalho
        Write-Host "   ADICIONAR FAVORITOS DOS TRIBUNAIS" -ForegroundColor Cyan
        Write-Host "   Adiciona na barra de favoritos sem apagar os favoritos que ja existem:" -ForegroundColor DarkGray
        Write-Host "   $(($Favoritos | ForEach-Object { $_.Nome }) -join ', ')" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   Em qual navegador voce quer adicionar os favoritos?"
        Write-Host ""
        Write-Host "   [1] Google Chrome"
        Write-Host "   [2] Mozilla Firefox"
        Write-Host "   [3] Nos dois (Chrome e Firefox)"
        Write-Host "   [0] Voltar"
        Write-Host ""
        $op = Ler-Opcao @("1", "2", "3", "0")
        if ($op -eq "0") { return }
        Fechar-Navegadores
        if ($op -in "1", "3") {
            Titulo "Google Chrome"
            Adicionar-FavoritosChrome
        }
        if ($op -in "2", "3") {
            Titulo "Mozilla Firefox"
            Adicionar-FavoritosFirefox
        }
        Pausar
    }
}


# ===================== 2. CORRECAO DE ERROS ==========================
# Para adicionar uma correcao: copie um bloco @{ ... } em $Correcoes e mude Nome, Descricao e Acao.

# Sites dos tribunais usados no dia a dia (teste "esta fora do ar?" e "abrir em outro navegador").
# Para incluir outro, copie a linha e troque Nome e Url.
$Tribunais = @(
    @{ Nome = "eSAJ (TJAL)"; Url = "https://www2.tjal.jus.br/esaj/" }
    # @{ Nome = "eproc"; Url = "https://COLE_O_ENDERECO_AQUI/" }
)

# Servidores de hora do Brasil (NTP.br) para acertar o relogio
$ServidoresHora = "a.st1.ntp.br,0x8 b.st1.ntp.br,0x8 time.windows.com,0x8"

function Perguntar-SN($texto) {
    return ((Read-Host "   $texto (S/N)").Trim().ToUpper() -eq "S")
}

# Pasta do usuario logado na tela. O kit pode estar rodando com OUTRA conta de
# administrador (a do tecnico); o cache e os cookies que importam sao os do usuario.
function Perfil-UsuarioTela {
    try {
        $u = (Get-CimInstance Win32_ComputerSystem).UserName
        if (-not $u) {
            # sem usuario "no console" (ex.: acesso remoto): usa o dono da area de trabalho
            $dono = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | Select-Object -First 1 | Invoke-CimMethod -MethodName GetOwner
            if ($dono.User) { $u = "$($dono.Domain)\$($dono.User)" }
        }
        if ($u) {
            $sid = (New-Object Security.Principal.NTAccount($u)).Translate([Security.Principal.SecurityIdentifier]).Value
            $p = (Get-CimInstance Win32_UserProfile | Where-Object { $_.SID -eq $sid }).LocalPath
            if ($p) { return $p }
        }
    } catch { }
    return $env:USERPROFILE
}

function Fechar-Navegadores {
    $abertos = Get-Process -Name "chrome", "msedge", "firefox" -ErrorAction SilentlyContinue
    if ($abertos) {
        $abertos | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "  Navegadores fechados."
    }
}

# Perfis do Chrome e do Edge (Default, Profile 1, ...)
function Pastas-PerfisChromium($perfil) {
    foreach ($base in "$perfil\AppData\Local\Google\Chrome\User Data", "$perfil\AppData\Local\Microsoft\Edge\User Data") {
        if (-not (Test-Path $base)) { continue }
        Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "Preferences") } | ForEach-Object { $_.FullName }
    }
}

function Limpar-Navegadores([bool]$cookies) {
    $perfil = Perfil-UsuarioTela
    Fechar-Navegadores
    $alvos = New-Object System.Collections.ArrayList
    foreach ($p in (Pastas-PerfisChromium $perfil)) {
        foreach ($s in "Cache", "Code Cache", "GPUCache", "Service Worker\CacheStorage", "Service Worker\ScriptCache") { [void]$alvos.Add((Join-Path $p $s)) }
        if ($cookies) {
            foreach ($s in "Network\Cookies", "Network\Cookies-journal", "Cookies", "Cookies-journal") { [void]$alvos.Add((Join-Path $p $s)) }
        }
    }
    foreach ($d in (Get-ChildItem "$perfil\AppData\Local\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue)) {
        [void]$alvos.Add((Join-Path $d.FullName "cache2")); [void]$alvos.Add((Join-Path $d.FullName "startupCache"))
    }
    if ($cookies) {
        foreach ($d in (Get-ChildItem "$perfil\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue)) {
            foreach ($s in "cookies.sqlite", "cookies.sqlite-wal", "cookies.sqlite-shm") { [void]$alvos.Add((Join-Path $d.FullName $s)) }
        }
    }
    $bytes = 0
    foreach ($a in $alvos) {
        if (-not (Test-Path -LiteralPath $a)) { continue }
        $bytes += [double](Get-ChildItem -LiteralPath $a -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Remove-Item -LiteralPath $a -Recurse -Force -ErrorAction SilentlyContinue
    }
    $oque = $(if ($cookies) { "cache e cookies" } else { "cache" })
    Write-Host ("  Limpo: {0} de Chrome, Edge e Firefox ({1:N0} MB)." -f $oque, ($bytes / 1MB)) -ForegroundColor Green
    if ($cookies) { Write-Host "  A pessoa vai precisar entrar de novo nos sites (e-mail, tribunal, etc.)." -ForegroundColor Yellow }
}

function Limpar-Dns([bool]$renovarIp) {
    ipconfig /flushdns | Out-Null
    ipconfig /registerdns | Out-Null
    Write-Host "  Cache de DNS limpo." -ForegroundColor Green
    if ($renovarIp) {
        Write-Host "  Renovando o IP (a internet cai por alguns segundos)..."
        ipconfig /release | Out-Null
        ipconfig /renew | Out-Null
        Write-Host "  IP renovado." -ForegroundColor Green
    }
}

function Perguntar-RenovarIp {
    Write-Host "   Renovar o IP derruba a internet por alguns segundos." -ForegroundColor Yellow
    Write-Host "   Se voce estiver acessando por AnyDesk, a conexao cai e volta sozinha." -ForegroundColor Yellow
    return (Perguntar-SN "Renovar o IP tambem?")
}

# Testa um site. Qualquer resposta abaixo de 500 conta como "no ar" (ate 403/404 e o servidor respondendo).
function Testar-Site($url) {
    $relogio = [Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        $codigo = [int]$r.StatusCode
    } catch {
        $resp = $_.Exception.Response
        if (-not $resp) { return @{ Ok = $false; Seg = $relogio.Elapsed.TotalSeconds; Erro = $_.Exception.Message } }
        $codigo = [int]$resp.StatusCode
    }
    return @{ Ok = ($codigo -lt 500); Seg = $relogio.Elapsed.TotalSeconds; Codigo = $codigo; Erro = "codigo $codigo" }
}

# Devolve $true se a internet e todos os tribunais responderam
function Verificar-Tribunais {
    $net = Testar-Site "https://www.google.com"
    if (-not $net.Ok) {
        Write-Host "  [SEM INTERNET] Nem o Google abriu. O problema e a internet desta maquina ou da rede." -ForegroundColor Red
        return $false
    }
    Write-Host ("  [OK]          Internet funcionando ({0:N1} s)" -f $net.Seg) -ForegroundColor Green
    $todos = $true
    foreach ($t in $Tribunais) {
        $dominio = ([Uri]$t.Url).Host
        if (-not (Resolve-DnsName $dominio -ErrorAction SilentlyContinue)) {
            Write-Host "  [DNS]         $($t.Nome): o endereco nao foi encontrado. Use 'Limpar DNS e renovar IP'." -ForegroundColor Red
            $todos = $false; continue
        }
        $r = Testar-Site $t.Url
        if (-not $r.Ok) {
            Write-Host "  [FORA DO AR]  $($t.Nome): nao respondeu ($($r.Erro))." -ForegroundColor Red
            Write-Host "                A internet esta funcionando, entao deve ser instabilidade do tribunal." -ForegroundColor Red
            Write-Host "                Aguarde e tente de novo; confira os avisos no site ou nas redes do tribunal." -ForegroundColor Red
            $todos = $false
        } elseif ($r.Seg -gt 8) {
            Write-Host ("  [LENTO]       {0}: respondeu, mas demorou {1:N1} s. O tribunal pode estar sobrecarregado." -f $t.Nome, $r.Seg) -ForegroundColor Yellow
        } else {
            Write-Host ("  [OK]          {0} no ar ({1:N1} s)" -f $t.Nome, $r.Seg) -ForegroundColor Green
        }
    }
    return $todos
}

# Estado da extensao Web Signer em cada navegador instalado:
#   OK = configurada e ja baixada | PENDENTE = configurada, falta abrir o navegador | FALTA = nao configurada
function Status-ExtensaoWebSigner {
    $perfil = Perfil-UsuarioTela
    $lista = @()
    $navegadores = @(
        @{ Nome = "Chrome"; Base = "$perfil\AppData\Local\Google\Chrome\User Data"; Chave = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" },
        @{ Nome = "Edge";   Base = "$perfil\AppData\Local\Microsoft\Edge\User Data"; Chave = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" }
    )
    foreach ($n in $navegadores) {
        if (-not (Test-Path $n.Base)) { continue }
        $politica = $false
        if (Test-Path $n.Chave) {
            $politica = [bool]((Get-ItemProperty $n.Chave).PSObject.Properties | Where-Object { $_.Value -like "$WebSignerChromeId*" })
        }
        $baixada = [bool](Get-ChildItem "$($n.Base)\*\Extensions\$WebSignerChromeId" -Directory -ErrorAction SilentlyContinue)
        $lista += [pscustomobject]@{ Nome = $n.Nome; Estado = $(if ($politica -and $baixada) { "OK" } elseif ($politica) { "PENDENTE" } else { "FALTA" }) }
    }
    $pastaFirefox = Pasta-Firefox
    if ($pastaFirefox) {
        $pol = "$pastaFirefox\distribution\policies.json"
        $politica = (Test-Path $pol) -and ((Get-Content $pol -Raw) -like "*$WebSignerFirefoxId*") -and ((Get-Content $pol -Raw) -like "*force_installed*")
        $baixada = [bool](Get-ChildItem "$perfil\AppData\Roaming\Mozilla\Firefox\Profiles\*\extensions\$WebSignerFirefoxId.xpi" -ErrorAction SilentlyContinue)
        $lista += [pscustomobject]@{ Nome = "Firefox"; Estado = $(if ($politica -and $baixada) { "OK" } elseif ($politica) { "PENDENTE" } else { "FALTA" }) }
    }
    return $lista
}

function Verificar-WebSigner {
    if (Test-Instalado "Web Signer") { Write-Host "  [OK]     Programa Web Signer instalado" -ForegroundColor Green }
    else { Write-Host "  [FALTA]  Programa Web Signer nao instalado. Use 'Instalar programas'." -ForegroundColor Red }
    $faltaPolitica = $false
    foreach ($n in Status-ExtensaoWebSigner) {
        switch ($n.Estado) {
            "OK"       { Write-Host "  [OK]     Extensao no $($n.Nome)" -ForegroundColor Green }
            "PENDENTE" { Write-Host "  [AVISO]  $($n.Nome): extensao configurada, mas ainda nao baixada. Abra o $($n.Nome) e espere 1 minuto." -ForegroundColor Yellow }
            "FALTA"    { Write-Host "  [FALTA]  Extensao no $($n.Nome)" -ForegroundColor Red; $faltaPolitica = $true }
        }
    }
    if ($faltaPolitica -and (Perguntar-SN "Aplicar a extensao Web Signer de novo?")) {
        Aplicar-ExtensaoWebSigner
        Write-Host "  Feche e abra os navegadores." -ForegroundColor Cyan
    } else {
        Configurar-TogglesWebSigner
    }
}

function Abrir-EmOutroNavegador {
    $site = $Tribunais[0]
    if ($Tribunais.Count -gt 1) {
        for ($i = 0; $i -lt $Tribunais.Count; $i++) { Write-Host ("   [{0}] {1}" -f ($i + 1), $Tribunais[$i].Nome) }
        $site = $Tribunais[[int](Ler-Opcao (1..$Tribunais.Count | ForEach-Object { "$_" })) - 1]
    }
    $opcoes = @(
        @{ Nome = "Google Chrome";   Exe = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" },
        @{ Nome = "Microsoft Edge";  Exe = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" },
        @{ Nome = "Mozilla Firefox"; Exe = "$env:ProgramFiles\Mozilla Firefox\firefox.exe", "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe" }
    )
    $instalados = @()
    foreach ($o in $opcoes) {
        $exe = $o.Exe | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($exe) { $instalados += @{ Nome = $o.Nome; Exe = $exe } }
    }
    if ($instalados.Count -eq 0) { Write-Host "  Nenhum navegador encontrado." -ForegroundColor Red; return }
    Write-Host "   Em qual navegador abrir $($site.Nome)?"
    for ($i = 0; $i -lt $instalados.Count; $i++) { Write-Host ("   [{0}] {1}" -f ($i + 1), $instalados[$i].Nome) }
    $n = $instalados[[int](Ler-Opcao (1..$instalados.Count | ForEach-Object { "$_" })) - 1]
    # Abre como usuario comum (sem administrador): o navegador nao deve rodar elevado.
    # O runas nao aceita aspas aninhadas, entao usa o caminho curto (sem espacos) do programa.
    $curto = (New-Object -ComObject Scripting.FileSystemObject).GetFile($n.Exe).ShortPath
    if ($curto -notmatch ' ' -and $site.Url -notmatch '[ "&]') {
        Start-Process runas.exe -ArgumentList "/trustlevel:0x20000 `"$curto $($site.Url)`"" -WindowStyle Hidden
    } else {
        Start-Process $n.Exe -ArgumentList $site.Url
    }
    Write-Host "  Abrindo $($site.Nome) no $($n.Nome). Se funcionar aqui, o problema e o outro navegador:" -ForegroundColor Green
    Write-Host "  use 'Limpar cache e cookies'." -ForegroundColor Green
}

function Acertar-Relogio {
    Write-Host "  Antes: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    Set-Service w32time -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service w32time -ErrorAction SilentlyContinue
    w32tm /config /manualpeerlist:"$ServidoresHora" /syncfromflags:manual /update | Out-Null
    $saida = w32tm /resync /force 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    Write-Host "  Depois: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')   Fuso: $((Get-TimeZone).DisplayName)"
    if ($ok) { Write-Host "  Relogio do computador acertado pela hora oficial (NTP.br)." -ForegroundColor Green }
    else { Write-Host "  Nao consegui acertar o relogio: $($saida -join ' ')" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "  O codigo do Google Autenticador e gerado no CELULAR, pela hora dele." -ForegroundColor Cyan
    Write-Host "  Se o codigo continuar dando errado, acerte a hora do celular:" -ForegroundColor Cyan
    Write-Host "    Android: Configuracoes > Data e hora > ligar 'Data e hora automaticas'"
    Write-Host "    iPhone:  Ajustes > Geral > Data e Hora > ligar 'Automaticamente'"
    Write-Host "  Confira tambem se a conta certa esta selecionada no app (pode ter varias)."
}

$Correcoes = @(
    @{
        Nome = "Tribunal nao carrega (eSAJ, eproc...)"
        Descricao = "Faz tudo em ordem: testa o tribunal, limpa DNS e cache, confere a extensao e testa de novo."
        Acao = {
            Titulo "1/5 O tribunal esta no ar?"
            $noAr = Verificar-Tribunais
            if (-not $noAr -and -not (Perguntar-SN "Algo esta fora do ar. Continuar as limpezas mesmo assim?")) { return }
            Titulo "2/5 DNS e IP"
            Limpar-Dns (Perguntar-RenovarIp)
            Titulo "3/5 Cache dos navegadores (fecha os navegadores)"
            Limpar-Navegadores (Perguntar-SN "Limpar os cookies tambem? A pessoa vai ter que entrar de novo nos sites")
            Titulo "4/5 Extensao Web Signer"
            Verificar-WebSigner
            Titulo "5/5 Testando de novo"
            [void](Verificar-Tribunais)
            Write-Host ""
            Write-Host "  Abra o tribunal de novo. Se continuar com erro, use 'Abrir o tribunal em outro navegador'." -ForegroundColor Cyan
        }
    },
    @{
        Nome = "Erro de conexao com certificado digital"
        Descricao = "Ex.: 'Ocorreu um erro durante uma conexao com certificado-sso.tjal.jus.br'. Confere o token e instala a cadeia ICP-Brasil."
        Acao = { Corrigir-CertificadoDigital }
    },
    @{
        Nome = "Limpar cache dos navegadores"
        Descricao = "Fecha Chrome, Edge e Firefox e apaga o cache. Nao desloga de nenhum site."
        Acao = { Limpar-Navegadores $false }
    },
    @{
        Nome = "Limpar cache e cookies"
        Descricao = "Igual ao anterior, mas apaga os cookies tambem: desloga de TODOS os sites."
        Acao = { Limpar-Navegadores $true }
    },
    @{
        Nome = "Limpar DNS e renovar IP"
        Descricao = "Limpa falhas de DNS (ipconfig /flushdns) e, se quiser, renova o IP."
        Acao = { Limpar-Dns (Perguntar-RenovarIp) }
    },
    @{
        Nome = "Abrir o tribunal em outro navegador"
        Descricao = "Para descobrir se o problema e so de um navegador."
        Acao = { Abrir-EmOutroNavegador }
    },
    @{
        Nome = "Codigo do Google Autenticador nao funciona"
        Descricao = "Acerta o relogio do computador pela hora oficial e mostra como acertar o do celular."
        Acao = { Acertar-Relogio }
    },
    @{
        Nome = "Token nao reconhecido"
        Descricao = "Reinicia os servicos de cartao inteligente do Windows."
        Acao = {
            foreach ($s in "SCardSvr", "CertPropSvc") {
                $svc = Get-Service $s -ErrorAction SilentlyContinue
                if (-not $svc) { continue }
                Set-Service $s -StartupType Automatic
                Restart-Service $s -Force -ErrorAction SilentlyContinue
                Write-Host "  Servico $s reiniciado." -ForegroundColor Green
            }
            Write-Host "  Tire o token, espere 5 segundos e coloque de novo."
        }
    },
    @{
        Nome = "Liberar remocao da extensao Web Signer"
        Descricao = "Tira a trava do Chrome, Edge e Firefox: a extensao continua, mas o usuario passa a poder remover."
        Acao = {
            Liberar-ExtensaoWebSigner
            Write-Host "  Pronto. Feche e abra os navegadores: a extensao Web Signer pode ser removida pelo usuario." -ForegroundColor Green
        }
    }
)

function Menu-Correcoes {
    while ($true) {
        Mostrar-Cabecalho
        Write-Host "   CORRECAO DE ERROS" -ForegroundColor Cyan
        Write-Host ""
        for ($i = 0; $i -lt $Correcoes.Count; $i++) {
            Write-Host ("   [{0}] {1}" -f ($i + 1), $Correcoes[$i].Nome)
            Write-Host ("       {0}" -f $Correcoes[$i].Descricao) -ForegroundColor DarkGray
        }
        Write-Host "   [0] Voltar"
        Write-Host ""
        $validas = @("0") + (1..$Correcoes.Count | ForEach-Object { "$_" })
        $op = Ler-Opcao $validas
        if ($op -eq "0") { return }
        $c = $Correcoes[[int]$op - 1]
        Titulo $c.Nome
        & $c.Acao
        Pausar
    }
}


# =========================== MENU ====================================

while ($true) {
    Mostrar-Cabecalho
    Write-Host "   Qual computador voce vai configurar?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1] Windows   (este computador)"
    Write-Host "   [2] Mac"
    Write-Host "   [0] Sair"
    Write-Host ""
    switch (Ler-Opcao @("1", "2", "0")) {
        "1" { Menu-Windows }
        "2" { Mostrar-ComandoMac; Pausar }
        "0" { Limpar-Historico; Write-Host ""; Write-Host "   Ate logo!" -ForegroundColor DarkYellow; return }
    }
}
