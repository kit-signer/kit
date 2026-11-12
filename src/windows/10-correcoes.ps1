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
        $desativada = [bool](Get-ChildItem "$perfil\AppData\Roaming\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue |
            Where-Object { WebSigner-DesativadoFirefox $_.FullName })
        $lista += [pscustomobject]@{ Nome = "Firefox"; Estado = $(if ($politica -and $desativada) { "DESATIVADA" } elseif ($politica -and $baixada) { "OK" } elseif ($politica) { "PENDENTE" } else { "FALTA" }) }
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
            "DESATIVADA" { Write-Host "  [AVISO]  $($n.Nome): extensao instalada, mas desativada. O kit vai reativar." -ForegroundColor Yellow }
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


