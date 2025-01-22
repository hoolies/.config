#!/usr/bin/env bash

opacity=$(grep -Pe "opacity = " $HOME/.config/alacritty/alacritty.toml | cut -d" " -f3)


## Assign toggle opacity value
case $opacity in
  1)
    toggle_opacity=0.67
    ;;
  *)
    toggle_opacity=1
    ;;
esac

## Replace opacity value in alacritty.yml
sed -i -- "s/opacity = $opacity/opacity = $toggle_opacity/" \
    $HOME/.config/alacritty/alacritty.toml
