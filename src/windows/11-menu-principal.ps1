# =========================== MENU ====================================

while ($true) {
    Mostrar-Cabecalho
    Write-Host "   Qual computador voce vai configurar?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1] Windows   (este computador)"
    Write-Host "   [2] Mac"
    Write-Host "   [0] Sair"
    Write-Host ""
    switch (Ler-Opcao @("1", "2", "0")) {
        "1" { Menu-Windows }
        "2" { Mostrar-ComandoMac; Pausar }
        "0" { Limpar-Historico; Write-Host ""; Write-Host "   Ate logo!" -ForegroundColor DarkYellow; return }
    }
}
