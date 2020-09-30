#!/bin/bash
LC_ALL=C.UTF-8
LANG=C.UTF-8

# image generator
imagegen() {
  printf '\rSaving screenshots: [0/00] 0%%'
  images=12
  seconds=$(ffprobe "$1" -v quiet -print_format json -show_format | jq -r '.format.duration')
  interval=$(bc <<< "scale=4; $seconds/($images+1)")
  for i in {1..12}; do
    framepos=$(bc <<< "scale=4; $interval*$i")
    ffmpeg -y -v quiet -ss "$framepos" -i "$1" -frames:v 1 -q:v 100 -compression_level 6 "image_$i.webp"
    printf '\rSaving screenshots: [%d/%d] %d%%' "$i" "$images" "$(bc <<< "$i*100/12")"
  done
  printf '\n'
  z=0
  # shellcheck disable=SC2012
  for i in $(ls -S1 image*webp | head -n 9 | sort); do
    (( z++ ))
    mv "$i" screenshot_"$z".webp
  done
}

# image uploader
keksh() {
  curl -fsSL https://kek.sh/api/v1/posts -F file="@$1" | jq -r '"https://i.kek.sh/\(.filename)"'
}

# bbcode generator
generate_screenshot_bbcode() {
  screenshot_bb_code='[spoiler=Screenshots][center]'
  printf '\rUploading screenshots: [0/6]'
  s=0
  for i in {4..9}; do
    (( s++ ))
    ffmpeg -y -v quiet -i screenshot_"$i".webp -vf scale=220:-1 -qscale:v 3 screenshot_"$i"_small.jpg
    # shellcheck disable=SC2030
    img=$(keksh screenshot_"$i".webp || { screenshot_bb_code=''; return; })
    imgsmall=$(keksh screenshot_"$i"_small.jpg || { screenshot_bb_code''; return; })
    printf '\rUploading screenshots: [%d/6] %s, %s' "$s" "$img" "$imgsmall"
    # shellcheck disable=SC2031
    (( i == 4 )) && screenshot_bb_code+=$'\n'
    screenshot_bb_code+="[url=$img][img]${imgsmall}[/img][/url] "
  done
  printf '\n'
  screenshot_bb_code+=$'\n[i]  (Kattints a képekre a teljes felbontásban való megtekintéshez.)[/i][/center][/spoiler]'
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
    mkdir -p ~/.ncup
    printf 'Missing config, saving default in: \e[93m%s\e[0m\n' "$config"
    printf '%s\n' "$default_config" > "$config"
    config_created=1
  fi
}

