# ===================== NAVEGADORES E WEB SIGNER ======================

function Pasta-Firefox {
    # tambem a instalacao "so do usuario" (AppData\Local), que o winget as vezes escolhe
    $perfil = Perfil-UsuarioTela
    return @("C:\Program Files\Mozilla Firefox", "C:\Program Files (x86)\Mozilla Firefox", "$perfil\AppData\Local\Mozilla Firefox") |
        Where-Object { Test-Path "$_\firefox.exe" } | Select-Object -First 1
}

# Garante que o Firefox ja tenha pasta de perfil criada, mesmo se acabou de ser instalado
# e nunca foi aberto na maquina (evita ter que abrir a tela de introducao e rodar o kit 2 vezes).
function Garantir-PerfilFirefox($perfil) {
    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) { return @() }
    $baseFx = "$perfil\AppData\Roaming\Mozilla\Firefox"
    $perfisFx = @(Get-ChildItem "$baseFx\Profiles" -Directory -ErrorAction SilentlyContinue)
    if ($perfisFx.Count -eq 0 -and $perfil -eq $env:USERPROFILE) {
        try {
            $proc = Start-Process "$pastaFirefox\firefox.exe" -ArgumentList "-headless" -WindowStyle Hidden -PassThru -ErrorAction Stop
            for ($i = 0; $i -lt 16; $i++) {
                Start-Sleep -Milliseconds 500
                $perfisFx = @(Get-ChildItem "$baseFx\Profiles" -Directory -ErrorAction SilentlyContinue)
                if ($perfisFx.Count -gt 0) { break }
            }
            if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
            Fechar-Navegadores
        } catch { }
    }
    $perfisFx = @(Get-ChildItem "$baseFx\Profiles" -Directory -ErrorAction SilentlyContinue)
    if ($perfisFx.Count -eq 0) {
        $novoPerfil = "$baseFx\Profiles\padrao.default-release"
        New-Item -ItemType Directory -Path $novoPerfil -Force | Out-Null
        $utf8SemBom = New-Object Text.UTF8Encoding($false)
        $installsIni = "[308046B0AF4A39CB]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n`r`n[E7CF176E110C211B]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n"
        $profilesIni = "[Install308046B0AF4A39CB]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n`r`n[InstallE7CF176E110C211B]`r`nDefault=Profiles/padrao.default-release`r`nLocked=1`r`n`r`n[Profile0]`r`nName=default-release`r`nIsRelative=1`r`nPath=Profiles/padrao.default-release`r`nDefault=1`r`n`r`n[General]`r`nStartWithLastProfile=1`r`nVersion=2`r`n"
        [IO.File]::WriteAllText("$baseFx\installs.ini", $installsIni, $utf8SemBom)
        [IO.File]::WriteAllText("$baseFx\profiles.ini", $profilesIni, $utf8SemBom)
        $perfisFx = @(Get-Item $novoPerfil)
    }
    return $perfisFx
}

