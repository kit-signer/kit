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


