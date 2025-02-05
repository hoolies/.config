#!/bin/bash

#set -x

pad() {


  # Set terminal's width
  local width=$(tput cols)  # Get the current width of the terminal

  if [[ -z "$1" ]]; then
    echo -e "$help"
    exit 1
  fi

  local center="$1"

  if [ -z "$2" ]; then
    local left="------------({["
  else
    local left="$2"
  fi

  if [ -z "$3" ]; then
    local right="]})------------"
  else
    local right="$3"
  fi

  shift $((OPTIND-1))

  # Calculate what the free space between the strings is
  local padding=$(( (width - ${#center} - ${#left} - ${#right}) / 2 ))  # Calculate padding for centering the string

  if [ "$padding" -lt 0 ]; then
  # If the padding is a negative number that means that the string exceeds the size of the width of the terminal
    echo "$left $center $right"
  else
    # Print the left part, the padded string, and the right part
    printf "%s%*s%s%*s%s\n" "$left" $padding "" "$center" $padding "" "$right";
  fi
}

pad "$@"
