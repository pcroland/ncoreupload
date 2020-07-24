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
* `ffmpeg`
* `ffprobe`
* `mktor`/`mktorrent` (configolható)
* `curl`
* `jq`
* `xmlstarlet` (ha a config fájlban `description='true'` van)

## Telepítés
```sh
install -D -m 755 <(curl -fsSL https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncup.sh) ~/.local/bin/ncup && hash -r
curl "https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncup.conf" --create-dirs -o ~/.ncup/ncup.conf -s
```
* Ha a `~/.local/bin` nincs benne PATH-ban, akkor írjuk be a `.bashrc`/`.zshrc` fájlunkba hogy: `PATH="$HOME/.local/bin:$PATH"`.
* Az`~/.ncup/ncup.conf` fájlban beállítjuk a beállításokat
### script frissítése:
`install -D -m 755 <(curl -fsSL https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncup.sh) ~/.local/bin/ncup && hash -r`
### config frissítése:
`curl "https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncup.conf" --create-dirs -o ~/.ncup/ncup.conf -s`

## Használat
```sh
ncup [input(s)]
```
Példák:

`ncup A.Dogs.Journey.2019.BDRip.x264.HuN-prldm`
(egy konkrét mappa feltöltése)

`ncup A.Dogs.Journey*prldm`
(összes mappa feltöltése, aminek az eleje `A.Dogs.Journey` és a vége `prldm`)

## Működés közben
![image1](https://i.kek.sh/ZvFWJUOhAU8.gif)
