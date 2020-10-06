# !/bin/sh
# use commands [jq wc curl cat grep dirname basename]
IFS=$'\n'

CONFIG_FILE="./config/settings.json"
COOKIE_FILE="./config/cookie"
TASK_FILE="./config/nijie.task"
if [ -z "$1" ]; then
  scriptname=$(basename $0)
  echo -e -n "\033[0;32m"; echo -n " # login"; echo -e "\033[0;0m"
  echo " ./$scriptname login"
  echo -e -n "\033[0;32m"; echo -n " # illust download"; echo -e "\033[0;0m"
  echo " ./$scriptname https://nijie.info/view.php?id=00000"
  echo -e -n "\033[0;32m"; echo -n " # member page illusts download"; echo -e "\033[0;0m"
  echo " ./$scriptname https://nijie.info/members.php?p=1&id=00000"
  echo -e -n "\033[0;32m"; echo -n " # member all page illusts download"; echo -e "\033[0;0m"
  echo " ./$scriptname https://nijie.info/members.php?id=00000"
  exit 0
fi

if [ -z "$(pgrep -a bash | grep -oP "$(basename $0).+main")" ]; then
  bash "$(pwd)/$(basename $0)" $(IFS=$'\n'; echo "${*}" | sed -e ':loop; N; $!b loop; s/\n/\" \"/g') "main"
  exit 0
elif [ "${@:$#}" != "main" ]; then
  echo "$(IFS=$'\n'; echo "[\"${*}\"]" | sed -e ':loop; N; $!b loop; s/\n/\" \"/g')" >> "$TASK_FILE"
  exit 0
fi

if [ -f "$CONFIG_FILE" ]; then
  USERAGENT=$(cat "$CONFIG_FILE" | jq -r ".USERAGENT")
  FILENAME_RULE=$(cat "$CONFIG_FILE" | jq -r ".FILENAME_RULE")
else
  # default config
  USERAGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:81.0) Gecko/20100101 Firefox/81.0"
  FILENAME_RULE="./downloads/[author_id] ([author])/[illust_id]_[index] - [title].[ext]"
  # generate config file
  [[ ! -d "$(dirname "$CONFIG_FILE")" ]] && mkdir -p "$(dirname "$CONFIG_FILE")"
  echo "{\"USERAGENT\":\"$USERAGENT\",\"FILENAME_RULE\":\"$FILENAME_RULE\"}" | jq > "$CONFIG_FILE"
fi

if [ ! -f "$COOKIE_FILE" ]; then
  echo -e -n "\033[0;31m"; echo -n "not find COOKIE login needed."; echo -e "\033[0;0m"
  echo -e -n "\033[0;33m"; echo -n "./nijie.sh login"; echo -e "\033[0;0m"
fi

RULE_UNSTABLE=("author" "title" "ext")
RULE_RESPONSIVE=("author" "title")
 
function get_task(){
  task=($(cat "$TASK_FILE"))
  echo "${task[0]}"
  unset task[0]
  echo -n "${task[*]}" > "$TASK_FILE"
}

function view_wait(){
  local wait=$1
  for ((i = 0; i < $wait; i++));do
    echo -ne "wait $(($wait-$i))sec \r"
    sleep 1;
  done
  echo -ne $(eval "printf \" %.s\" {1..$(tput cols)}");echo -ne "\r"
}

