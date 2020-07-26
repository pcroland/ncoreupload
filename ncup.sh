#!/bin/bash

# image generator
imagegen() {
  images=3
  seconds=$(ffprobe -i "$1" -show_format -v quiet | sed -n 's/duration=//p')
  interval=$(bc <<< "scale=4; $seconds/($images+1)")
  for i in {1..3}; do
    framepos=$(bc <<< "scale=4; $interval*$i")
    ffmpeg -y -loglevel panic -ss "$framepos" -i "$1" -vframes 1 "torrent_image_$i.png"
    printf '\rSaving images: [%d/%d] %03d%%' "$i" "$images" "$(bc <<< "$i*100/3")"
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
  while true; do
    for i in "${animation[@]}"; do
      printf '\r'
      if (( nfo_created )); then
        printf 'Creating NFO. '
      fi
      printf 'Creating torrent \e[93m%-8s\e[0m' "$i"
      sleep 0.1
    done
  done
}

print_separator() {
  printf '%.0s─' $(seq 1 "$(tput cols)")
}

config_checker() {
  if [[ ! -f "$config" ]]; then
    printf 'Missing config, saving default in: \e[93m%s\e[0m\n' "$config"
    printf '%s\n' "$default_config" > "$config"
    config_created=1
  fi
}

infobar_checker() {
  if [[ ! -f "$infobar" ]]; then
    printf 'Missing infobar, saving default in: \e[93m%s\e[0m\n' "$infobar"
    printf '%s\n' "$default_infobar" > "$infobar"
    infobar_created=1
  fi
}

updater() {
  printf 'Updating script.\n'
  tmp=$(mktemp "${TMPDIR:-/tmp}/ncup.XXXXXXXXXX")
  curl "https://raw.githubusercontent.com/pcroland/ncoreupload/master/ncup.sh" -s -o "$tmp"
  if diff -q "$script" "$tmp" >/dev/null; then
    printf '\e[32mAlready up to date.\e[0m\n'
  else
    diff --color=always -u "$script" "$tmp"
    install -D -m 755 "$tmp" "$script"
  fi
  rm -f "$tmp"
}

help=$(cat <<'EOF'
Usage:
  ncup [input(s)]

Options:
  -h      Prints help.
  -n      Skip uploading.
  -u      Update script.
  -c      Config editor.
  -i      Infobar editor.
  -d      Update config from the script.
  -e      Update infobar from the script.

Example:
  ncup A.Dogs.Journey*prldm
EOF
)

default_config=$(cat <<EOF
torrent_program='mktorrent'
generate_images='true'
print_infobar='false'
anonymous_upload='false'
description='false'
post_to_feed='false'
EOF
)

default_infobar=$(cat <<EOF
imdb=
movie_database=
hun_title=
eng_title=
for_title=
release_date=
infobar_picture=
infobar_rank=
infobar_genres=
country=
runtime=
director=
cast=
seasons=
episodes=
EOF
)

# Show help if there's no arguments.
if [[ "$#" -eq 0 ]]; then
  echo "$help" >&2
  exit 1
fi

cookies=~/.ncup/cookies.txt
config=~/.ncup/ncup.conf
infobar=~/.ncup/infobar.txt
script=~/.local/bin/ncup

while getopts ':hnucide' OPTION; do
  case "$OPTION" in
    h) echo "$help"; exit 0;;
    n) noupload=1;;
    u) updater; exit 0;;
    c) config_checker
       (( config_created )) && sleep 2
       "${EDITOR:-editor}" "$config"
       exit 0;;
    i) infobar_checker
       (( infobar_created )) && sleep 2
       "${EDITOR:-editor}" "$infobar"
       exit 0;;
    d) printf '%s\n' "$default_config" > "$config"
       printf 'Copied default config in: %s\n' "$config"
       exit 0;;
    e) printf '%s\n' "$default_infobar" > "$infobar"
       printf 'Copied default infobar in: %s\n' "$infobar"
       exit 0;;
    *) echo "ERROR: Invalid option: -$OPTARG" >&2; exit 1;;
  esac
done

shift "$((OPTIND - 1))"

# Config and infobar check.
config_checker
infobar_checker

