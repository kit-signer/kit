# ===================== FAVORITOS NOS NAVEGADORES =====================

function Adicionar-FavoritosChrome {
    $perfil = Perfil-UsuarioTela
    $baseChrome = "$perfil\AppData\Local\Google\Chrome\User Data"
    $exeChrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$perfil\AppData\Local\Google\Chrome\Application\chrome.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $exeChrome -and -not (Test-Path $baseChrome)) {
        Write-Host "  Google Chrome nao encontrado nesta maquina." -ForegroundColor Yellow
        return
    }
    $perfisCr = @()
    if (Test-Path $baseChrome) {
        $perfisCr = @(Get-ChildItem $baseChrome -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" -or (Test-Path "$($_.FullName)\Preferences") -or (Test-Path "$($_.FullName)\Bookmarks") } |
            ForEach-Object { $_.FullName })
    }
    if ($perfisCr.Count -eq 0) { $perfisCr = @("$baseChrome\Default") }

    $utf8SemBom = New-Object Text.UTF8Encoding($false)
    $agoraCr = [string]([int64](([DateTime]::UtcNow - [DateTime]::new(1601, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalMilliseconds * 1000))

    foreach ($p in ($perfisCr | Select-Object -Unique)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        $arqFav = Join-Path $p "Bookmarks"
        $dados = $null
        if (Test-Path $arqFav) {
            try { $dados = [IO.File]::ReadAllText($arqFav, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $dados = $null }
        }
        if (-not $dados -or -not $dados.roots -or -not $dados.roots.bookmark_bar) {
            $dados = [pscustomobject]@{
                roots = [pscustomobject]@{
                    bookmark_bar = [pscustomobject]@{
                        children = @()
                        date_added = $agoraCr
                        date_last_used = "0"
                        date_modified = $agoraCr
                        guid = "0bc5d13f-2cba-5d74-951f-3f233fe6c908"
                        id = "1"
                        name = "Barra de favoritos"
                        type = "folder"
                    }
                    other = [pscustomobject]@{
                        children = @()
                        date_added = $agoraCr
                        date_last_used = "0"
                        date_modified = "0"
                        guid = "82b081ec-3dd3-529c-8475-ab6c344590dd"
                        id = "2"
                        name = "Outros favoritos"
                        type = "folder"
                    }
                    synced = [pscustomobject]@{
                        children = @()
                        date_added = $agoraCr
                        date_last_used = "0"
                        date_modified = "0"
                        guid = "4cf2e351-0e85-532b-bb37-df045d8f8d0f"
                        id = "3"
                        name = "Dispositivos moveis"
                        type = "folder"
                    }
                }
                version = 1
            }
        }

        $textoAtual = ($dados | ConvertTo-Json -Depth 20 -Compress)
        $maxId = 10
        foreach ($m in [regex]::Matches($textoAtual, '"id"\s*:\s*"(\d+)"')) {
            $v = [int]$m.Groups[1].Value
            if ($v -gt $maxId) { $maxId = $v }
        }

        $atuais = @($dados.roots.bookmark_bar.children)
        $urlsExistentes = @($atuais | Where-Object { $_.url } | ForEach-Object { $_.url })
        $novos = 0
        foreach ($f in $Favoritos) {
            if ($urlsExistentes -contains $f.Url) { continue }
            $maxId++
            $atuais += [pscustomobject]@{
                date_added = $agoraCr
                date_last_used = "0"
                guid = [guid]::NewGuid().ToString()
                id = "$maxId"
                name = $f.Nome
                type = "url"
                url = $f.Url
            }
            $novos++
        }
        $dados.roots.bookmark_bar.children = $atuais
        $dados.roots.bookmark_bar.date_modified = $agoraCr
        if ($dados.PSObject.Properties["checksum"]) { [void]$dados.PSObject.Properties.Remove("checksum") }
        Remove-Item "$arqFav.bak" -Force -ErrorAction SilentlyContinue
        [IO.File]::WriteAllText($arqFav, ($dados | ConvertTo-Json -Depth 20), $utf8SemBom)

        # Mostra a barra de favoritos em todas as abas
        $arqPref = Join-Path $p "Preferences"
        if (Test-Path $arqPref) {
            $rawPref = [IO.File]::ReadAllText($arqPref, [Text.Encoding]::UTF8)
            if ($rawPref -match '"bookmark_bar"\s*:\s*\{') {
                if ($rawPref -match '"show_on_all_tabs"\s*:\s*(true|false)') {
                    $rawPref = [regex]::Replace($rawPref, '"show_on_all_tabs"\s*:\s*false', '"show_on_all_tabs":true')
                } else {
                    $rawPref = [regex]::Replace($rawPref, '"bookmark_bar"\s*:\s*\{', '"bookmark_bar":{"show_on_all_tabs":true,')
                }
            } elseif ($rawPref -match '^\s*\{\s*\}') {
                $rawPref = '{"bookmark_bar":{"show_on_all_tabs":true}}'
            } else {
                $rawPref = [regex]::Replace($rawPref, '^\s*\{', '{"bookmark_bar":{"show_on_all_tabs":true},')
            }
            [IO.File]::WriteAllText($arqPref, $rawPref, $utf8SemBom)
        } else {
            [IO.File]::WriteAllText($arqPref, '{"bookmark_bar":{"show_on_all_tabs":true}}', $utf8SemBom)
        }

        Write-Host ("  [OK] Chrome ({0}): {1} favoritos adicionados na barra de favoritos ({2} no total)." -f (Split-Path $p -Leaf), $novos, $Favoritos.Count) -ForegroundColor Green
    }
}

function Adicionar-FavoritosFirefox {
    if (-not (Pasta-Firefox)) {
        Write-Host "  Mozilla Firefox nao encontrado nesta maquina." -ForegroundColor Yellow
        return
    }
    [void](Gravar-PoliticaFirefox $null $null $true)
    $perfil = Perfil-UsuarioTela
    $perfisFx = @(Garantir-PerfilFirefox $perfil)
    foreach ($d in $perfisFx) {
        foreach ($nomeArq in "prefs.js", "user.js") {
            $arq = Join-Path $d.FullName $nomeArq
            if ($nomeArq -eq "prefs.js" -and -not (Test-Path $arq)) { continue }
            $linhas = @()
            if (Test-Path $arq) {
                $linhas = @(Get-Content $arq | Where-Object { $_ -notmatch 'browser\.toolbars\.bookmarks\.visibility' })
            }
            $linhas += 'user_pref("browser.toolbars.bookmarks.visibility", "always");'
            [IO.File]::WriteAllLines($arq, ($linhas -as [string[]]))
        }
    }
    Write-Host ("  [OK] Firefox: {0} favoritos adicionados na barra de favoritos." -f $Favoritos.Count) -ForegroundColor Green
}

function Menu-Favoritos {
    while ($true) {
        Mostrar-Cabecalho
        Write-Host "   ADICIONAR FAVORITOS DOS TRIBUNAIS" -ForegroundColor Cyan
        Write-Host "   Adiciona na barra de favoritos sem apagar os favoritos que ja existem:" -ForegroundColor DarkGray
        Write-Host "   $(($Favoritos | ForEach-Object { $_.Nome }) -join ', ')" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   Em qual navegador voce quer adicionar os favoritos?"
        Write-Host ""
        Write-Host "   [1] Google Chrome"
        Write-Host "   [2] Mozilla Firefox"
        Write-Host "   [3] Nos dois (Chrome e Firefox)"
        Write-Host "   [0] Voltar"
        Write-Host ""
        $op = Ler-Opcao @("1", "2", "3", "0")
        if ($op -eq "0") { return }
        Fechar-Navegadores
        if ($op -in "1", "3") {
            Titulo "Google Chrome"
            Adicionar-FavoritosChrome
        }
        if ($op -in "2", "3") {
            Titulo "Mozilla Firefox"
            Adicionar-FavoritosFirefox
        }
        Pausar
    }
}


