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
#   Busca    = trecho do nome que aparece em "Aplicativos instalados"
#   Versao   = versao fixa. Sem Versao, instala a mais nova. Para atualizar, troque aqui
#              (veja as versoes com: winget show --id ID --versions).
#   Pendrive = plano B SEM internet: so e usado quando o kit roda do pendrive e o winget
#              nao conseguiu instalar. O arquivo fica na pasta "instaladores" do pendrive.
$ProgramasWinget = @(
    @{ Nome = "WinRAR";          Id = "RARLab.WinRAR";   Busca = "WinRAR" },
    @{ Nome = "Google Chrome";   Id = "Google.Chrome";   Busca = "Google Chrome" },
    @{ Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox"; Busca = "Mozilla Firefox" },
    @{ Nome = "Driver do token GD"; Id = "AETEurope.SafeSignICStandard"; Versao = "3.5.3.0"; Busca = "SafeSign"
       Pendrive = @{ Arquivo = "safesign.exe"; Argumentos = '/s /v"/qn /norestart"'; Sha256 = "0dad976c832526f494f665661fb8b47a93c5f9b969bc9b7d5496d6dd87ae6dfe" } },
    @{ Nome = "Web Signer"; Id = "SoftplanSistemas.WebSigner"; Versao = "2.15.0.0"; Busca = "Web Signer"
       Pendrive = @{ Arquivo = "websigner.msi"; Argumentos = "/qn /norestart"; Sha256 = "e66d0df97ff28272d4535b19f1ac3c67b13bc7ab3fb695e27ba72e5a1f4be0a3" } }
)

# Instaladores baixados do Release do GitHub (ou da pasta "instaladores" do pendrive).
# Aqui ficam os que nao estao no winget e os que no winget sao lentos demais: o SafeNet
# do winget vem num pacote de 142 MB da DigiCert; o nosso safenet.msi tem 15 MB.
#   Arquivo    = nome exato do arquivo no Release (sem espacos)
#   Sha256     = impressao digital do arquivo. Se o arquivo baixado nao bater, NAO instala.
#                Para gerar: Get-FileHash .\arquivo.exe -Algorithm SHA256
#   Argumentos = parametros de instalacao silenciosa
#   Busca      = trecho do nome em "Aplicativos instalados"
# Ao atualizar um programa: troque o arquivo no Release "instaladores" (mesmo nome)
# e troque Versao e Sha256 aqui.
$InstaladoresKit = @(
    @{ Nome = "PJeOffice Pro";      Versao = "2.5.16u"; Arquivo = "pjeoffice.exe"; Argumentos = "/S";
       Busca = "PJeOffice"; Sha256 = "8237999eff5313607daf53558b4a0b8f3aba4da670c6438ee34eb25120b45bc4" },
    @{ Nome = "SafeNet (token)";    Versao = "10.7";    Arquivo = "safenet.msi";   Argumentos = "/qn /norestart";
       Busca = "SafeNet Authentication Client"; Sha256 = "a998da33cab2d70675d5de9a8a114f870f643dba1f676f9586b263030c395e12" }
)

# Tipos de token reconhecidos no cabecalho, pelo nome que o aparelho USB informa.
#   Padrao = trecho do nome (expressao regular, sem diferenciar maiusculas)
#   Driver = como o driver aparece em "Aplicativos instalados" ($null = nao vem no kit)
$TiposToken = @(
    @{ Padrao = 'etoken|token jc|safenet|aladdin';                Tipo = "SafeNet eToken";         Driver = "SafeNet Authentication Client"; DriverNome = "SafeNet" },
    @{ Padrao = 'idprime|gemalto';                                Tipo = "Thales/Gemalto IDPrime"; Driver = "SafeNet Authentication Client"; DriverNome = "SafeNet" },
    @{ Padrao = 'starsign|giesecke|g&d|g\+d|smart ?cafe|sm@rtcafe'; Tipo = "G+D StarSign";         Driver = "SafeSign";                      DriverNome = "SafeSign" },
    @{ Padrao = 'watchdata|proxkey';                              Tipo = "Watchdata";              Driver = $null;                           DriverNome = $null },
    @{ Padrao = 'epass|feitian';                                  Tipo = "Feitian ePass";          Driver = $null;                           DriverNome = $null }
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

# Leitores de cartao / tokens conectados agora. O tipo vem do nome que o USB informa
# (o Windows costuma chamar todos de "Usbccid Smartcard Reader").
function Ler-Tokens {
    $itens = @()
    foreach ($d in @(Get-PnpDevice -PresentOnly -Class SmartCardReader -ErrorAction SilentlyContinue)) {
        $usb = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_BusReportedDeviceDesc' -ErrorAction SilentlyContinue).Data
        $itens += Classificar-Token $usb $d.FriendlyName $d.Manufacturer
    }
    return $itens
}

function Classificar-Token($usb, $nomeWindows, $fabricante) {
    $texto = "$usb $nomeWindows $fabricante"
    $tipo = $TiposToken | Where-Object { $texto -match $_.Padrao } | Select-Object -First 1
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
    $cert = @(Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue |
        Where-Object { $_.Issuer -match "ICP-Brasil" -and $_.HasPrivateKey } | Sort-Object NotAfter -Descending) | Select-Object -First 1
    if ($cert) {
        $nome = ($cert.GetNameInfo("SimpleName", $false) -split ':')[0]
        $vence = $cert.NotAfter.ToString('dd/MM/yyyy')
        if ($cert.NotAfter -lt (Get-Date)) { Write-Host "   Certificado: $nome - VENCIDO em $vence" -ForegroundColor Red }
        else { Write-Host "   Certificado: $nome - vale ate $vence" -ForegroundColor Gray }
    }
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
    return @("C:\Program Files\Mozilla Firefox", "C:\Program Files (x86)\Mozilla Firefox") |
        Where-Object { Test-Path "$_\firefox.exe" } | Select-Object -First 1
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
    foreach ($base in "$perfil\AppData\Local\Google\Chrome\User Data", "$perfil\AppData\Local\Microsoft\Edge\User Data") {
        if ((Test-Path (Split-Path $base)) -and ($perfis -notcontains "$base\Default")) { $perfis += "$base\Default" }
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

    # Firefox: grava storage.js e habilita keepStorageOnUninstall no prefs.js.
    # Sem keepStorageOnUninstall=true, no primeiro ADDON_INSTALL o Firefox marca a extensao
    # como ja migrada antes de abrir o storage.js (Extension.sys.mjs) e ignora o arquivo.
    $jsonFx = '{"pkcs11":["eTPKCS11.dll","aetpkss1.dll","asepkcs.dll"],"trace":true}'
    foreach ($d in (Get-ChildItem "$perfil\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue)) {
        $dirExt = Join-Path $d.FullName "browser-extension-data\$WebSignerFirefoxId"
        if (Get-ChildItem $dirExt -Filter "storage.js*.migrated" -File -ErrorAction SilentlyContinue) { continue }

        $prefs = Join-Path $d.FullName "prefs.js"
        if (Test-Path $prefs) {
            $textoPrefs = Get-Content $prefs -Raw
            if ($textoPrefs -match '"websigner@softplan_com_br"\s*:\s*\\?"([0-9a-fA-F-]+)\\?"') {
                $uuidFx = $matches[1]
                Get-ChildItem "$($d.FullName)\storage\default" -Filter "moz-extension+++$uuidFx*" -Directory -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            $linhasPrefs = @(Get-Content $prefs | Where-Object {
                $_ -notmatch 'ExtensionStorageIDB\.migrated\.websigner@softplan_com_br' -and
                $_ -notmatch 'extensions\.webextensions\.keepStorageOnUninstall'
            })
            $linhasPrefs += 'user_pref("extensions.webextensions.keepStorageOnUninstall", true);'
            [IO.File]::WriteAllLines($prefs, $linhasPrefs)
        }
        New-Item -ItemType Directory -Path $dirExt -Force | Out-Null
        [IO.File]::WriteAllText("$dirExt\storage.js", $jsonFx)
    }

    Write-Host "Web Signer: toggles (SafeNet, SafeSign, Athena e logs detalhados) ativados."
}

function Aplicar-ExtensaoWebSigner {
    $valorLoja = "$WebSignerChromeId;$ChromeStoreUpdate"
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

# Escreve o policies.json do Firefox com as duas partes do kit:
#   extensao     = Web Signer forcada
#   certificados = usar os certificados do Windows + carregar os modulos dos tokens
# Cada parametro: $true (liga), $false (desliga) ou $null (mantem como esta).
# Assim uma parte nao apaga a outra. Devolve $false se nao houver Firefox.
function Gravar-PoliticaFirefox($extensao, $certificados) {
    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) { return $false }
    $dist = Join-Path $pastaFirefox "distribution"
    $arqPol = Join-Path $dist "policies.json"
    $atual = $(if (Test-Path $arqPol) { Get-Content $arqPol -Raw } else { "" })
    if ($null -eq $extensao)     { $extensao = $atual -like "*$WebSignerFirefoxId*" }
    if ($null -eq $certificados) { $certificados = $atual -like "*ImportEnterpriseRoots*" }

    $pol = @{}
    if ($extensao) {
        $urlXpi = "file:///" + ("$PastaTI\websigner.xpi" -replace '\\', '/')
        $pol.ExtensionSettings = @{ $WebSignerFirefoxId = @{ installation_mode = "force_installed"; install_url = $urlXpi } }
    }
    if ($certificados) {
        $pol.Certificates = @{ ImportEnterpriseRoots = $true }
        $modulos = @{}
        foreach ($nome in $ModulosToken.Keys) { if (Test-Path $ModulosToken[$nome]) { $modulos[$nome] = $ModulosToken[$nome] } }
        if ($modulos.Count) { $pol.SecurityDevices = @{ Add = $modulos } }
    }
    if ($pol.Count -eq 0) {
        Remove-Item $arqPol -Force -ErrorAction SilentlyContinue
        return $true
    }
    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    # guarda o arquivo original (de antes do kit) uma vez so
    if ((Test-Path $arqPol) -and -not (Test-Path "$arqPol.bak")) { Copy-Item $arqPol "$arqPol.bak" -Force }
    # UTF-8 sem BOM (o Firefox exige)
    [IO.File]::WriteAllText($arqPol, (@{ policies = $pol } | ConvertTo-Json -Depth 10))
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
    $meus = @(Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue | Where-Object { $_.Issuer -match "ICP-Brasil" -and $_.HasPrivateKey })
    if ($meus.Count -eq 0) {
        Write-Host "  Nenhum certificado do token apareceu no Windows." -ForegroundColor Red
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

function Remover-ExtensaoWebSigner {
    Remover-ListaForcada "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" $WebSignerChromeId
    Remover-ListaForcada "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" $WebSignerChromeId
    [void](Gravar-PoliticaFirefox $false $null)
    Remove-Item "$PastaTI\websigner.xpi" -Force -ErrorAction SilentlyContinue
    $perfil = Perfil-UsuarioTela
    foreach ($d in (Get-ChildItem "$perfil\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue)) {
        Remove-Item "$($d.FullName)\browser-extension-data\$WebSignerFirefoxId" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  Extensao Web Signer liberada no Chrome, Edge e Firefox (agora pode ser removida)."
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
        Write-Host "   Vai remover: $(($alvo | ForEach-Object { $_.Nome }) -join ', ')" -ForegroundColor Yellow
        if (-not (Perguntar-SN "Confirmar?")) { Write-Host "  Cancelado."; Pausar; continue }

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

    Titulo "1/4 Programas pelo winget"
    $temWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    if (-not $temWinget) {
        Write-Host "winget nao encontrado. Atualize o 'Instalador de Aplicativo' pela Microsoft Store e rode de novo." -ForegroundColor Yellow
    }
    foreach ($p in $ProgramasWinget) {
        if (Test-Instalado $p.Busca) { Write-Host "[ja instalado] $($p.Nome)" -ForegroundColor DarkGray; continue }
        if ($temWinget) {
            $parametros = @("install", "-e", "--id", $p.Id, "--silent", "--source", "winget",
                            "--accept-package-agreements", "--accept-source-agreements")
            if ($p.Versao) { $parametros += @("--version", $p.Versao) }
            Write-Host "Instalando $($p.Nome) $($p.Versao)..."
            & winget @parametros
        }
        # Plano B sem internet: arquivo do pendrive (conferido pela impressao digital)
        if (-not (Test-Instalado $p.Busca) -and $p.Pendrive -and $PastaLocal) {
            $local = Join-Path $PastaLocal $p.Pendrive.Arquivo
            if (Hash-Confere $local $p.Pendrive.Sha256) {
                Write-Host "  Instalando $($p.Nome) pelo arquivo do pendrive..."
                [void](Executar-Instalador $local $p.Pendrive.Argumentos)
            }
        }
        if (-not (Test-Instalado $p.Busca)) {
            Write-Host "  Nao foi possivel instalar $($p.Nome). Confira a internet e se o winget esta atualizado." -ForegroundColor Yellow
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
    Write-Host "Feche e abra os navegadores para a extensao aparecer." -ForegroundColor Cyan
    Write-Host "Log salvo em: $log"
    Stop-Transcript | Out-Null
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
        Write-Host "   [0] Voltar"
        Write-Host ""
        switch (Ler-Opcao @("1", "2", "3", "0")) {
            "1" { Instalar-Windows; $script:CacheToken = $null; Pausar }
            "2" { Menu-Correcoes }
            "3" { Menu-Desinstalar; $script:CacheToken = $null }
            "0" { return }
        }
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
        $politica = (Test-Path $pol) -and ((Get-Content $pol -Raw) -like "*$WebSignerFirefoxId*")
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
        Nome = "Remover extensoes forcadas"
        Descricao = "Tira as politicas de extensao do Chrome, Edge e Firefox (a extensao volta a poder ser removida)."
        Acao = {
            Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" -Recurse -ErrorAction SilentlyContinue
            Remove-Item "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Recurse -ErrorAction SilentlyContinue
            [void](Gravar-PoliticaFirefox $false $null)
            Write-Host "  Politicas removidas. Feche e abra os navegadores." -ForegroundColor Green
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
        $confirma = (Read-Host "   Confirmar? (S/N)").Trim().ToUpper()
        if ($confirma -eq "S") { & $c.Acao } else { Write-Host "  Cancelado." }
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