# Update config values if something is missing (old config).
# shellcheck disable=SC1090
source "$config"
[[ -z "$torrent_program" ]] && torrent_program='mktorrent'
[[ -z "$generate_images" ]] && generate_images='true'
[[ -z "$print_infobar" ]] && print_infobar='false'
[[ -z "$anonymous_upload" ]] && anonymous_upload='false'
[[ -z "$description" ]] && description='false'
[[ -z "$post_to_feed" ]] && post_to_feed='false'

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
  if [[ $(curl -s -I -b "$cookies" 'https://ncore.cc/' -o /dev/null -w '%{http_code}') == 200 ]]; then
    printf '\e[92m%s\e[0m\n' "Cookies OK."
  else
    printf '\e[91m%s\e[0m\n' "ERROR: login failed." >&2
    rm -f "$cookies"
    exit 1
  fi
  print_separator
fi

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
print_separator

# Creating NFO file with mediainfo if it doesn't exist yet.
# exit if there are multiple NFO files in the folder.
# Creating torrent file if it doesn't exist yet.
for x in "$@"; do
  torrent_name=$(basename "$x")
  torrent_file="$torrent_name".torrent
  nfo_files=("$x"/*.nfo)
  nfo_file="${nfo_files[0]}"
  printf '\e[92m%s\e[0m\n' "$torrent_name"
  if (( ${#nfo_files[@]} > 1 )); then
    printf '\e[91m%s\e[0m\n' "ERROR: multiple NFO files found." >&2
    exit 1
  fi
  if [[ -f "$nfo_file" && -f "$torrent_file" ]]; then
    printf 'Already has NFO and torrent file.\n'
  else
    if [[ ! -f "$nfo_file" ]]; then
      nfo_created=1
      printf "Creating NFO. "
	  mediainfo "$x" > "$x"/"$torrent_name".nfo
    fi
    if [[ ! -f "$torrent_file" ]]; then
      torrent_created=1
      animation &
      pid=$!
      if [[ $torrent_program == mktorrent ]]; then
        mktorrent -a http://bithumen.be:11337/announce -l 24 -o "$torrent_file" "$x" &> /dev/null
      elif [[ "$torrent_program" == mktor ]]; then
        mktor "$x" http://bithumen.be:11337/announce -o "$torrent_file" &> /dev/null
      else
        printf '\e[91m%s\e[0m\n' "ERROR: unsupported torrent program." >&2
        exit 1
      fi
      kill -PIPE "$pid"
	  printf '\n'
    fi
  if (( nfo_created && ! torrent_created )); then
    printf '\n'
  fi
  fi
  torrent_created=0
  nfo_created=0
done
print_separator

# Setting up the input files and the infobar values from infobar.txt.
# The script will try to set values that are unset with multiple methods:
# it will get "$imdb" and "$$movie_database" from the NFO file or scrape the sites,
# "hun_title" "release_date" and other infobar values will be parsed from the site.
for x in "$@"; do
  # Setting up torrent name, torrent file and NFO file. Print out torrent name.
  torrent_name=$(basename "$x")
  torrent_file="$torrent_name".torrent
  nfo_file=("$x"/*.nfo)
  seasons=
  episodes=
  # shellcheck disable=SC1090
  source "$infobar"
  printf '\e[92m%s\e[0m\n' "$torrent_name"

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
    file=$(find "$x" -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" | head -n 1)
    if [[ -f "$file" ]]; then
      imagegen "$file"
    fi
  fi

  # Setting IMDb id from NFO file if it's not set manually in infobar.txt,
  # if that fails it will scrape imdb.com for an id based on the torrent name.
  if [[ -z "$imdb" ]]; then
    # shellcheck disable=SC2128
    imdb=$(grep -Po '(tt[[:digit:]]*)(?=/)' "$nfo_file")
  fi
  if [[ -z "$imdb" ]]; then
    printf "Scraping imdb.com for id: "
    if [[ $type == hdser_hun || $type == xvidser_hun ]]; then
      search_name_folder=$(sed -E 's/.(S|E)[0-9]{2}.*//' <<< "$torrent_name" | tr '.' '+')
    else
      search_name_folder=$(sed -E 's/(.[0-9]{4}).*/\1/' <<< "$torrent_name" | tr '.' '+')
    fi
    prefix=${search_name_folder:0:1}
    prefix=${prefix,,}
    imdb=$(curl -s "https://v2.sg.media-imdb.com/suggestion/${prefix}/${search_name_folder}.json" | jq -r 'if .d then .d[0].id else empty end')
    #imdb=$(curl "https://www.imdb.com/find?q=$search_name_folder" -s | grep -Po "(tt[[:digit:]]*)(?=\/)" | head -1)
	printf '\e[93m%s\e[0m\n' "$imdb"
  fi

  # Setting link from the NFO file (tvmaze.com/port.hu/rottentomatoes.com) if it's not set manually in infobar.txt,
  # if that fails it will scrape port.hu for an id based on the torrent name.
  if [[ -z "$movie_database" ]]; then
    # shellcheck disable=SC2128
    movie_database=$(grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" "$nfo_file" | grep 'tvmaze.com\|thetvdb.com\|port.hu\|rottentomatoes.com\|mafab.hu' | head -1)
  fi
  if [[ -z "$movie_database" ]]; then
    printf 'Scraping IMDb for title.\n'
    search_name_imdb=$(curl -s "https://v2.sg.media-imdb.com/suggestion/t/$imdb.json" | jq -r 'if .d then .d[0].l else empty end')
    printf 'Scraping port.hu for link with title: \e[93m%s\e[0m\n' "$search_name_imdb"
    movie_database=$(curl -s "https://port.hu/search/suggest-list?q=$search_name_imdb" | jq -r 'if length > 0 then "https://port.hu\(.[0].url)" else empty end')
  fi

  # Grabbing infobar page.
  printf '%s\n' "Saving infobar."
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
  # shellcheck disable=SC2128
  printf 'Category...: \e[93m%s\e[0m\n' "$type"
  printf 'IMDB.......: \e[93mhttps://www.imdb.com/title/%s\e[0m\n' "$imdb"
  printf 'link.......: \e[93m%s\e[0m\n' "$movie_database"

  # Grab description from port.hu
  # shellcheck disable=SC2154
  if [[ "$description" == true ]]; then
    if [[ "$movie_database" == *port.hu* ]]; then
      port_description=$(curl -s "$movie_database" | grep og:description | sed -r 's,>$, />,' | xmlstarlet sel -t -v '//meta/@content')
    else
	  printf '%s\n' "Scraping IMDb for title."
      search_name_imdb=$(curl -s "https://v2.sg.media-imdb.com/suggestion/t/$imdb.json" | jq -r 'if .d then .d[0].l else empty end')
      printf 'Scraping port.hu for link with title: \e[93m%s\e[0m\n' "$search_name_imdb"
      port_link=$(curl -s "https://port.hu/search/suggest-list?q=$search_name_imdb" | jq -r 'if length > 0 then "https://port.hu\(.[0].url)" else empty end')
      port_description=$(curl -s "$port_link" | grep og:description | sed -r 's,>$, />,' | xmlstarlet sel -t -v '//meta/@content')
    fi
	printf 'Description: \e[93m%.50s...\e[0m\n' "$port_description"
  fi


  if (( ! noupload )); then
    printf "Uploading. "
    # shellcheck disable=SC2128
    torrent_link=$(curl -Ls -o /dev/null -w "%{url_effective}" "https://ncorea.cc/upload.php" \
    -b "$cookies" \
    -F getUnique="$unique_id" \
    -F eredeti=igen \
    -F infobar_site=imdb \
    -F tipus="$type" \
    -F torrent_nev="$torrent_name" \
    -F torrent_fajl=@"$torrent_file" \
    -F nfo_fajl=@"$nfo_file" \
    -F szoveg="$port_description" \
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
    if [[ "$post_to_feed" == true ]]; then
      printf "Posting to feed.\n"
      torrent_id="${id_with_passkey%%&*}"
      curl "https://ncore.cc/torrents.php?action=addnews&id=$torrent_id&getunique=$unique_id" -b "$cookies" -s
    fi
  fi
  # Drawing a separator after each torrent.
  (( t++ ))
  if (( t < $# )); then
    print_separator
  fi
  unset imdb movie_database hun_title eng_title for_title release_date infobar_picture infobar_rank infobar_genres country runtime director cast seasons episodes
done

# Deleting thumbnails.
if [[ -f torrent_image_1.png ]]; then
  printf 'Deleting thumbnails.\n'
  rm torrent_image_*png
fi