infobar_checker() {
  if [[ ! -f "$infobar" ]]; then
    mkdir -p ~/.ncup
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

login() {
  read -r -p 'username...: ' username
  read -r -s -p 'password...: ' password
  printf '\n'
  read -r -p '2factor....: ' twofactor
  curl 'https://ncore.cc/login.php?2fa' -c "$cookies" -s -d "submitted=1" \
  --data-urlencode "nev=$username" --data-urlencode "pass=$password" \
  --data-urlencode "2factor=$twofactor" -d "ne_leptessen_ki=1"
  if [[ $(curl -s -I -b "$cookies" 'https://ncore.cc/' -o /dev/null -w '%{http_code}') == 200 ]]; then
    printf '\e[92m%s\e[0m\n' "Successful login."
  else
    printf '\e[91m%s\e[0m\n' "ERROR: Login failed, wrong password/2FA or maybe a captcha appeared." >&2
    rm -f "$cookies"
    exit 1
  fi
}

extract_nfo_urls() {
  nfo_urls=$(grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" "$1")
  if [[ "$extract_urls" == true ]]; then
    nfo_urls=$(while IFS= read -r line; do
      if grep 'imdb.com\|tvmaze.com\|thetvdb.com\|port.hu\|rottentomatoes.com\|mafab.hu' <<< "$line"; then
        echo "$line"
      else
        curl -Ls -o /dev/null -w "%{url_effective}" "$line"
      fi
    done <<< "$nfo_urls")
  fi
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

default_config=$(cat <<'EOF'
torrent_program='pmktorrent'
screenshots_in_upload='true'
screenshots_in_description='false'
port_description='true'
port_description_before_screenshots='false'
post_to_feed='false'
print_infobar='false'
anonymous_upload='false'
extract_urls='true'
EOF
)

default_infobar=$(cat <<'EOF'
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
    d) mkdir -p ~/.ncup
       printf '%s\n' "$default_config" > "$config"
       printf 'Copied default config in: \e[93m%s\e[0m\n' "$config"
       exit 0;;
    e) mkdir -p ~/.ncup
       printf '%s\n' "$default_infobar" > "$infobar"
       printf 'Copied default infobar in: \e[93m%s\e[0m\n' "$infobar"
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
[[ -z "$torrent_program" ]] && torrent_program='pmktorrent'
[[ -z "$screenshots_in_upload" ]] && screenshots_in_upload='true'
[[ -z "$screenshots_in_description" ]] && screenshots_in_description='false'
[[ -z "$port_description" ]] && port_description='true'
[[ -z "$port_description_before_screenshots" ]] && port_description_before_screenshots='false'
[[ -z "$post_to_feed" ]] && post_to_feed='false'
[[ -z "$print_infobar" ]] && print_infobar='false'
[[ -z "$anonymous_upload" ]] && anonymous_upload='false'
[[ -z "$extract_urls" ]] && extract_urls='true'

# Anonymous upload config.
if [[ "$anonymous_upload" == true ]]; then
  anonymous='igen'
elif [[ "$anonymous_upload" == false ]]; then
  anonymous='nem'
else
  printf '\e[91m%s\e[0m\n' "ERROR: Unsupported anonymous value." >&2
  exit 1
fi

# Searching for cookies.txt next to the script,
# if it doesn't exist, show login prompt.
# If login fails exit.
if [[ -f "$cookies" ]]; then
  if [[ $(curl -s -I -b "$cookies" 'https://ncore.cc/' -o /dev/null -w '%{http_code}') == 200 ]]; then
    printf '\e[92m%s\e[0m\n' "Cookies OK."
  else
    printf '\e[91m%s\e[0m\n' "ERROR: cookies.txt does not work, login: "
    login
  fi
else
  mkdir -p "$(dirname "$cookies")"
  printf '\e[91m%s\e[0m\n' "ERROR: cookies.txt is missing, login: "
  login
fi

# Grabbing the getUnique id.
printf "Grabbing getUnique id: "
unique_id=$(curl https://ncore.cc -b "$cookies" -s | grep -o -P '(?<=exit.php\?q=).*(?=" id="menu_11")')
printf '\e[93m%.15s...\e[0m\n' "$unique_id"
print_separator

# Creating NFO and torrent file if something is missing.
# Exit if there are multiple NFO files or no video files in the folder.
for x in "$@"; do
  torrent_name=$(basename "$x")
  torrent_file="$torrent_name".torrent
  nfo_files=("$x"/*.nfo)
  nfo_file="${nfo_files[0]}"
  printf '\e[92m%s\e[0m\n' "$torrent_name"
  file=$(find "$x" -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" | head -n 1)
  if [[ ! -f "$file" ]]; then
    printf '\e[91m%s\e[0m\n' "ERROR: No video files were found."
    exit 1
  fi
  if (( ${#nfo_files[@]} > 1 )); then
    printf '\e[91m%s\e[0m\n' "ERROR: Multiple NFO files were found." >&2
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
      if [[ "$torrent_program" == pmktorrent ]]; then
        animation &
        pid=$!
        pmktorrent -q -a http://bithumen.be:11337/announce -l 24 -o "$torrent_file" "$x"
        kill -PIPE "$pid"
      elif [[ "$torrent_program" == mktorrent ]]; then
        mktorrent -a http://bithumen.be:11337/announce -l 24 -o "$torrent_file" "$x" | while read -r; do printf '\r\e[K%s' "$REPLY"; done
      elif [[ "$torrent_program" == mktor ]]; then
        animation &
        pid=$!
        mktor "$x" http://bithumen.be:11337/announce --chunk-min 16M --chunk-max 16M -o "$torrent_file" &> /dev/null
        kill -PIPE "$pid"
      else
        printf '\e[91m%s\e[0m\n' "ERROR: Unsupported torrent program." >&2
        exit 1
      fi
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
  resolution=$(grep -oP '\d+(?=[ip])' <<< "$torrent_name")
  type=xvid
  if (( resolution >= 720 )); then
    type=hd
  fi
  if grep -qE "(S|E)[0-9][0-9]" <<< "$torrent_name"; then
    type+=ser
  fi
  if grep -qEi "\.hun(\.|\-)" <<< "$torrent_name"; then
    type+=_hun
  fi

  # Generating screenshots.
  if [[ "$screenshots_in_upload" == true ]] || [[ "$screenshots_in_description" == true ]]; then
    file=$(find "$x" -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" | sort -n | head -n 1)
    imagegen "$file"
    if [[ "$screenshots_in_upload" == true ]]; then
      for i in {1..3}; do
        ffmpeg -y -v quiet -i screenshot_"$i".webp screenshot_"$i".png
      done
      screenshot_1='@screenshot_1.png'
      screenshot_2='@screenshot_2.png'
      screenshot_3='@screenshot_3.png'
    fi
    if [[ "$screenshots_in_description" == true ]]; then
      generate_screenshot_bbcode
    fi
  fi

  # Setting IMDb id from NFO file if it's not set manually in infobar.txt,
  # if that fails it will scrape imdb.com for an id based on the torrent name.
  if [[ -z "$imdb" ]]; then
    # shellcheck disable=SC2128
    extract_nfo_urls "$nfo_file"
    imdb=$(grep -Poa '(tt[[:digit:]]*)(?=/)' <<< "$nfo_urls" | head -n 1)
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
    [[ -z "$nfo_urls" ]] && extract_nfo_urls "$nfo_file"
    movie_database=$(grep 'tvmaze.com\|thetvdb.com\|port.hu\|rottentomatoes.com\|mafab.hu' <<< "$nfo_urls" | head -1)
  fi
  if [[ -z "$movie_database" ]]; then
    printf 'Scraping IMDb for title: '
    search_name_imdb=$(curl -s "https://v2.sg.media-imdb.com/suggestion/t/$imdb.json" | jq -r 'if .d then .d[0].l else empty end')
    printf '\e[93m%s\e[0m\n' "$search_name_imdb"
    printf 'Scraping port.hu for link: '
    movie_database=$(curl -s "https://port.hu/search/suggest-list?q=$(jq -rR '@uri' <<< "$search_name_imdb")" | jq -r 'if length > 0 then "https://port.hu\(.[0].url)" else empty end')
    printf '\e[93m%s\e[0m\n' "$movie_database"
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
  if [[ "$port_description" == true ]]; then
    if [[ "$movie_database" == *port.hu* ]]; then
      port_link="$movie_database"
    else
      printf 'Scraping IMDb for title: '
      search_name_imdb=$(curl -s "https://v2.sg.media-imdb.com/suggestion/t/$imdb.json" | jq -r 'if .d then .d[0].l else empty end')
      printf '\e[93m%s\e[0m\n' "$search_name_imdb"
      printf 'Scraping port.hu for link: '
      port_link=$(curl -s "https://port.hu/search/suggest-list?q=$search_name_imdb" | jq -r 'if length > 0 then "https://port.hu\(.[0].url)" else empty end')
      printf '\e[93m%s\e[0m\n' "$port_link"
      if [[ -z "$port_link" ]]; then
        printf '\e[91m%s\e[0m\n' "ERROR: port.hu scraping failed."
        read -r -p 'port.hu link: ' port_link
      fi
    fi
    porthu_description=$(curl -s "$port_link" | grep -A1 'application/ld+json' | sed -r 's#<br ?/?>#\\n#gi' | xmlstarlet sel -t -v '//script/text()' 2>/dev/null | jq -r '.description // empty')
    printf 'Description: \e[93m%s...\e[0m\n' "${porthu_description:0:$(($(tput cols)-16))}"
  fi

  # Setup description.
  if [[ "$port_description" == true ]] && [[ "$screenshots_in_description" == true ]]; then
    if [[ "$port_description_before_screenshots" == true ]]; then
      description="$porthu_description"'

'"$screenshot_bb_code"
    else
      description="$screenshot_bb_code"'

'"$porthu_description"
    fi
  elif [[ "$port_description" == true ]] && [[ "$screenshots_in_description" == false ]]; then
    description="$porthu_description"
  elif [[ "$port_description" == false ]] && [[ "$screenshots_in_description" == true ]]; then
    description="$screenshot_bb_code"
  fi

  if (( ! noupload )); then
    printf "Uploading. "
    # shellcheck disable=SC2128
    torrent_link=$(curl -Ls -o /dev/null -w "%{url_effective}" "https://ncore.cc/upload.php" \
    -b "$cookies" \
    -F getUnique="$unique_id" \
    -F eredeti=igen \
    -F infobar_site=imdb \
    -F tipus="$type" \
    -F torrent_nev="$torrent_name" \
    -F torrent_fajl=@"$torrent_file" \
    -F nfo_fajl=@"$nfo_file" \
    -F szoveg="$description" \
    -F kep1="$screenshot_1" \
    -F kep2="$screenshot_2" \
    -F kep3="$screenshot_3" \
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
    printf 'Downloading: \e[93mhttps://ncore.cc/t/%s\e[0m\n' "${torrent_link//[!0-9]/}"
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
  unset imdb movie_database hun_title eng_title for_title release_date infobar_picture infobar_rank infobar_genres country runtime director cast seasons episodes nfo_urls
done

# Deleting screenshots.
if [[ "$screenshots_in_upload" == true ]] || [[ "$screenshots_in_description" == true ]]; then
  printf 'Deleting screenshots.\n'
  rm image*png screenshot*
fi
