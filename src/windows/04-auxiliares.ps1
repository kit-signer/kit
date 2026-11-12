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
    Baixar-Url $url $destino
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

