# Lingmo File Manager

Lingmo File Manager, simple to use, beautiful, and retain the classic PC interactive design. 

![screenshot](screenshots/Screenshot_20211025_151224.png)

## Dependencies

### Ubuntu

```
sudo apt install equivs curl git devscripts lintian build-essential automake autotools-dev --no-install-recommends

sudo mk-build-deps -i -t "apt-get --yes" -r
```

### Debian

```
sudo apt install build-essential cmake extra-cmake-modules libkf5kio-dev libkf5solid-dev libkf5windowsystem-dev libkf5config-dev qtbase5-dev qtbase5-private-dev qtdeclarative5-dev qtquickcontrols2-5-dev qttools5-dev qttools5-dev-tools
```

### ArchLinux

```shell
sudo pacman -S extra-cmake-modules qt5-base qt5-quickcontrols2 taglib kio
```

## Build

```shell
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr ..
make
```

## Install

```shell
sudo make install
```

## License

This project has been licensed by GPLv3.

## Janela

- **Barra de caminho**: botões clicáveis a partir da *Pasta pessoal*; pastas do
  meio que não cabem viram um menu "…". Clique na parte vazia da barra (ou
  `Ctrl+L`) para digitar o caminho.
- **Barra de ferramentas**: voltar/avançar, pesquisa (`Ctrl+F`), ícones/lista
  (`Ctrl+1`/`Ctrl+2`), ordenação, nova pasta (`Ctrl+Shift+N`) e painel de
  visualização (`Alt+P`).
- **Pesquisa**: procura pelo nome em toda a pasta atual e subpastas, numa thread
  separada, sem indexador (até 2000 resultados; ignora acentos e maiúsculas;
  pastas ocultas só com "Mostrar arquivos ocultos").
- **Barra lateral**: Favoritos (arraste uma pasta para lá, ou "Adicionar aos
  favoritos" no menu de contexto; salvos em `~/.config/lingmoos/lingmo-filemanager-places.conf`),
  Recentes (`~/.local/share/recently-used.xbel`), Locais (pastas do usuário,
  Lixeira com o número de itens, Caixas em `~/Boxes`) e Discos com barra de uso.
- **Abas**: `Ctrl+T`, `Ctrl+W`, `Ctrl+Tab`; clique do meio numa pasta abre em
  nova aba.
- **Lista** com colunas Nome, Tamanho, Modificado e Tipo (clique no cabeçalho
  para ordenar); **ícones** com miniaturas quadradas e zoom (controle deslizante
  ou `Ctrl`+roda).
- **Painel de visualização**: imagem, primeira página de PDF, início de arquivos
  de texto, dados de áudio/vídeo e detalhes (tamanho, datas, permissões).

Opcionais: `kfilemetadata` (duração, dimensões, artista… no painel; detectado
no `cmake`) e o módulo QML `QtQuick.Pdf` (`qt6-webengine` no Arch) para a página
do PDF. Sem eles o painel mostra o ícone e os detalhes básicos.

## Arquivos compactados

O menu de contexto oferece **Extrair aqui**, **Extrair para…** e **Compactar…**
para arquivos locais (inclusive seleção múltipla). A extração aparece quando
todos os arquivos selecionados são reconhecidos pelos plugins do Ark instalado.
`ark --mimetypes` fornece a lista em tempo de execução; não há uma lista fixa de
extensões no gerenciador. O diálogo de compactação mostra os formatos graváveis.
O Ark cuida de progresso, senhas, erros e conflitos; a extração usa subpasta
automática quando o conteúdo não tem uma única raiz.

Dependências de execução no Arch: `ark` e `7zip`, incluídas em
`packaging/components.conf` e em `make deps` no workspace. Não há promessa de
leitura/escrita de todo formato: isso depende dos plugins e codecs instalados.
A integração usa os argumentos documentados no código oficial:
https://invent.kde.org/utilities/ark/-/blob/master/app/main.cpp

```sh
cmake -S tests -B /tmp/lingmo-archive-tests
cmake --build /tmp/lingmo-archive-tests
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= ctest --test-dir /tmp/lingmo-archive-tests --output-on-failure
```

Os mesmos testes cobrem a pesquisa recursiva (`browser-test`) e a barra de
caminho começando na pasta pessoal.

O teste de integração requer Ark com suporte a ZIP, TAR.GZ e 7z. Verifica
compactação e extração reais, incluindo nomes com espaços. Sem Ark, essa parte
é marcada como ignorada.

## Validação do wallpaper

O wallpaper dispensa o ColorOverlay que capturava o próprio pai e recria seu
Loader após desbloqueio, retorno da suspensão ou reinicialização do scene graph.
Validar em uma sessão Lingmo: imagem e cor sólida, tema claro/escuro, bloqueio e
suspensão repetidos, incluindo monitor secundário. O build isolado não reproduz
perda de textura no driver/compositor de uma sessão real.
