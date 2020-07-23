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
  printf '\n'
}

# infobar parser
ajax_parser() {
  grep -o -P "(?<=id=\"$1\" value=\").*(?=\">)" <<< "$ajax_infobar"
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

print_separator() {
  printf '%.0s─' $(seq 1 "$(tput cols)")
}

cookies=~/.ncup/cookies.txt
config=~/.ncup/ncup.conf
if [[ ! -f "$config" ]]; then
  printf 'Creating config file in: \e[93m%s\e[0m\n' "$config"
  curl "https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncup.conf" --create-dirs -o "$config" -s
fi

# Searching for cookies.txt next to the script,
# if it doesn't exist, show login prompt.
# If login fails exit.
if [[ ! -f "$cookies" ]]; then
  printf '\e[91m%s\e[0m\n' "cookies.txt not found, login: "
  read -r -p 'username: ' username
  read -r -s -p 'password: ' password
  printf '\n'
  mkdir -p "$(dirname "$cookies")"
  curl 'https://ncore.cc/login.php' -c "$cookies" -s -d "submitted=1" --data-urlencode "nev=$username" --data-urlencode "pass=$password" -d "ne_leptessen_ki=1"
  if [[ $(curl -s -I -b "$cookies_file" 'https://ncore.cc/' -o /dev/null -w '%{http_code}') == 200 ]]; then
    printf '\e[92m%s\e[0m\n' "Cookies OK."
  else
    printf '\e[91m%s\e[0m\n' "ERROR: login failed." >&2
    rm -f "$cookies"
    exit 1
  fi
  print_separator
fi

# Config setup.
# shellcheck disable=SC1090
source "$config"
[[ -z "$torrent_program" ]] && torrent_program='mktor'
[[ -z "$generate_images" ]] && generate_images='true'
[[ -z "$print_infobar" ]] && print_infobar='false'
[[ -z "$anonymous_upload" ]] && anonymous_upload='false'

# Anonymous upload config.
if [[ "$anonymous_upload" == true ]]; then
  anonymous='igen'
elif [[ "$anonymous_upload" == false ]]; then
  anonymous='nem'
else
  printf '\e[91m%s\e[0m\n' "ERROR: unsupported anonymous value." >&2
  exit 1
fi

# Grabbing the getUnique id.
printf "Grabbing getUnique id: "
unique_id=$(curl https://ncore.cc -b "$cookies" -s | grep -o -P '(?<=exit.php\?q=).*(?=" id="menu_11")')
printf '%s\n' "$unique_id"

# Check for infobar.txt
if [[ -f infobar.txt ]]; then
  printf 'infobar.txt was found.\n'
else
  printf 'infobar.txt was not found.\n'
fi
print_separator

# Creating torrent file if it doesn't exist yet.
for x in "$@"; do
  torrent_name=$(basename "$x")
  torrent_file=$torrent_name.torrent
  if [[ ! -f "$torrent_file" ]]; then
    torrent_created=1
    printf '\r\e[92m%s\e[0m\n' "$torrent_name"
    animation &
    pid=$!
    if [[ "$torrent_program" == mktor ]]; then
      mktor "$x" http://bithumen.be:11337/announce -o "$torrent_file" &> /dev/null
    elif [[ $torrent_program == mktorrent ]]; then
      mktorrent -a http://bithumen.be:11337/announce -l 24 -o "$torrent_file" "$x" &> /dev/null
    else
      printf '\e[91m%s\e[0m\n' "ERROR: unsupported torrent program." >&2
      exit 1
    fi
    kill -PIPE "$pid"
  fi
done
if (( torrent_created )); then
  print_separator
fi

# Setting up the input files and the infobar values from infobar.txt.
# The script will try to set values that are unset with multiple methods:
# it will get "$imdb" and "$$movie_database" from the NFO file or scrape the sites,
# "$hun_title" "$release_date" and other infobar values will be parsed from the site.
for x in "$@"; do
  printf '\e[92m%s\e[0m\n' "$torrent_name"

  seasons=
  episodes=

  if [[ -f infobar.txt ]]; then
    # shellcheck disable=SC1091
    source infobar.txt
  fi

  torrent_name=$(basename "$x")
  torrent_file=$torrent_name.torrent
  nfo_files=("$x"/*.nfo)
  if (( ${#nfo_files[@]} > 1 )); then
    echo 'ERROR: multiple NFO files found' >&2
    exit 1
  fi
  nfo_file=${nfo_files[0]}

  # Defining torrent category.
  if grep -qEi "\.hun(\.|\-)" <<< "$torrent_name"; then
    if grep -qE "(720p|1080p|2160p|4320p)" <<< "$torrent_name"; then
      if grep -qE "(S|E)[0-9][0-9]" <<< "$torrent_name"; then
        type=hdser_hun
      else
        type=hd_hun
      fi
    else
      if grep -qE "(S|E)[0-9][0-9]" <<< "$torrent_name"; then
        type=xvidser_hun
      else
        type=xvid_hun
      fi
    fi
  else
    if grep -qE "(720p|1080p|2160p|4320p)" <<< "$torrent_name"; then
      if grep -qE "(S|E)[0-9][0-9]" <<< "$torrent_name"; then
        type=hdser
      else
        type=hd
      fi
    else
      if grep -qE "(S|E)[0-9][0-9]" <<< "$torrent_name"; then
        type=xvidser
      else
        type=xvid
      fi
    fi
  fi

  # Generating thumbnail images from the first mkv/mp4/avi file if there's one.
  if [[ "$generate_images" == true ]]; then
    files=(*.mkv *.mp4 *.avi)
    file=${files[0]}
    if [[ -f "$file" ]]; then
      imagegen "$file"
    fi
  fi

  # Setting IMDb id from NFO file if it's not set manually in infobar.txt,
  # if that fails it will scrape imdb.com for an id based on the torrent name.
  if [[ -z "$imdb" ]]; then
    imdb=$(grep -Po '(tt[[:digit:]]*)(?=/)' "$nfo_file")
  fi
  if [[ -z "$imdb" ]]; then
    printf 'Scraping imdb.com for id.\n'
    if [[ $type == hdser_hun || $type == xvidser_hun ]]; then
      search_name=$(sed -E 's/.(S|E)[0-9]{2}.*//' <<< "$torrent_name" | tr '.' '+')
    else
      search_name=$(sed -E 's/(.[0-9]{4}).*/\1/' <<< "$torrent_name" | tr '.' '+')
    fi
    prefix=${search_name:0:1}
    prefix=${prefix,,}
    imdb=$(curl -s "https://v2.sg.media-imdb.com/suggestion/${prefix}/${search_name}.json" | jq -r 'if .d then .d[0].id else empty end')
    #imdb=$(curl "https://www.imdb.com/find?q=$search_name" -s | grep -Po "(tt[[:digit:]]*)(?=\/)" | head -1)
  fi

  # Setting link from the NFO file (tvmaze.com/port.hu/rottentomatoes.com) if it's not set manually in infobar.txt,
  # if that fails it will scrape port.hu for an id based on the torrent name.
  if [[ -z "$movie_database" ]]; then
    movie_database=$(grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" "$nfo_file" | grep 'tvmaze.com\|thetvdb.com\|port.hu\|rottentomatoes.com\|mafab.hu' | head -1)
  fi
  if [[ -z "$movie_database" ]]; then
    printf 'Scraping IMDb for title with id: \e[93m%s\e[0m\n' "$imdb"
    search_name=$(curl -s "https://v2.sg.media-imdb.com/suggestion/t/$imdb.json" | jq -r 'if .d then .d[0].l else empty end')
    printf 'Scraping port.hu for link with title: \e[93m%s\e[0m\n' "$search_name"
    movie_database=$(curl -s "https://port.hu/search/suggest-list?q=$search_name" | jq -r 'if length > 0 then "https://port.hu\(.[0].url)" else empty end')
  fi

  # Grabbing infobar page.
  printf 'Saving infobar with IMDb id: \e[93m%s\e[0m\n' "$imdb"
  ajax_infobar=$(curl "https://ncore.cc/ajax.php?action=imdb_movie&imdb_movie=${imdb//t}" -b "$cookies" -s)

  # Updating infobar values with ajax_parser()
  # if they are not set manually in infobar.txt
  [[ -z "$hun_title" ]] && hun_title=$(ajax_parser movie_magyar_cim)
  [[ -z "$eng_title" ]] && eng_title=$(ajax_parser movie_angol_cim)
  [[ -z "$for_title" ]] && for_title=$hun_title
  [[ -z "$release_date" ]] && release_date=$(ajax_parser movie_megjelenes_eve)
  [[ -z "$infobar_picture" ]] && infobar_picture=$(ajax_parser movie_picture)
  [[ -z "$infobar_rank" ]] && infobar_rank=$(ajax_parser movie_rank)
  [[ -z "$infobar_genres" ]] && infobar_genres=$(ajax_parser movie_genres)
  [[ -z "$country" ]] && country=$(ajax_parser movie_orszag)
  [[ -z "$runtime" ]] && runtime=$(ajax_parser movie_hossz)
  [[ -z "$director" ]] && director=$(ajax_parser movie_rendezo)
  [[ -z "$cast" ]] && cast=$(ajax_parser movie_szereplok)

  # Setting torrent image values if files exist.
  if [[ -f torrent_image_1.png ]]; then
    torrent_image_1='@torrent_image_1.png'
    torrent_image_2='@torrent_image_2.png'
    torrent_image_3='@torrent_image_3.png'
  fi

  # Print infobar values.
  if [[ "$print_infobar" == true ]]; then
    printf 'Hun title..: \e[93m%s\e[0m\n' "$hun_title"
    printf 'Eng title..: \e[93m%s\e[0m\n' "$eng_title"
    printf 'For title..: \e[93m%s\e[0m\n' "$for_title"
    printf 'Release....: \e[93m%s\e[0m\n' "$release_date"
    printf 'Rank.......: \e[93m%s\e[0m\n' "$infobar_rank"
    printf 'Genres.....: \e[93m%s\e[0m\n' "$infobar_genres"
    printf 'Country....: \e[93m%s\e[0m\n' "$country"
    printf 'Runtime....: \e[93m%s\e[0m\n' "$runtime"
    printf 'Director...: \e[93m%s\e[0m\n' "$director"
    printf 'Cast.......: \e[93m%s\e[0m\n' "$cast"
  fi

  # Uploading torrent.
  printf 'IMDB.......: \e[93mhttps://www.imdb.com/title/%s\e[0m\n' "$imdb"
  printf 'link.......: \e[93m%s\e[0m\n' "$movie_database"
  printf 'Uploading..: \e[93m%s\e[0m\n' "$type"
  torrent_link=$(curl -Ls -o /dev/null -w "%{url_effective}" "https://ncore.cc/upload.php" \
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
  -F anonymous="$anonymous" \
  -F elrejt=nem \
  -F mindent_tud1=szabalyzat \
  -F mindent_tud3=seedeles)

  # Downloading torrent from nCore.
  # First curl gets the torrent id with passkey,
  # the second one downloads the torrent.
  printf 'Downloading: \e[93m%s\e[0m\n' "$torrent_link"
  torrent_page=$(curl "$torrent_link" -b "$cookies" -s)
  id_with_passkey=$(grep -m 1 -o -P '(?<=action\=download&id\=).*(?=\">)' <<< "$torrent_page")
  curl "https://ncore.cc/torrents.php?action=download&id=$id_with_passkey" -b "$cookies" -s -o "${torrent_name}_nc.torrent"

  # Posting to feed.
  #printf "Posting to feed.\n"
  #torrent_id=$(grep -m 1 -o -P '(?<=addnews\&id\=).*(?=\&getunique)' <<< "$torrent_page")
  #curl https://ncore.cc/torrents.php?action=addnews&id="$torrent_id"&getunique="$unique_id" -b "$cookies" -s

  # Drawing a separator after each torrent.
  (( t++ ))
  if (( t < $# )); then
    print_separator
  fi

  # Unset infobar values.
  unset imdb movie_database hun_title eng_title for_title release_date infobar_picture infobar_rank infobar_genres country runtime director cast seasons episodes
done

# Deleting thumbnails.
printf 'Deleting thumbnails.\n'
rm -f torrent_image_*
