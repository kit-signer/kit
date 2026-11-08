# =====================================================================
#  instalar.ps1 - Kit de TI da CAAAL
#
#  Uso pela internet (CMD ou PowerShell):
#    powershell -c "irm https://raw.githubusercontent.com/kit-signer/kit/main/instalar.ps1 | Out-String | iex"
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

# Programas instalados pelo winget (baixa direto da internet)
#   Busca = trecho do nome que aparece em "Aplicativos instalados"
$ProgramasWinget = @(
    @{ Nome = "WinRAR";          Id = "RARLab.WinRAR";   Busca = "WinRAR" },
    @{ Nome = "Google Chrome";   Id = "Google.Chrome";   Busca = "Google Chrome" },
    @{ Nome = "Mozilla Firefox"; Id = "Mozilla.Firefox"; Busca = "Mozilla Firefox" }
)

# Instaladores do kit (ficam no Release do GitHub, ou na pasta "instaladores" do pendrive)
#   Arquivo    = nome exato do arquivo no Release (sem espacos)
#   Sha256     = impressao digital do arquivo. Se o arquivo baixado nao bater, NAO instala.
#                Para gerar: Get-FileHash .\arquivo.exe -Algorithm SHA256
#   Argumentos = parametros de instalacao silenciosa
#   Busca      = trecho do nome em "Aplicativos instalados"
# Ao atualizar um programa: suba o arquivo novo com o MESMO nome num Release novo
# e troque Versao e Sha256 aqui.
$InstaladoresKit = @(
    @{ Nome = "PJeOffice Pro";      Versao = "2.5.16u"; Arquivo = "pjeoffice.exe"; Argumentos = "/S";
       Busca = "PJeOffice"; Sha256 = "8237999eff5313607daf53558b4a0b8f3aba4da670c6438ee34eb25120b45bc4" },
    @{ Nome = "SafeNet (token)";    Versao = "10.7";    Arquivo = "safenet.msi";   Argumentos = "/qn /norestart";
       Busca = "SafeNet Authentication Client"; Sha256 = "a998da33cab2d70675d5de9a8a114f870f643dba1f676f9586b263030c395e12" },
    @{ Nome = "Driver do token GD"; Versao = "3.0.124"; Arquivo = "safesign.exe";  Argumentos = '/s /v"/qn /norestart"';
       Busca = "SafeSign"; Sha256 = "0dad976c832526f494f665661fb8b47a93c5f9b969bc9b7d5496d6dd87ae6dfe" },
    @{ Nome = "Web Signer";         Versao = "2.15.0";  Arquivo = "websigner.msi"; Argumentos = "/qn /norestart";
       Busca = "Web Signer"; Sha256 = "e66d0df97ff28272d4535b19f1ac3c67b13bc7ab3fb695e27ba72e5a1f4be0a3" }
)

# Extensao Web Signer (Softplan)
$WebSignerChromeId  = "bbafmabaelnnkondpfpjmdklbmfnbmol"   # mesmo ID no Chrome e no Edge
$ChromeStoreUpdate  = "https://clients2.google.com/service/update2/crx"
$WebSignerFirefoxId = "websigner@softplan_com_br"
$WebSignerXpi       = @{ Arquivo = "websigner.xpi"; Sha256 = "2c16afbfb80dff721e2796ffae262093a8558d68ac15b77af5f8169085ea5c6a" }

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
    if ($ArquivoDoScript) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ArquivoDoScript`""
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $UrlScript | Out-String | iex`""
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
    $urlXpi = "file:///" + ("$PastaTI\websigner.xpi" -replace '\\', '/')
    $dist = Join-Path $pastaFirefox "distribution"
    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    $arqPol = Join-Path $dist "policies.json"
    if (Test-Path $arqPol) { Copy-Item $arqPol "$arqPol.bak" -Force }
    $politica = @{ policies = @{ ExtensionSettings = @{
        $WebSignerFirefoxId = @{ installation_mode = "force_installed"; install_url = $urlXpi } } } }
    # UTF-8 sem BOM (o Firefox exige)
    [IO.File]::WriteAllText($arqPol, ($politica | ConvertTo-Json -Depth 10))
    Write-Host "Firefox: extensao forcada."
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
        if (-not $temWinget) { continue }
        Write-Host "Instalando $($p.Nome)..."
        winget install -e --id $p.Id --silent --source winget --accept-package-agreements --accept-source-agreements
    }

    Titulo "2/4 Programas do kit"
    foreach ($p in $InstaladoresKit) {
        if (Test-Instalado $p.Busca) { Write-Host "[ja instalado] $($p.Nome)" -ForegroundColor DarkGray; continue }
        $arquivo = Obter-Arquivo $p.Arquivo $p.Sha256
        if (-not $arquivo) { continue }
        Write-Host "Instalando $($p.Nome) $($p.Versao)..."
        if ($arquivo -like "*.msi") {
            $proc = Start-Process msiexec.exe -ArgumentList "/i `"$arquivo`" $($p.Argumentos)" -Wait -PassThru
        } else {
            $proc = Start-Process $arquivo -ArgumentList $p.Argumentos -Wait -PassThru
        }
        if ($proc.ExitCode -notin 0, 3010) {
            Write-Host "  Codigo de saida $($proc.ExitCode) - confira os parametros silenciosos." -ForegroundColor Yellow
        }
    }

    Titulo "3/4 Extensao Web Signer"
    Aplicar-ExtensaoWebSigner

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
# Para adicionar uma correcao: copie um bloco @{ ... } e mude Nome, Descricao e Acao.

$Correcoes = @(
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
        Nome = "Extensao Web Signer sumiu"
        Descricao = "Aplica de novo a extensao no Chrome, Edge e Firefox."
        Acao = { Aplicar-ExtensaoWebSigner; Write-Host "  Feche e abra os navegadores." -ForegroundColor Cyan }
    },
    @{
        Nome = "Navegador ou PJeOffice travado"
        Descricao = "Fecha Chrome, Edge, Firefox e PJeOffice (salve o que estiver aberto antes)."
        Acao = {
            $nomes = "chrome", "msedge", "firefox", "pjeoffice*"
            Get-Process -Name $nomes -ErrorAction SilentlyContinue | Stop-Process -Force
            Write-Host "  Programas fechados. Pode abrir de novo." -ForegroundColor Green
        }
    },
    @{
        Nome = "Remover extensoes forcadas"
        Descricao = "Tira as politicas de extensao do Chrome, Edge e Firefox (desfaz o passo 3 da instalacao)."
        Acao = {
            Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" -Recurse -ErrorAction SilentlyContinue
            Remove-Item "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Recurse -ErrorAction SilentlyContinue
            $pastaFirefox = Pasta-Firefox
            if ($pastaFirefox) { Remove-Item "$pastaFirefox\distribution\policies.json" -ErrorAction SilentlyContinue }
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