# Ativa automaticamente os toggles internos da extensao Web Signer:
#   - Cripto Dispositivos (PKCS #11): Tokens SafeNet, Dispositivos SafeSign AET, Smartcards Athena IDProtect
#   - Avancadas: Habilitar logs detalhados (trace = true)
function Configurar-TogglesWebSigner {
    $perfil = Perfil-UsuarioTela
    Fechar-Navegadores

    # LevelDB (MANIFEST-000001 + 000003.log) com:
    #   pkcs11 = ["eTPKCS11.dll","aetpkss1.dll","asepkcs.dll"]
    #   trace  = true
    $manifestB64 = "lXy5xSIAAQEabGV2ZWxkYi5CeXRld2lzZUNvbXBhcmF0b3ICAAMCBAA="
    $logWinB64   = "O4Mwm04AAQEAAAAAAAAAAgAAAAEGcGtjczExLVsiZVRQS0NTMTEuZGxsIiwiYWV0cGtzczEuZGxsIiwiYXNlcGtjcy5kbGwiXQEFdHJhY2UEdHJ1ZQ=="

    $perfis = @(Pastas-PerfisChromium $perfil)
    # Navegador recem-instalado ainda nao tem perfil (so cria ao abrir pela primeira vez).
    # Cria o perfil "Default" para os toggles ja estarem la quando ele abrir.
    $navegadores = @(
        @{ Base = "$perfil\AppData\Local\Google\Chrome\User Data"; Exe = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$perfil\AppData\Local\Google\Chrome\Application\chrome.exe" },
        @{ Base = "$perfil\AppData\Local\Microsoft\Edge\User Data"; Exe = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" }
    )
    foreach ($n in $navegadores) {
        $instalado = [bool]($n.Exe | Where-Object { Test-Path $_ })
        if (($instalado -or (Test-Path $n.Base)) -and ($perfis -notcontains "$($n.Base)\Default")) { $perfis += "$($n.Base)\Default" }
    }

    foreach ($p in ($perfis | Select-Object -Unique)) {
        $dirDb = Join-Path $p "Local Extension Settings\$WebSignerChromeId"
        $jaConfigurado = Get-ChildItem $dirDb -Include *.log, *.ldb -File -ErrorAction SilentlyContinue |
            Where-Object {
                $txt = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($_.FullName))
                $txt -match 'eTPKCS11\.dll' -and $txt -match 'aetpkss1\.dll' -and $txt -match 'asepkcs\.dll' -and $txt -match 'trace'
            }
        if ($jaConfigurado) { continue }

        New-Item -ItemType Directory -Path $dirDb -Force | Out-Null
        Remove-Item "$dirDb\*" -Force -ErrorAction SilentlyContinue
        [IO.File]::WriteAllBytes("$dirDb\MANIFEST-000001", [Convert]::FromBase64String($manifestB64))
        [IO.File]::WriteAllBytes("$dirDb\CURRENT", [Text.Encoding]::ASCII.GetBytes("MANIFEST-000001`n"))
        [IO.File]::WriteAllBytes("$dirDb\000003.log", [Convert]::FromBase64String($logWinB64))
    }

    # Firefox: grava storage.js e habilita keepStorageOnUninstall no user.js/prefs.js e policies.json.
    # Sem keepStorageOnUninstall=true, no primeiro ADDON_INSTALL o Firefox marca a extensao
    # como ja migrada antes de abrir o storage.js (Extension.sys.mjs) e ignora o arquivo.
    $jsonFx = '{"pkcs11":["eTPKCS11.dll","aetpkss1.dll","asepkcs.dll"],"trace":true}'
    $pastaFirefox = Pasta-Firefox
    $perfisFx = @(Garantir-PerfilFirefox $perfil)
    $prefsExtrasFx = @(
        'user_pref("extensions.webextensions.keepStorageOnUninstall", true);',
        'user_pref("browser.aboutwelcome.enabled", false);',
        'user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);',
        'user_pref("termsofuse.acceptedVersion", 999);',
        'user_pref("termsofuse.acceptedDate", "1740000000000");'
    )
    $regexLimparFx = 'ExtensionStorageIDB\.migrated\.websigner@softplan_com_br|extensions\.webextensions\.keepStorageOnUninstall|browser\.aboutwelcome\.enabled|datareporting\.policy\.dataSubmissionPolicyBypassNotification|termsofuse\.accepted'

    foreach ($d in $perfisFx) {
        $dirExt = Join-Path $d.FullName "browser-extension-data\$WebSignerFirefoxId"
        $arqXpiPerfil = Join-Path $d.FullName "extensions\$WebSignerFirefoxId.xpi"
        $jaMigrado = [bool](Get-ChildItem $dirExt -Filter "storage.js*.migrated" -File -ErrorAction SilentlyContinue)
        if ($jaMigrado -and (Test-Path $arqXpiPerfil)) { continue }

        $prefs = Join-Path $d.FullName "prefs.js"
        if (Test-Path $prefs) {
            $textoPrefs = Get-Content $prefs -Raw
            if ($textoPrefs -match '"websigner@softplan_com_br"\s*:\s*\\?"([0-9a-fA-F-]+)\\?"') {
                $uuidFx = $matches[1]
                Get-ChildItem "$($d.FullName)\storage\default" -Filter "moz-extension+++$uuidFx*" -Directory -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            $linhasPrefs = @(Get-Content $prefs | Where-Object { $_ -notmatch $regexLimparFx })
            $linhasPrefs += $prefsExtrasFx
            [IO.File]::WriteAllLines($prefs, ($linhasPrefs -as [string[]]))
        }
        $userJs = Join-Path $d.FullName "user.js"
        $linhasUser = @()
        if (Test-Path $userJs) {
            $linhasUser = @(Get-Content $userJs | Where-Object { $_ -notmatch $regexLimparFx })
        }
        $linhasUser += $prefsExtrasFx
        [IO.File]::WriteAllLines($userJs, ($linhasUser -as [string[]]))
        New-Item -ItemType Directory -Path $dirExt -Force | Out-Null
        Remove-Item "$dirExt\storage.js*" -Force -ErrorAction SilentlyContinue
        [IO.File]::WriteAllText("$dirExt\storage.js", $jsonFx)

        # Inicializa o Firefox em modo invisivel (-headless) para ja instalar o websigner.xpi
        # e migrar o storage.js na primeira instalacao, sem precisar abrir a tela de introducao.
        if ($pastaFirefox -and (Test-Path "$PastaTI\websigner.xpi")) {
            try {
                $procFx = Start-Process "$pastaFirefox\firefox.exe" -ArgumentList "-headless -no-remote -profile `"$($d.FullName)`"" -WindowStyle Hidden -PassThru -ErrorAction Stop
                for ($i = 0; $i -lt 24; $i++) {
                    Start-Sleep -Milliseconds 500
                    $temXpi = Test-Path $arqXpiPerfil
                    $temMig = [bool](Get-ChildItem $dirExt -Filter "storage.js*.migrated" -File -ErrorAction SilentlyContinue)
                    if ($temXpi -and $temMig) { break }
                }
                if (-not $procFx.HasExited) { Stop-Process -Id $procFx.Id -Force -ErrorAction SilentlyContinue }
                Start-Sleep -Milliseconds 500
                Remove-Item "$($d.FullName)\parent.lock" -Force -ErrorAction SilentlyContinue
            } catch { }
        }
    }

    Write-Host "Web Signer: toggles (SafeNet, SafeSign, Athena e logs detalhados) ativados."
}

function Aplicar-ExtensaoWebSigner {
    $valorLoja = "$WebSignerChromeId;$ChromeStoreUpdate"
    # se a extensao tinha sido excluida antes (modo "removed"), tira essa regra
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Google\Chrome" $null
    Definir-ModoExtensaoChromium "HKLM:\SOFTWARE\Policies\Microsoft\Edge" $null
    Add-ListaForcada "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" $valorLoja
    Write-Host "Chrome: extensao forcada."
    Add-ListaForcada "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" $valorLoja
    Write-Host "Edge: extensao forcada."

    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) {
        Write-Host "Firefox nao encontrado; politica nao aplicada." -ForegroundColor Yellow
    } else {
        $xpi = Obter-Arquivo $WebSignerXpi.Arquivo $WebSignerXpi.Sha256
        if ($xpi) {
            Copy-Item $xpi "$PastaTI\websigner.xpi" -Force
            [void](Gravar-PoliticaFirefox $true $null)
            Write-Host "Firefox: extensao forcada."
        }
    }
    Configurar-TogglesWebSigner
}

# Escreve o policies.json do Firefox com as partes do kit:
#   extensao     = Web Signer forcada
#   certificados = usar os certificados do Windows + carregar os modulos dos tokens
#   favoritos    = sites dos tribunais na barra de favoritos
# Cada parametro: $true (liga), $false (desliga) ou $null (mantem como esta).
# A extensao aceita tambem "bloqueada": o Firefox remove a extensao e nao deixa reinstalar
# (usado ao desinstalar o Web Signer; instalar de novo pelo kit volta para forcada).
# Assim uma parte nao apaga a outra. Devolve $false se nao houver Firefox.
function Gravar-PoliticaFirefox($extensao, $certificados, $favoritos = $null) {
    $pastaFirefox = Pasta-Firefox
    if (-not $pastaFirefox) { return $false }
    $dist = Join-Path $pastaFirefox "distribution"
    $arqPol = Join-Path $dist "policies.json"
    $atual = $(if (Test-Path $arqPol) { Get-Content $arqPol -Raw } else { "" })
    if ($null -eq $extensao) {
        if ($atual -like "*$WebSignerFirefoxId*" -and $atual -like "*force_installed*") { $extensao = $true }
        elseif ($atual -like "*$WebSignerFirefoxId*" -and $atual -like "*blocked*") { $extensao = "bloqueada" }
        else { $extensao = $false }
    }
    if ($null -eq $certificados) { $certificados = $atual -like "*ImportEnterpriseRoots*" }
    if ($null -eq $favoritos) { $favoritos = $atual -like '*"Bookmarks"*' }

    $pol = @{}
    # cuidado: no PowerShell "$true -eq 'texto'" da verdadeiro, por isso confere o tipo
    if ($extensao -is [string] -and $extensao -eq "bloqueada") {
        $pol.ExtensionSettings = @{ $WebSignerFirefoxId = @{ installation_mode = "blocked" } }
    } elseif ($extensao -is [bool] -and $extensao) {
        $urlXpi = "file:///" + ("$PastaTI\websigner.xpi" -replace '\\', '/')
        $pol.ExtensionSettings = @{ $WebSignerFirefoxId = @{ installation_mode = "force_installed"; install_url = $urlXpi } }
        $pol.Preferences = @{
            "extensions.webextensions.keepStorageOnUninstall" = @{ Value = $true; Status = "default" }
            "browser.aboutwelcome.enabled" = @{ Value = $false; Status = "default" }
            "datareporting.policy.dataSubmissionPolicyBypassNotification" = @{ Value = $true; Status = "default" }
        }
    }
    if ($certificados) {
        $pol.Certificates = @{ ImportEnterpriseRoots = $true }
        $modulos = @{}
        foreach ($nome in $ModulosToken.Keys) { if (Test-Path $ModulosToken[$nome]) { $modulos[$nome] = $ModulosToken[$nome] } }
        if ($modulos.Count) { $pol.SecurityDevices = @{ Add = $modulos } }
    }
    if ($favoritos) {
        $pol.DisplayBookmarksToolbar = "always"
        $pol.Bookmarks = @($Favoritos | ForEach-Object {
            @{ Title = $_.Nome; URL = $_.Url; Placement = "toolbar" }
        })
    }
    if ($pol.Count -eq 0) {
        Remove-Item $arqPol -Force -ErrorAction SilentlyContinue
        return $true
    }
    # Pula a tela de introducao e o aviso de termos de uso na primeira abertura do Firefox
    $pol.SkipTermsOfUse = $true
    $pol.OverrideFirstRunPage = ""
    $pol.OverridePostUpdatePage = ""
    $pol.DontCheckDefaultBrowser = $true
    $pol.UserMessaging = @{
        WhatsNew = $false
        ExtensionRecommendations = $false
        FeatureRecommendations = $false
        UrlbarInterventions = $false
        SkipOnboarding = $true
        MoreFromMozilla = $false
    }
    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    # guarda o arquivo original (de antes do kit) uma vez so
    if ((Test-Path $arqPol) -and -not (Test-Path "$arqPol.bak")) { Copy-Item $arqPol "$arqPol.bak" -Force }
    # UTF-8 sem BOM (o Firefox exige)
    $utf8SemBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($arqPol, (@{ policies = $pol } | ConvertTo-Json -Depth 10), $utf8SemBom)
    return $true
}

