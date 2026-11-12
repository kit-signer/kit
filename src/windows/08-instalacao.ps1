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
    $fxDesativada = $okFx -and [bool](Get-ChildItem "$(Perfil-UsuarioTela)\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue |
        Where-Object { WebSigner-DesativadoFirefox $_.FullName })
    if ($fxDesativada) { $okFx = $false }
    [void]$resultado.Add([pscustomobject]@{ Item = "Extensao no Firefox"; OK = $okFx; Detalhe = $(if ($fxDesativada) { "desativada" } elseif ($okFx) { "politica aplicada" } else { "politica ausente" }) })
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
            -ArgumentList "-sL --fail --retry 5 --retry-delay 3 $($script:CurlArgsExtra -join ' ') -o `"$parcial`" `"$UrlArquivos/$($a.Arquivo)`""
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
        # -1978335215 (0x8A150011) = impressao digital do instalador nao confere. Acontece
        # muito com o Chrome: o Google troca o arquivo no mesmo link antes do catalogo do
        # winget ser atualizado. Tentar de novo baixaria o mesmo arquivo (163 MB) e daria o
        # mesmo erro, entao nesse caso vai direto para o plano B.
        $erroHash = -1978335215
        if (-not (Test-Instalado $p.Busca) -and $p.Escopo -and $codigo -ne $erroHash) {
            # alguns pacotes nao tem instalador "para a maquina toda": tenta sem escolher
            & $script:Winget @base
            $codigo = $LASTEXITCODE
        }
        if (Test-Instalado $p.Busca) { return }
        if ($codigo -eq $erroHash) {
            Write-Host "  O winget recusou o instalador (impressao digital desatualizada no catalogo). Indo para o plano B." -ForegroundColor Yellow
        } else {
            Write-Host "  O winget nao conseguiu instalar (codigo $codigo)." -ForegroundColor Yellow
        }
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
    Baixar-Url $url $destino
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

