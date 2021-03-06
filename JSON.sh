#!/usr/bin/env bash

throw () {
  echo "$*" >&2
  exit 1
}

BRIEF=0

tokenize () {
  local ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
  local CHAR='[^[:cntrl:]"\\]'
  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'
  egrep -ao "$STRING|$NUMBER|$KEYWORD|$SPACE|." --color=never |
    egrep -v "^$SPACE$"  # eat whitespace
}

parse_array () {
  local index=0
  local ary=''
  read -r token
  case "$token" in
    ']') ;;
    *)
      while :
      do
        parse_value "$1" "array_elem$index"
        let index=$index+1
        ary="$ary""$value"
        read -r token
        case "$token" in
          ']') break ;;
          ',') ary="$ary," ;;
          *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
      ;;
  esac
  [[ $BRIEF -ne 1 ]] && value=`printf '[%s]' "$ary"`
}

parse_object () {
  local key
  local obj=''
  read -r token
  case "$token" in
    '}') ;;
    *)
      while :
      do
        case "$token" in
          '"'*'"') key=$token ;;
          *) throw "EXPECTED string GOT ${token:-EOF}" ;;
        esac
        read -r token
        case "$token" in
          ':') ;;
          *) throw "EXPECTED : GOT ${token:-EOF}" ;;
        esac
        read -r token
        parse_value "$1" "$key"
        obj="$obj$key:$value"
        read -r token
        case "$token" in
          '}') break ;;
          ',') obj="$obj," ;;
          *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
    ;;
  esac
  [[ $BRIEF -ne 1 ]] && value=`printf '{%s}' "$obj"`
}

parse_value () {
  local jpath=$(echo "$2" | tr -d "\"")

  case "$token" in
    '{')
        echo "<$jpath>"
        parse_object "$jpath"
        echo "</$jpath>"
        ;;
    '[')
        echo "<$jpath>"
        parse_array "$jpath"
        echo "</$jpath>"
        ;;
    # At this point, the only valid single-character tokens are digits.
    ''|[^0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
    *)
        value=$token
        echo "<$jpath>$value</$jpath>"
        ;;
  esac
  [[ ! ($BRIEF -eq 1 && ( -z $jpath || $value == '""' ) ) ]] \
      && printf "[%s]\t%s\n" "$jpath" "$value"
}

parse () {
  echo '<?xml version="1.0"?>'
  read -r token
  parse_value "" "json"
  read -r token
  case "$token" in
    '') ;;
    *) throw "EXPECTED EOF GOT $token" ;;
  esac
}

[[ -n $1 && $1 == "-b" ]] && BRIEF=1

if [ $0 = $BASH_SOURCE ];
then
  tokenize | parse
fi
