# ncup
### Feltöltő script nCore-ra eredeti release-ekhez film és sorozat kategóriában.

## Leírás
* A script automatikusan készít torrentet a megadott inputokhoz, ha még nincs.
* A feltöltési kategóriát mappanévből állapítja meg.
* Az IMDb id-t először NFO fájlban keresi, ha itt nem találja, mappanév alapján keresi ki IMDb-ről.
* A másodlagos linket először szintén NFO fájlban keresi (tvmaze/thetvdb/port/rottentomatoes/mafab),
ha nem talál semmit, IMDb-ről id-vel lekéri a címet, majd port.hu-n ezzel a címmel lekéri a linket.
* Az első videófájlból generál mintaképeket a videó hossza alapján.
* infobar.txt-ben manuálisan is meg lehet adni az infobar értékeket.
* A script az `~/.ncup/` mappában tárolja a cookies és config fájlt.
* Letölti a config fájlt, ha még nincs.
* Ha nincs cookies.txt az `~/.ncup/` mappában, akkor login prompt jön elő. (Ha captcha-t dob az oldal nem fog működni)

## Szükséges programok
* `curl`
* `jq`
* `ffmpeg`, `ffprobe` (ha a config fájlban `generate_images='true'` (default))
* `mktorrent`/`mktor` (configolható (mktorrent a default))
* `xmlstarlet` (ha a config fájlban `description='true'` van)
* `mediainfo` (ha a feltölteni kívánt mappában nincs NFO fájl, a script létrehoz egyet)

## Telepítés
```sh
install -D -m 755 <(curl -fsSL https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncup.sh) ~/.local/bin/ncup && hash -r
```
* Ha a `~/.local/bin` nincs benne PATH-ban, akkor írjuk be a `.bashrc`/`.zshrc` fájlunkba hogy: `PATH="$HOME/.local/bin:$PATH"`.
* `ncup -e` paranccsal szerkesztjük a config fájlunkat. (Ha még nincs, a scriptből kimenti a defaultot.)

script frissítése:

`ncup -u`

config frissítése:

`ncup -c`

## Használat
```sh
ncup [input(s)]
```
Help:

`ncup -h`
Példák:

`ncup A.Dogs.Journey.2019.BDRip.x264.HuN-prldm`
(egy konkrét mappa feltöltése)

`ncup A.Dogs.Journey*prldm`
(összes mappa feltöltése, aminek az eleje `A.Dogs.Journey` és a vége `prldm`)

## Működés közben
![image1](https://i.kek.sh/ZvFWJUOhAU8.gif)
