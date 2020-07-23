# ncoreupload
## Feltöltő script nCore-ra eredeti magyar film/sorozat release-ekhez.
* A script automatikusan készít torrentet a megadott inputokhoz, ha még nincs.
* A feltöltési kategóriát mappanévből állapítja meg.
* Az IMDb id-t először NFO fájlban keresi, ha itt nem találja, mappanév alapján keresi ki IMDb-ről.
* A másodlagos linket először szintén NFO fájlban keresi (tvmaze/thetvdb/port/rottentomatoes/mafab), ha nem talál semmit IMDb id-vel lekéri a címet, majd port.hu-n keres rá.
* Az első videófájlból generál mintaképeket.
* infobar.txt-ben manuálisan is meg lehet adni az infobar értékeket.

## Telepítés
```sh
curl -fsSL https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncoreup.sh -o ~/.local/bin/ncoreup && chmod +x ~/.local/bin/ncoreup && rehash
```
## Használat
```sh
ncoreupload [input(s))
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
