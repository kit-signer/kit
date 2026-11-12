# ===================== CERTIFICADOS (ICP-BRASIL) =====================

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


