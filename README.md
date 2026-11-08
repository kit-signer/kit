# Kit de TI da CAAAL

Instala e configura as máquinas da equipe com um comando só, e tem um menu de correção de erros comuns. Funciona no Windows e no Mac.

## Como usar

**Windows** (CMD ou PowerShell, como administrador):

```
powershell -c "irm https://raw.githubusercontent.com/kit-signer/kit/main/instalar.ps1 | Out-String | iex"
```

**Mac** (Terminal: Cmd+Espaço, digite "Terminal", Enter):

```
curl -fsSL https://raw.githubusercontent.com/kit-signer/kit/main/instalar.sh | bash
```

Vai pedir a senha do Mac. Não aparece nada enquanto digita, e isso é normal.

**Pendrive** (sem internet): copie esta pasta com a subpasta `instaladores`.
- Windows: dois cliques em `INSTALAR.bat`.
- Mac: dois cliques em `INSTALAR.command`. Se o macOS bloquear: botão direito › Abrir › Abrir. Se o arquivo perdeu a permissão (acontece ao copiar pelo Windows), use no Terminal: `sudo bash /Volumes/NOME_DO_PENDRIVE/caaal-kit/instalar.sh`

O menu tem três opções: instalação de programas (Windows ou Mac), correção de erros e sair.

## O que tem aqui

| Arquivo | Para quê |
|---|---|
| `instalar.ps1` | Script do Windows |
| `instalar.sh` | Script do Mac |
| `INSTALAR.bat` / `INSTALAR.command` | Atalhos do pendrive |
| `instaladores/` | Os instaladores dos dois sistemas. **Não vão para o repositório**: sobem no Release `instaladores` |

Os arquivos de Mac começam com `mac-`. No Mac, o script escolhe sozinho a versão certa de cada programa para a versão do macOS e o processador (Intel ou M1/M2/M3), e instala o Rosetta quando precisa.

## Segurança

Cada instalador tem a impressão digital (SHA256) escrita no script. Se o arquivo baixado não bater, ele **não é instalado**. Isso protege contra download pela metade e contra arquivo trocado.

## Como atualizar um programa

1. Troque o arquivo em `instaladores/`. Sem espaços no nome: o GitHub troca espaços por pontos.
2. Gere a impressão digital. No Windows: `Get-FileHash .\instaladores\safenet.msi -Algorithm SHA256`. No Mac: `shasum -a 256 instaladores/arquivo`.
3. Atualize o script:
   - **Windows** (`instalar.ps1`, em `$InstaladoresKit`): troque `Versao`, `Arquivo` e `Sha256`.
   - **Mac** (`instalar.sh`, em `ARQUIVOS`): uma linha por arquivo, no formato `chave|arquivo|macOS mínimo|processador|sha256`. Para ter uma versão nova só para macOS 13 ou mais novo, por exemplo, acrescente uma linha com `13` em "macOS mínimo"; as antigas continuam valendo para os Macs mais velhos.
4. No GitHub, abra o Release **instaladores** › Edit. Apague o arquivo antigo, suba o novo **com o mesmo nome** e clique em Update release. Os outros arquivos ficam como estão.
5. Envie o script alterado (`git commit` e `git push`). Faça isso logo depois do passo 4: até o script novo subir, as máquinas recusam o arquivo novo, porque a impressão digital ainda é a antiga.

O comando não muda nunca.

## Como adicionar uma correção de erro

- **Windows:** em `$Correcoes`, no `instalar.ps1`, copie um bloco `@{ Nome = ...; Descricao = ...; Acao = { ... } }`. Ele aparece sozinho no menu, numerado.
- **Mac:** no `instalar.sh`, acrescente `"Nome|Descrição"` em `CORRECOES` e crie a função `corrigir_N` com o mesmo número.

Logs: Windows em `C:\ProgramData\TI\logs`, Mac em `/Users/Shared/TI/logs`.
