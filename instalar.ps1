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
    @{ Nome = "SafeNet (token)"; Id = "Thales.SafeNetAuthenticationClient"; Versao = "10.9.4482.0"; Busca = "SafeNet Authentication Client"
       Pendrive = @{ Arquivo = "safenet.msi"; Argumentos = "/qn /norestart"; Sha256 = "a998da33cab2d70675d5de9a8a114f870f643dba1f676f9586b263030c395e12" } },
    @{ Nome = "Driver do token GD"; Id = "AETEurope.SafeSignICStandard"; Versao = "3.5.3.0"; Busca = "SafeSign"
       Pendrive = @{ Arquivo = "safesign.exe"; Argumentos = '/s /v"/qn /norestart"'; Sha256 = "0dad976c832526f494f665661fb8b47a93c5f9b969bc9b7d5496d6dd87ae6dfe" } },
    @{ Nome = "Web Signer"; Id = "SoftplanSistemas.WebSigner"; Versao = "2.15.0.0"; Busca = "Web Signer"
       Pendrive = @{ Arquivo = "websigner.msi"; Argumentos = "/qn /norestart"; Sha256 = "e66d0df97ff28272d4535b19f1ac3c67b13bc7ab3fb695e27ba72e5a1f4be0a3" } }
)

# Instaladores que NAO estao no winget (ficam no Release do GitHub, ou na pasta "instaladores" do pendrive)
#   Arquivo    = nome exato do arquivo no Release (sem espacos)
#   Sha256     = impressao digital do arquivo. Se o arquivo baixado nao bater, NAO instala.
#                Para gerar: Get-FileHash .\arquivo.exe -Algorithm SHA256
#   Argumentos = parametros de instalacao silenciosa
#   Busca      = trecho do nome em "Aplicativos instalados"
# Ao atualizar um programa: troque o arquivo no Release "instaladores" (mesmo nome)
# e troque Versao e Sha256 aqui.
$InstaladoresKit = @(
    @{ Nome = "PJeOffice Pro";      Versao = "2.5.16u"; Arquivo = "pjeoffice.exe"; Argumentos = "/S";
       Busca = "PJeOffice"; Sha256 = "8237999eff5313607daf53558b4a0b8f3aba4da670c6438ee34eb25120b45bc4" }
)

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
    Write-Host "   -------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Ler-Opcao($validas) {
    while ($true) {
        $op = (Read-Host "   Escolha uma opcao").Trim()
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

function Aplicar-ExtensaoWebSigner {
    $valorLoja = "$WebSignerChromeId;$ChromeStoreUpdate"
    Add-ListaForcada "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" $valorLoja
    Write-Host "Chrome: extensao forcada."
    Add-ListaForcada "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" $valorLoja
    Write-Host "Edge: extensao forcada."

    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) {
        Write-Host "Firefox nao encontrado; politica nao aplicada." -ForegroundColor Yellow
        return
    }
    $xpi = Obter-Arquivo $WebSignerXpi.Arquivo $WebSignerXpi.Sha256
    if (-not $xpi) { return }
    Copy-Item $xpi "$PastaTI\websigner.xpi" -Force
    [void](Gravar-PoliticaFirefox $true $null)
    Write-Host "Firefox: extensao forcada."
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
    Write-Host "   No Mac, abra o Terminal e cole:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   curl -fsSL $UrlScriptMac | bash" -ForegroundColor White
    Write-Host ""
}

function Menu-Instalacao {
    while ($true) {
        Mostrar-Cabecalho
        Write-Host "   INSTALACAO DE PROGRAMAS" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] Windows (este computador)"
        Write-Host "   [2] Mac (mostra o comando para o Terminal)"
        Write-Host "   [0] Voltar"
        Write-Host ""
        switch (Ler-Opcao @("1", "2", "0")) {
            "1" { Instalar-Windows; Pausar }
            "2" { Mostrar-ComandoMac; Pausar }
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

function Verificar-WebSigner {
    $perfil = Perfil-UsuarioTela
    $faltaPolitica = $false
    if (Test-Instalado "Web Signer") { Write-Host "  [OK]     Programa Web Signer instalado" -ForegroundColor Green }
    else { Write-Host "  [FALTA]  Programa Web Signer nao instalado. Use 'Instalacao de programas'." -ForegroundColor Red }

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
        if ($politica -and $baixada) { Write-Host "  [OK]     Extensao no $($n.Nome)" -ForegroundColor Green }
        elseif ($politica) { Write-Host "  [AVISO]  $($n.Nome): extensao configurada, mas ainda nao baixada. Abra o $($n.Nome) e espere 1 minuto." -ForegroundColor Yellow }
        else { Write-Host "  [FALTA]  Extensao no $($n.Nome)" -ForegroundColor Red; $faltaPolitica = $true }
    }
    $pastaFirefox = Pasta-Firefox
    if ($pastaFirefox) {
        $pol = "$pastaFirefox\distribution\policies.json"
        $politica = (Test-Path $pol) -and ((Get-Content $pol -Raw) -like "*$WebSignerFirefoxId*")
        $baixada = [bool](Get-ChildItem "$perfil\AppData\Roaming\Mozilla\Firefox\Profiles\*\extensions\$WebSignerFirefoxId.xpi" -ErrorAction SilentlyContinue)
        if ($politica -and $baixada) { Write-Host "  [OK]     Extensao no Firefox" -ForegroundColor Green }
        elseif ($politica) { Write-Host "  [AVISO]  Firefox: extensao configurada, mas ainda nao baixada. Abra o Firefox." -ForegroundColor Yellow }
        else { Write-Host "  [FALTA]  Extensao no Firefox" -ForegroundColor Red; $faltaPolitica = $true }
    }
    if ($faltaPolitica -and (Perguntar-SN "Aplicar a extensao Web Signer de novo?")) {
        Aplicar-ExtensaoWebSigner
        Write-Host "  Feche e abra os navegadores." -ForegroundColor Cyan
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
    Write-Host "  use 'Limpar cache e cookies' e 'Verificar extensao Web Signer'." -ForegroundColor Green
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
        Nome = "O tribunal esta fora do ar?"
        Descricao = "Testa a internet e os sites dos tribunais, para saber se o problema e daqui ou de la."
        Acao = { [void](Verificar-Tribunais) }
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
        Nome = "Verificar extensao Web Signer"
        Descricao = "Confere o programa e a extensao em cada navegador, e aplica de novo se faltar."
        Acao = { Verificar-WebSigner }
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
        Nome = "Navegador ou PJeOffice travado"
        Descricao = "Fecha Chrome, Edge, Firefox e PJeOffice (salve o que estiver aberto antes)."
        Acao = {
            Fechar-Navegadores
            Get-Process | Where-Object { $_.Name -like "pjeoffice*" -or $_.Path -like "*\PJeOffice*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "  Programas fechados. Pode abrir de novo." -ForegroundColor Green
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
    Write-Host "   [1] Instalacao de programas"
    Write-Host "   [2] Correcao de erros"
    Write-Host "   [3] Sair"
    Write-Host ""
    switch (Ler-Opcao @("1", "2", "3")) {
        "1" { Menu-Instalacao }
        "2" { Menu-Correcoes }
        "3" { Write-Host ""; Write-Host "   Ate logo!" -ForegroundColor DarkYellow; return }
    }
}
