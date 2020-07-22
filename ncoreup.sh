#!/bin/bash

# thumbnail generator
imagegen() {
  seconds=$(ffprobe -i "$1" -show_format -v quiet | sed -n 's/duration=//p')
  for i in {1..3}; do
    interval=$(bc <<< "scale=4; $seconds/4")
    framepos=$(bc <<< "scale=4; $interval*$i")
    ffmpeg -y -loglevel panic -ss "$framepos" -i "$1" -vframes 1 "torrent_image_$i.png"
    printf '\r\e[0mSaving thumbnails... %d%%' "$(bc <<< "$i*100/3")"
  done
  printf "\n"
}

# infobar parser
ajax_parser() {
  grep -o -P '(?<=id\=\"'"$1"'\"\ value\=\").*(?=\"\>)' <<< "$ajax_infobar"
}

# animation for torrent creation
animation(){
  animation=('░▒▓█▓▒░ ' ' ░▒▓█▓▒░' '░ ░▒▓█▓▒' '▒░ ░▒▓█▓' '▓▒░ ░▒▓█' '█▓▒░ ░▒▓' '▓█▓▒░ ░▒' '▒▓█▓▒░ ░')
  while true
  do
    for i in "${animation[@]}"; do
	  printf '\rCreating torrent \e[93m%-8s\e[0m' "$i"
      sleep 0.1
    done
  done
}

# Searching for ncore_cookies.txt next to the script,
# if it doesn't exist, show login prompt.
script_path=$(realpath -s "$0")
script_path=$(dirname "$script_path")
cookies="$script_path"/ncore_cookies.txt
if [ ! -f "$cookies" ]; then
  printf '\e[91m%s\e[0m\n' "ncore_cookies.txt not found, login: "
  printf "username: "
  read -r username
  printf "password: "
  read -r -s password
  password=$(jq -rR '@uri' <<< "$password")
  printf '\n'
  sudo curl 'https://ncore.cc/login.php' -c "$cookies" -s --data-raw "submitted=1&nev=$username&pass=$password&ne_leptessen_ki=1"
  eval printf %.0s─ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo
fi

