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


