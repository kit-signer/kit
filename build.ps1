# =====================================================================
#  build.ps1 - Monta o instalar.ps1 e o instalar.sh a partir da pasta src
#
#  O kit e baixado pela internet como UM arquivo so (irm ... | iex e
#  curl ... | bash), entao o codigo fica organizado em partes dentro de
#  src\windows e src\mac, e este script junta as partes, na ordem do
#  numero do nome (01-, 02-, ...), no instalar.ps1 e no instalar.sh.
#
#  Uso (na pasta do kit):
#    powershell -ExecutionPolicy Bypass -File .\build.ps1
#  Para so conferir se o instalar.ps1/.sh estao em dia (sem gravar):
#    powershell -ExecutionPolicy Bypass -File .\build.ps1 -Verificar
#
#  Arquivo propositalmente sem acentos (o PowerShell 5.1 le acentos errado).
# =====================================================================

param([switch]$Verificar)

$ErrorActionPreference = "Stop"
$raiz = $PSScriptRoot

$saidas = @(
    @{ Pasta = "src\windows"; Filtro = "*.ps1"; Saida = "instalar.ps1" },
    @{ Pasta = "src\mac";     Filtro = "*.sh";  Saida = "instalar.sh" }
)

# Tira o CR (byte 13) do fim de linha do Windows
function Sem-CR([byte[]]$b) {
    $l = New-Object System.Collections.Generic.List[byte] $b.Length
    foreach ($x in $b) { if ($x -ne 13) { $l.Add($x) } }
    return ,$l.ToArray()
}

$problemas = 0
foreach ($s in $saidas) {
    $pasta = Join-Path $raiz $s.Pasta
    $partes = @(Get-ChildItem -Path $pasta -Filter $s.Filtro -File | Sort-Object Name)
    if (-not $partes) { throw "Nenhuma parte encontrada em $($s.Pasta)" }

    # Junta os bytes de cada parte (sem mexer em acentos) e tira o CR do Windows:
    # o instalar.sh precisa de LF, e o instalar.ps1 sempre foi LF.
    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($p in $partes) {
        $bytes.AddRange((Sem-CR ([IO.File]::ReadAllBytes($p.FullName))))
        if ($bytes.Count -and $bytes[$bytes.Count - 1] -ne 10) { $bytes.Add(10) }
    }
    $novo = $bytes.ToArray()
    $destino = Join-Path $raiz $s.Saida

    $igual = $false
    if (Test-Path $destino) {
        $atual = Sem-CR ([IO.File]::ReadAllBytes($destino))
        $igual = [Convert]::ToBase64String($atual) -eq [Convert]::ToBase64String($novo)
    }

    if ($Verificar) {
        if ($igual) { Write-Host "[OK] $($s.Saida) esta em dia com $($s.Pasta)." -ForegroundColor Green }
        else {
            Write-Host "[DIFERENTE] $($s.Saida) nao bate com $($s.Pasta). Rode o build.ps1 e faca o commit." -ForegroundColor Red
            $problemas++
        }
        continue
    }

    [IO.File]::WriteAllBytes($destino, $novo)
    Write-Host "$($s.Saida): $($partes.Count) partes juntadas." -ForegroundColor Green
}

# Confere a sintaxe do instalar.ps1 gerado (nao executa nada)
$erros = $null
[void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz "instalar.ps1"), [ref]$null, [ref]$erros)
if ($erros) {
    Write-Host "[ERRO DE SINTAXE] no instalar.ps1:" -ForegroundColor Red
    $erros | ForEach-Object { Write-Host "  linha $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red }
    $problemas++
} else {
    Write-Host "[OK] instalar.ps1 sem erro de sintaxe." -ForegroundColor Green
}

if ($problemas) { exit 1 }