# Grabbing the getUnique id.
printf "Grabbing getUnique id: "
unique_id=$(curl https://ncore.cc -b "$cookies" -s | grep -o -P '(?<=exit.php\?q\=).*(?=\"\ id\=\"menu_11\")')
printf '%s\n' "$unique_id"

# Check for infobar.txt
if [ -f infobar.txt ]; then
  printf 'infobar.txt was found.\n'
else
  printf 'infobar.txt was not found.\n'
fi
eval printf %.0s─ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo

# Creating torrent file if it doesn't exist yet.
for x in "$@"; do
  torrent_name=$(basename "$x")
  torrent_file="$torrent_name".torrent 
  if [[ ! -f "$torrent_file" ]]; then
    torrent_created='true'
    printf '\r\e[92m%s\e[0m\n' "$torrent_name"
    animation &
    pid=$!
    mktor "$x" http://bithumen.be:11337/announce -o "$torrent_file" &> /dev/null
#   mktorrent -a http://bithumen.be:11337/announce -l 24 -o "$torrent_file" "$x" &> /dev/null
    kill -PIPE "$pid"
  fi
done
if [ "$torrent_created" ]; then
  printf '\n'
  eval printf %.0s─ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo
fi

# Setting up the input files and the infobar values from infobar.txt.
# The script will try to set values that are unset with multiple methods:
# it will get "$imdb" and "$$movie_database" from the NFO file or scrape the sites,
# "$hun_title" "$release_date" and other infobar values will be parsed from the site.
for x in "$@"; do
if [ -f infobar.txt ]; then
  source infobar.txt
fi
seasons=
episodes=
torrent_name=$(basename "$x")
torrent_file="$torrent_name".torrent
nfo_file=$(ls "$x"/*nfo)
printf '\e[92m%s\e[0m\n' "$torrent_name"

# Defining torrent category.
if (grep -qE "(720p|1080p|2160p|4320p)" <<< "$torrent_name"); then
  if (grep -qE "(S|E)[0-9][0-9]" <<< "$torrent_name"); then type=hdser_hun
  else type=hd_hun
  fi
else
  if (grep -qE "(S|E)[0-9][0-9]" <<< "$torrent_name"); then type=xvidser_hun
  else type=xvid_hun
  fi
fi

# Generating thumbnail images from the first mkv/mp4/avi file.
imagegen "$(find "$x" -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" | head -n 1)"

# Setting IMDb id from NFO file if it's not set manually in infobar.txt,
# if that fails it will scrape imdb.com for an id based on the torrent name.
if [ -z "$imdb" ]; then
  imdb=$(cat -v "$nfo_file" | grep -Po "(tt[[:digit:]]*)(?=\/)")
fi
if [ -z "$imdb" ]; then
  printf "Scraping imdb.com for id.\n"
  if [[ "$type" == hdser_hun || "$type" == xvidser_hun ]]; then
    search_name=$(sed -E 's/.(S|E)[0-9]{2}.*//' <<< "$torrent_name" | tr '.' '+')
  else
    search_name=$(sed -E 's/(.[0-9]{4}).*/\1/' <<< "$torrent_name" | tr '.' '+')
  fi
  prefix=${search_name:0:1}
  prefix=${prefix,,}
  imdb=$(curl -s "https://v2.sg.media-imdb.com/suggestion/${prefix}/${search_name}.json" | jq -r 'if .d then .d[0].id else empty end')
# imdb=$(curl "https://www.imdb.com/find?q=$search_name" -s | grep -Po "(tt[[:digit:]]*)(?=\/)" | head -1)
fi

# Setting link from the NFO file (tvmaze.com/port.hu/rottentomatoes.com) if it's not set manually in infobar.txt,
# if that fails it will scrape port.hu for an id based on the torrent name.
if [ -z "$movie_database" ]; then
  movie_database=$(cat -v "$nfo_file" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" | grep 'tvmaze.com\|thetvdb.com\|port.hu\|rottentomatoes.com\|mafab.hu' | head -1)
fi
if [ -z "$movie_database" ]; then
  printf "Scraping port.hu for movie database.\n"
  if [[ "$type" == hdser_hun || "$type" == xvidser_hun ]]; then
    search_name=$(sed -E 's/.(S|E)[0-9]{2}.*//' <<< "$torrent_name" | tr '.' '+')
  else
    search_name=$(sed -E 's/(.[0-9]{4}).*//' <<< "$torrent_name" | tr '.' '+')
  fi
  movie_database=$(curl -s "https://port.hu/search/suggest-list?q=$search_name" | jq -r 'if length > 0 then "https://port.hu\(.[0].url)" else empty end')
fi

# Grabbing infobar page.
printf 'Saving infobar with IMDb id: \e[93m%s\e[0m\n' "$imdb"
ajax_infobar=$(curl "https://ncore.cc/ajax.php?action=imdb_movie&imdb_movie=${imdb//t}" -b "$cookies" -s)

# Updating infobar values with ajax_parser()
# if they are not set manually in infobar.txt
if [ -z "$hun_title" ]; then hun_title=$(ajax_parser movie_magyar_cim); fi
if [ -z "$eng_title" ]; then eng_title=$(ajax_parser movie_angol_cim); fi
if [ -z "$for_title" ]; then for_title=$hun_title; fi
if [ -z "$release_date" ]; then release_date=$(ajax_parser movie_megjelenes_eve); fi
if [ -z "$infobar_picture" ]; then infobar_picture=$(ajax_parser movie_picture); fi
if [ -z "$infobar_rank" ]; then infobar_rank=$(ajax_parser movie_rank); fi
if [ -z "$infobar_genres" ]; then infobar_genres=$(ajax_parser movie_genres); fi
if [ -z "$country" ]; then country=$(ajax_parser movie_orszag); fi
if [ -z "$runtime" ]; then runtime=$(ajax_parser movie_hossz); fi
if [ -z "$director" ]; then director=$(ajax_parser movie_rendezo); fi
if [ -z "$cast" ]; then cast=$(ajax_parser movie_szereplok); fi

# Setting torrent image values if files exist.
if [ -f torrent_image_1.png ]; then
  torrent_image_1='@torrent_image_1.png'
  torrent_image_2='@torrent_image_2.png'
  torrent_image_3='@torrent_image_3.png'
fi

# Print infobar values.
#printf 'Hun title..: \e[93m%s\e[0m\n' "$hun_title"
#printf 'Eng title..: \e[93m%s\e[0m\n' "$eng_title"
#printf 'For title..: \e[93m%s\e[0m\n' "$for_title"
#printf 'Release....: \e[93m%s\e[0m\n' "$release_date"
#printf 'Rank.......: \e[93m%s\e[0m\n' "$infobar_rank"
#printf 'Genres.....: \e[93m%s\e[0m\n' "$infobar_genres"
#printf 'Country....: \e[93m%s\e[0m\n' "$country"
#printf 'Runtime....: \e[93m%s\e[0m\n' "$runtime"
#printf 'Director...: \e[93m%s\e[0m\n' "$director"
#printf 'Cast.......: \e[93m%s\e[0m\n' "$cast"

# Uploading torrent.
printf 'IMDB.......: \e[93mhttps://www.imdb.com/title/%s\e[0m\n' "$imdb"
printf 'link.......: \e[93m%s\e[0m\n' "$movie_database"
printf 'Uploading..: \e[93m%s\e[0m\n' "$type"
torrent_link=$(curl -Ls -o /dev/null -w "%{url_effective}" "https://ncorea.cc/upload.php" \
-b "$cookies" \
-F getUnique="$unique_id" \
-F eredeti=igen \
-F infobar_site=imdb \
-F tipus="$type" \
-F torrent_nev="$torrent_name" \
-F torrent_fajl=@"$torrent_file" \
-F nfo_fajl=@"$nfo_file" \
-F kep1="$torrent_image_1" \
-F kep2="$torrent_image_2" \
-F kep3="$torrent_image_3" \
-F imdb_id="$imdb" \
-F film_adatbazis="$movie_database" \
-F infobar_picture="$infobar_picture" \
-F infobar_rank="$infobar_rank" \
-F infobar_genres="$infobar_genres" \
-F megjelent="$release_date" \
-F orszag="$country" \
-F hossz="$runtime" \
-F film_magyar_cim="$hun_title" \
-F film_angol_cim="$eng_title" \
-F film_idegen_cim="$for_title" \
-F rendezo="$director" \
-F szereplok="$cast" \
-F szezon="$seasons" \
-F epizod_szamok="$episodes" \
-F keresre=nem \
-F anonymous=nem \
-F elrejt=nem \
-F mindent_tud1=szabalyzat \
-F mindent_tud3=seedeles)

# Downloading torrent from nCore.
# First curl gets the torrent id with passkey,
# the second one downloads the torrent.
printf 'Downloading: \e[93m%s\e[0m\n' "$torrent_link"
torrent_page=$(curl "$torrent_link" -b ncore_cookies.txt -s)
id_with_passkey=$(grep -m 1 -o -P '(?<=action\=download&id\=).*(?=\">)' <<< "$torrent_page")
curl "https://ncore.cc/torrents.php?action=download&id=$id_with_passkey" -b ncore_cookies.txt -s -o "$torrent_name"_nc.torrent

# Posting to feed.
#printf "Posting to feed.\n"
#torrent_id=$(grep -m 1 -o -P '(?<=addnews\&id\=).*(?=\&getunique)' <<< "$torrent_page")
#curl https://ncore.cc/torrents.php?action=addnews&id="$torrent_id"&getunique="$unique_id" -b ncore_cookies.txt -s

# Drawing a separator after each torrent.
((t++))
if [[ "$t" -lt "$#" ]]; then
  eval printf %.0s─ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo
fi

# Unset infobar values.
unset imdb movie_database hun_title eng_title for_title release_date infobar_picture infobar_rank infobar_genres country runtime director cast seasons episodes
done

# Deleting thumbnails.
if [ -f torrent_image_1.png ]; then
  printf "Deleting thumbnails.\n"
  rm torrent_image_*
fi
