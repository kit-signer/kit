# Kit de TI da CAAAL

Instala e configura as máquinas da equipe com um comando só, e tem um menu de correção de erros comuns. Funciona no Windows e no Mac.

## Como usar

**Windows**: abra o **PowerShell** (botão direito no Iniciar › Terminal (Admin) ou Windows PowerShell (Admin)) e cole:

```
irm https://raw.githubusercontent.com/kit-signer/kit/main/instalar.ps1 | Out-String | iex
```

Use o PowerShell, não o CMD. Rodar pelo CMD exige `powershell -c "..."`, e o Microsoft Defender bloqueia esse formato como trojan (`Trojan:Win32/Commando`), mesmo o script sendo inofensivo. Se abrir sem ser administrador, o kit pede a permissão sozinho.

**Mac** (Terminal: Cmd+Espaço, digite "Terminal", Enter):

```
curl -fsSL https://raw.githubusercontent.com/kit-signer/kit/main/instalar.sh | bash
```

Vai pedir a senha do Mac. Não aparece nada enquanto digita, e isso é normal.

**Pendrive** (sem internet): copie esta pasta com a subpasta `instaladores`.
- Windows: dois cliques em `INSTALAR.bat`.
- Mac: dois cliques em `INSTALAR.command`. Se o macOS bloquear: botão direito › Abrir › Abrir. Se o arquivo perdeu a permissão (acontece ao copiar pelo Windows), use no Terminal: `sudo bash /Volumes/NOME_DO_PENDRIVE/caaal-kit/instalar.sh`

### O menu

A primeira tela pergunta **qual computador você vai configurar** (Windows ou Mac) e depois mostra só as opções daquele sistema:

| Windows | Mac |
|---|---|
| Instalar programas | Instalar programas |
| Correção de erros | Correção de erros |
| Desinstalar programas | (ainda não tem) |

Se você escolher o outro sistema (Mac num Windows, ou Windows num Mac), o kit mostra o comando para colar no outro computador.

**Token no cabeçalho:** o topo da tela mostra se tem um token conectado, de que tipo (SafeNet eToken, Thales/Gemalto IDPrime, G+D StarSign, Watchdata, Feitian ePass) e se o driver dele está instalado. No Windows, mostra também o certificado e até quando ele vale. O tipo é reconhecido pelo nome que o aparelho USB informa. Para reconhecer outro modelo, acrescente uma linha em `$TiposToken` (Windows) ou `TIPOS_TOKEN` (Mac).

**Histórico (Windows):** o kit apaga o próprio comando do histórico do PowerShell quando abre e de novo ao escolher Sair. Assim ninguém repete o comando com a seta para cima. Só saem as linhas com `kit-signer`; o resto do histórico fica. A lista da seta para cima daquela janela é zerada, porque o PowerShell não deixa tirar uma linha só. A cópia temporária que o kit cria para pedir administrador (`%TEMP%\kit-ti.ps1`) também é apagada. Isso ainda não existe no Mac: lá, o Terminal grava o histórico só quando é fechado, e o script não consegue apagar a linha antes disso.

### Desinstalar programas

Remove só os **programas do kit**: PJeOffice, SafeNet, SafeSign e Web Signer. Os de uso pessoal (Chrome, Firefox, WinRAR) **nunca** são removidos e nem aparecem na lista: estão em `$NaoDesinstalar`, no `instalar.ps1`. Para proteger outro programa, acrescente o nome nessa lista.

- Dá para escolher um programa ou **[T] Todos** os que estão instalados. O kit mostra o que vai remover e pede confirmação.
- Remove sem janelas, fechando antes o programa se estiver aberto (o PJeOffice fica em segundo plano).
- Ao remover o Web Signer, tira também a extensão forçada dos navegadores. Só a entrada do Web Signer sai: outras extensões forçadas continuam.
- A cadeia de certificados ICP-Brasil **não** é removida: ela não atrapalha e é usada por outros programas e sites.
- Log em `C:\ProgramData\TI\logs\desinstalar-...txt`.

## O que tem aqui

| Arquivo | Para quê |
|---|---|
| `instalar.ps1` | Script do Windows |
| `instalar.sh` | Script do Mac |
| `INSTALAR.bat` / `INSTALAR.command` | Atalhos do pendrive |
| `instaladores/` | Os instaladores. **Não vão para o repositório** (veja abaixo) |

**De onde vem cada programa no Windows:**

| Programa | Origem |
|---|---|
| WinRAR, Chrome, Firefox | winget (versão mais nova) |
| SafeSign, Web Signer | winget, com **versão fixa** no `instalar.ps1` |
| PJeOffice Pro | Release `instaladores` do GitHub (não está no winget) |
| SafeNet 10.7 | Release `instaladores` do GitHub. No winget ele vem num pacote de 142 MB e demora muito; o nosso `safenet.msi` tem 15 MB |