function rule_accept(){
  local rule="$1";
  local dict="$(declare -p $2)";eval "declare -A dict=${dict#*=}"
  local responsive=(${3})
  local array=($(echo "$rule" | grep -oP "[^/]+"))
  for ((i = 0; i < ${#array[@]}; i++));do
    local temp="${array[$i]}"
    for v in "${responsive[@]}"; do temp="$(echo "${temp}" | sed "s/\[$v\]//g")"; done
    for key in ${!dict[@]}; do local value=$(echo "${dict[$key]}"|sed "s/\//_/g");temp="$(echo "$temp" | sed "s/\[$key\]/$value/g")"; done
    local min_length=$(echo "$temp" | wc -c)
    temp="${array[$i]}"
    for key in ${!dict[@]}; do
      local value=$(echo "${dict[$key]}"|sed "s/[\/\\:\*\?\"\<\>\|]/_/g")
      if [ "$(echo -n "${responsive[*]}" | grep -xoF "$key")" != "" ];then
        local margin=$(echo -ne "$((250-min_length-1))\n0"|sort -n|tail -1)
        value="$(echo -n "$value"|cut -b -$margin|sed "s/\//_/g")"
        if [ $margin -gt 0 ]; then value="$(echo -n "${value}"|cut -b -$margin)"; else value=""; fi
        local length=$(echo -n "$value"|wc -c)
        min_length=$((min_length-length))
      fi
      local a2=($(echo "$value" | grep -oP "[^/]+"))
      value="$(IFS=_; echo "${a2[*]}")"
      temp="$(echo "$temp" | sed "s/\[$key\]/$value/g")"
    done
    array[$i]="$temp"
  done
  [[ "$rule" == /* ]] && echo -n "/"
  echo "$(IFS=/; echo "${array[*]}")"
}

function ruleble_directory_searth(){
  local rule="$1"
  local dict="$(declare -p $2)";eval "declare -A dict=${dict#*=}"
  local unstable=(${3})
  local responsive=(${4})
  for v in "${unstable[@]}"; do rule="$(echo "$rule" | sed "s/\[$v\]/*/g")"; done
  local wc="$(rule_accept "$rule" dict "${responsive[*]}")"
  local depth=$(echo "$rule" | grep -o "/" | wc -l)
  [[ -d "$(dirname "$wc")" ]] && find "$(dirname "$wc")" -maxdepth $((depth-1)) -type d -name "$(basename "$wc")"
}

function ruleble_file_searth(){
  local rule="$1"
  local dict="$(declare -p $2)";eval "declare -A dict=${dict#*=}"
  local unstable=(${3})
  local responsive=(${4})
  for v in "${unstable[@]}"; do rule="$(echo "$rule" | sed "s/\[$v\]/*/g")"; done
  local filename="$(rule_accept "$(basename "$rule")" dict "${responsive[*]}")"
  local directoryname=$(ruleble_directory_searth "$(dirname $rule)" dict "${unstable[*]}" "${RULE_RESPONSIVE[*]}")
  local depth=$(echo "$rule" | grep -o "/" | wc -l)
  [[ -d "$directoryname" ]] && find "$directoryname" -maxdepth $((depth-2)) -type f -name "$filename"
}

function nijie_login(){
  read -p "nijie id email: " email
  read -sp "nijie id password: " password; echo ""
  curl -X POST -d email="$email" -s -d password="$password" -c "$COOKIE_FILE" -A "$USERAGENT" "https://nijie.info/login_int.php"
  login_test
}

function login_test(){
  if [ -n "$(cat "$COOKIE_FILE" | grep n_session_hash)" ]; then
    echo "login ok."
  else
    echo "login error."
  fi
}

function illust_download(){
  local illust_id=$1;local user_id=$2
  local web=$(curl --silent -b "$COOKIE_FILE" -A "$USERAGENT" "https://nijie.info/view.php?id=$illust_id")
  echo -e -n "\033[0;33m"; echo -n "Get => https://nijie.info/view.php?id=$illust_id"; echo -e "\033[0;0m"
  local username=$(echo "$web" | grep -oP "(?<=<p class=\"user_icon\">)(.*)?(?=</p>)" | grep -oP "(?<=<br />)(.*)(?=<br />)")
  local title="$(echo "$web" | grep -oP "(?<=<h2 class=\"illust_title\">)(.*)?(?=</h2>)")"
  local tags="$(echo "$web" | grep -oP "(?<=<span class=\"tag_name\">)(<a href=\"[^\"]+\">).+?(</a>)(?=</span>)" | grep -oP "(?<=\">).*(?<=\">)(.+)(?=</a>)")"
  echo "author: \"${username}\""
  echo "title: \"${title}\""
  echo "tag: [\"$(echo "${tags[@]}" | sed -e ':loop; N; $!b loop; s/\n/\", \"/g')\"]"
  local urls="$(echo "$web" | grep -oP "(illust_id=[\"']$illust_id[\"'] user_id=[\"'][0-9]+[\"'] itemprop=\"image\" src=\"[^\"]+/nijie_picture[^\"]+\.[a-zA-Z0-9]+\")|(user_id=[\"'][0-9]+[\"'] illust_id=[\"']$illust_id[\"'] src=\"[^\"]+/nijie_picture[^\"]+\.[a-zA-Z0-9]+\")")"
  if [ -n "$urls" ]; then
    local image_index=-1
    for url in ${urls[@]}; do
      local user_id=$(echo "$url" | grep -oP "(?<=user_id=[\"'])([0-9]+)(?=[\"'])")
      local image_url="https:$(echo "$url" | grep -oP "(?<=src=\")(.+)(?=\")")"
      local image_original_url="$(echo "$image_url" | grep -oP ".+pic.nijie.net/[0-9]+/")$(echo "$image_url" | grep -oP "nijie_picture.*$")"
      local image_ext=$(echo $image_url | grep -oP "(?<=\.)([a-zA-Z0-9]+)$")
      image_index=$((image_index+1))
      declare -A rule_values=(
        ["author_id"]="$user_id"
        ["author"]="$username"
        ["title"]="$title"
        ["ext"]="$image_ext"
        ["index"]="$image_index"
        ["illust_id"]="$illust_id"
      )
      if [ -n "$(ruleble_file_searth "$FILENAME_RULE" rule_values "${RULE_UNSTABLE[*]}" "${RULE_RESPONSIVE[*]}")" ]; then
        echo "already ${illust_id}_${image_index}${image_ext}"
      else
        echo "Download => $image_original_url"
        local output_dirctory="$(ruleble_directory_searth "$(dirname $FILENAME_RULE)" rule_values "${RULE_UNSTABLE[*]}" "${RULE_RESPONSIVE[*]}")"
        local file_path="$(rule_accept "$FILENAME_RULE" rule_values "${RULE_RESPONSIVE[*]}")"
        if [ -z "$output_dirctory" ]; then
          output_dirctory="$(dirname "$file_path")"
          mkdir -p "$(dirname "$file_path")"
        fi
        file_path="${output_dirctory}/$(basename "$file_path")"
        curl -# -A "$USERAGENT" "$image_original_url" > "$file_path"
        sleep 1
      fi
    done
  fi
}

function member_illusts(){
  local page="$1"; local user_id="$2"; local allpage="$3"
  [[ -z $page ]] && page=1 && allpage="yes"

  local web=$(curl --silent -b "$COOKIE_FILE" -A "$USERAGENT" "https://nijie.info/members_illust.php?p=$page&id=$user_id")
  echo -e -n "\033[0;33m"; echo -n "Get => https://nijie.info/members_illust.php?p=$page&id=$user_id"; echo -e "\033[0;0m"
  local username=$(echo "$web" | grep -oP "(?<=<p class=\"user_icon\">)(.*)?(?=</p>)" | grep -oP "(?<=<br />)(.*)(?=<br />)")
  local illusts=$(echo "$web" | grep -oP "(?<=<img class=\"mozamoza ngtag\" illust_id\=\")[^\"]+")
  echo "username: \"${username}\""

  for illust_id in ${illusts[@]}
  do
    declare -A rule_values=(
      ["author_id"]="$user_id"
      ["author"]="$username"
      ["illust_id"]="$illust_id"
      ["index"]="0"
    )
    if [ -n "$(ruleble_file_searth "$FILENAME_RULE" rule_values "${RULE_UNSTABLE[*]}" "${RULE_RESPONSIVE[*]}")" ]; then
      echo "already illust_id=$illust_id"
    else
      illust_download $illust_id $user_id
      view_wait 3
    fi
  done

  page=$((++page))
  [[ "$allpage" = "yes" && -n "$(echo "$web" | grep -oP "/members_illust.php\?p=$page&id=$user_id")" ]] && member_illusts "$page" "$user_id" "yes"
}

arg1="$1"
while true ; do
  #login
  #nijie.sh login
  [[ "$arg1" = "login" ]] && nijie_login

  #Image URL
  #nijie.sh https://nijie.info/view.php?id=00000
  id=$(echo "$arg1" | grep -oP "(?<=nijie\.info/view\.php\?id=)[0-9]+$")
  [[ -n "$id" ]] && illust_download "$id"
  #Member Illusts URL
  #nijie.sh https://nijie.info/members.php?id=00000
  id="$(echo "$arg1" | grep -oP "(?<=nijie\.info/members\.php\?)(id=[0-9]+)$")"
  [[ -n "$id" ]] && member_illusts "" "$(echo "$id" | grep -oP "(?<=id=)[0-9]+")"
  #nijie.sh https://nijie.info/members_illust.php?p=0&id=00000
  id="$(echo "$arg1" | grep -oP "(?<=nijie\.info/members_illust\.php\?)(p=[0-9]+&)?(id=[0-9]+)$")"
  [[ -n "$id" ]] && member_illusts "$(echo "$id" | grep -oP "(?<=p=)[0-9]+")" "$(echo "$id" | grep -oP "(?<=id=)[0-9]+")"

  [[ -f "$TASK_FILE" ]] && args=($(get_task | jq -r .[])) && arg1="${args[0]}" && [[ -z "$args" ]] && rm "$TASK_FILE"
  [[ ! -f "$TASK_FILE" || -z "$args" ]] && break
done