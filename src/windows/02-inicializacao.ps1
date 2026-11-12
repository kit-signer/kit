[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# O curl do Windows verifica se o certificado HTTPS do site foi revogado. Em redes que
# bloqueiam o servidor de revogacao (proxy/firewall), ele falha com
# CRYPT_E_REVOCATION_OFFLINE e nao baixa nada. Com --ssl-revoke-best-effort ele so pula
# a verificacao quando o servidor de revogacao esta fora do ar (certificado revogado
# continua bloqueado). Curl antigo (antes do 7.70) nao conhece a opcao, entao testa antes.
$script:CurlArgsExtra = @()
if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    $ajudaCurl = (& curl.exe --help all 2>$null) -join "`n"
    if ($ajudaCurl -match "ssl-revoke-best-effort") { $script:CurlArgsExtra = @("--ssl-revoke-best-effort") }
}

# Baixa uma URL: tenta o curl; se falhar, tenta o Invoke-WebRequest (que nao depende do
# servidor de revogacao). A conferencia (SHA256 ou assinatura) e feita por quem chama.
function Baixar-Url($url, $destino) {
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --fail --retry 5 --retry-delay 3 $script:CurlArgsExtra -# -o $destino $url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $destino)) { return }
        Write-Host "  O curl nao conseguiu baixar (codigo $LASTEXITCODE). Tentando outro jeito..." -ForegroundColor Yellow
    }
    Remove-Item $destino -Force -ErrorAction SilentlyContinue
    try { Invoke-WebRequest -Uri $url -OutFile $destino -UseBasicParsing -ErrorAction Stop } catch { }
}

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


