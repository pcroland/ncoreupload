# ncup
### Feltöltő script nCore-ra eredeti release-ekhez film és sorozat kategóriában.
## Leírás
* A script automatikusan készít torrent és NFO fájlt a megadott inputokhoz, ha valamelyik még nincs.
* A feltöltési kategóriát mappanévből állapítja meg.
* Az IMDb id-t először NFO fájlban keresi, ha itt nem találja, mappanév alapján keresi ki IMDb-ről.
* A másodlagos linket először szintén NFO fájlban keresi (tvmaze/thetvdb/port/rottentomatoes/mafab),
ha nem talál semmit, IMDb-ről id-vel lekéri a címet, majd port.hu-n ezzel a címmel lekéri a linket.
* Az első videó fájlból generál mintaképeket a videó hossza alapján.
* infobar.txt-ben manuálisan is meg lehet adni az infobar értékeket.
* A script az `~/.ncup/` mappában tárolja a cookies és config fájlt.
* Letölti a config fájlt, ha még nincs.
* Ha nincs cookies.txt az `~/.ncup/` mappában, akkor login prompt jön elő. (2FA-s és captcha-s login nem fog működni.)
## Szükséges programok
* `curl`
* `jq`
* `ffmpeg`, `ffprobe` (ha a config fájlban `generate_images='true'` (default))
* `mktorrent`/`mktor` (configolható (mktorrent a default))
* `xmlstarlet` (ha a config fájlban `description='true'` van)
* `mediainfo` (ha a feltölteni kívánt mappában nincs NFO fájl, a script létrehoz egyet)
## Telepítés
* `install -D -m 755 <(curl -fsSL git.io/JJ94i) ~/.local/bin/ncup`

(Ha a `~/.local/bin` nincs benne PATH-ban, akkor írjuk be a `.bashrc`/`.zshrc` fájlunkba hogy: `PATH="$HOME/.local/bin:$PATH"`.)
* `hash -r && ncup -d && ncup -e`
* A `cookies.txt` fájlt az `~/.ncup` mappába másoljuk.
* `ncup -e` paranccsal tudjuk szerkeszteni a config fájlunkat.
## Használat
```sh
ncup [input(s)]
```
Példák:

`ncup A.Dogs.Journey.2019.BDRip.x264.HuN-prldm`
(egy konkrét mappa feltöltése)

`ncup A.Dogs.Journey*prldm`
(összes mappa feltöltése, aminek az eleje `A.Dogs.Journey` és a vége `prldm`)
## Kapcsolók
```sh
-h      Prints help.
-n      Skip uploading.
-u      Update script.
-c      Config editor.
-i      Infobar editor.
-d      Update config from the script.
-e      Update infobar from the script.
```
## Működés közben
![image1](https://i.kek.sh/ZvFWJUOhAU8.gif)