O winget é o catálogo de programas da Microsoft: baixa do site do fabricante e confere a impressão digital. Precisa de internet.

**No Release `instaladores`** ficam o `pjeoffice.exe`, o `safenet.msi`, o `websigner.xpi` e os arquivos de Mac (`mac-...`).

**Na pasta `instaladores/` do pendrive** ficam todos, incluindo `safesign.exe` e `websigner.msi`. Esses dois são o plano B sem internet: só são usados quando o kit roda do pendrive e o winget não consegue instalar.

Os arquivos de Mac começam com `mac-`. No Mac, o script escolhe sozinho a versão certa de cada programa para a versão do macOS e o processador (Intel ou M1/M2/M3), e instala o Rosetta quando precisa.

## Segurança

Cada instalador tem a impressão digital (SHA256) escrita no script. Se o arquivo baixado não bater, ele **não é instalado**. Isso protege contra download pela metade e contra arquivo trocado.

### Cadeia de certificados ICP-Brasil

A instalação e a correção "Erro de conexão com certificado digital" instalam no Windows a cadeia ICP-Brasil, baixada do pacote oficial do ITI. É ela que permite ao navegador apresentar o certificado do token ao tribunal (ex.: `certificado-sso.tjal.jus.br`).

- Só são instaladas as **raízes cuja impressão digital está em `$RaizesIcp`**, no `instalar.ps1`: v5, v10, v11 e v12, as que o TJAL aceita. A v12 é a raiz da **AC OAB G4** (certificados novos da OAB). A v5 e a v10 também conferem com a lista de raízes confiáveis da Microsoft.
- As autoridades intermediárias (AC OAB, Certisign etc.) só entram se a cadeia delas termina numa dessas raízes.
- Se o ITI publicar uma raiz nova, ela é **ignorada** até alguém conferir a impressão digital no site do ITI e acrescentar em `$RaizesIcp`. Instalar uma raiz falsa permitiria se passar por qualquer site, então isso é de propósito.

No Firefox, o kit também liga o uso dos certificados do Windows e carrega o módulo do token (SafeNet e SafeSign).

## Como atualizar um programa

**SafeSign e Web Signer (winget):** veja as versões disponíveis com `winget show --id AETEurope.SafeSignICStandard --versions` (os IDs estão no `instalar.ps1`). Troque o `Versao` do programa em `$ProgramasWinget` e envie o script. Não precisa subir arquivo nenhum. Driver de token novo: teste numa máquina antes. Se quiser manter o plano B do pendrive atualizado, troque também o arquivo e o `Sha256` em `Pendrive`.

**PJeOffice, SafeNet e os programas de Mac (Release):**

1. Troque o arquivo em `instaladores/`. Sem espaços no nome: o GitHub troca espaços por pontos.
2. Gere a impressão digital. No Windows: `Get-FileHash .\instaladores\safenet.msi -Algorithm SHA256`. No Mac: `shasum -a 256 instaladores/arquivo`.
3. Atualize o script:
   - **Windows** (`instalar.ps1`, em `$InstaladoresKit`): troque `Versao` e `Sha256`.
   - **Mac** (`instalar.sh`, em `ARQUIVOS`): uma linha por arquivo, no formato `chave|arquivo|macOS mínimo|processador|sha256`. Para ter uma versão nova só para macOS 13 ou mais novo, por exemplo, acrescente uma linha com `13` em "macOS mínimo"; as antigas continuam valendo para os Macs mais velhos.
4. No GitHub, abra o Release **instaladores** › Edit. Apague o arquivo antigo, suba o novo **com o mesmo nome** e clique em Update release. Os outros arquivos ficam como estão.
5. Envie o script alterado (`git commit` e `git push`). Faça isso logo depois do passo 4: até o script novo subir, as máquinas recusam o arquivo novo, porque a impressão digital ainda é a antiga.

O comando não muda nunca.

## Como adicionar uma correção de erro

**Sites dos tribunais:** as opções "O tribunal está fora do ar?" e "Abrir o tribunal em outro navegador" usam a lista `$Tribunais`, no `instalar.ps1`. Hoje ela tem o eSAJ do TJAL. Para incluir o eproc ou outro, copie a linha e troque o nome e o endereço.


- **Windows:** em `$Correcoes`, no `instalar.ps1`, copie um bloco `@{ Nome = ...; Descricao = ...; Acao = { ... } }`. Ele aparece sozinho no menu, numerado.
- **Mac:** no `instalar.sh`, acrescente `"Nome|Descrição"` em `CORRECOES` e crie a função `corrigir_N` com o mesmo número.

Logs: Windows em `C:\ProgramData\TI\logs`, Mac em `/Users/Shared/TI/logs`.
