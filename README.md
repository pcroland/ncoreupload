# ncoreupload
## Feltöltő script nCore-ra eredeti magyar film/sorozat release-ekhez.
* A script automatikusan készít torrentet a megadott inputokhoz, ha még nincs.
* A feltöltési kategóriát mappanévből állapítja meg.
* Az IMDb id-t először NFO fájlban keresi, ha itt nem találja, mappanév alapján keresi ki IMDb-ről.
* A másodlagos linket először szintén NFO fájlban keresi (tvmaze/thetvdb/port/rottentomatoes/mafab),
ha nem talál semmit, IMDb-ről id-vel lekéri a címet, majd port.hu-n ezzel a címmel lekéri a linket.
* Az első videófájlból generál mintaképeket a videó hossza alapján.
* infobar.txt-ben manuálisan is meg lehet adni az infobar értékeket.
## Szükséges programok
* ffmpeg
* ffprobe
* mktor/mktorrent (script tetején állítható)
* curl
* jq
## Telepítés
```sh
install -D -m 755 <(curl -fsSL https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncoreup.sh) ~/.local/bin/ncoreup && hash -r
```
* ha `~/.local/bin` nincs benne PATH-ban, akkor írjuk be a `.bashrc`/`.zshrc` fájlunkba hogy: `PATH="$HOME/.local/bin:$PATH"`
## Használat
```sh
ncoreupload [input(s)]
```
## Példák
```sh
ncoreupload A.Dogs.Journey.2019.BDRip.x264.HuN-prldm
```
(egy konkrét mappa feltöltése)
```sh
ncoreupload A.Dogs.Journey*prldm
```
(összes mappa feltöltése, aminek az eleje `A.Dogs.Journey` és a vége `prldm`)

## Működés közben
![image1](https://i.kek.sh/ZvFWJUOhAU8.gif)
