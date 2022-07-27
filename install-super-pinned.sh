#!/bin/bash

keybind_name="super-pinned-"
tmpfile="/tmp/super-pinned.dconf"


script_path=$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd )

custom_keybindings_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
custom_keybindings=$(dconf read $custom_keybindings_path)
custom_keybindings=${custom_keybindings:1:-1}
custom_keybindings=${custom_keybindings//,}
keybinding_list=( $custom_keybindings )

declare -a new_list
for (( index=0; index < ${#keybinding_list[@]}; index++ )); do
    item=${keybinding_list[$index]}
    tail=${item#*/custom-keybindings/}
    if [[ "$tail" =~ "$keybind_name" ]]; then
        keybinding_list[$index]=""
    else
        new_list+=( $item )
    fi
    # printf "#: %s\n" "$item"
done
# Remove old super-pinned bindings

: > "$tmpfile" 
for ((key=0; key<10; key++)); do    
    item="'$custom_keybindings_path/${keybind_name}$key/'"
    new_list+=( $item )
    cat - >> "$tmpfile" << EOF
[${keybind_name}$key]
binding='<Super>$key'
command='$script_path/SuperKey.sh --key=$key'
name='Super pinned $key'

EOF
    item="'$custom_keybindings_path/${keybind_name}shift-$key/'"
    new_list+=( $item )
    cat - >> "$tmpfile" << EOF
[${keybind_name}shift-$key]
binding='<Super><Shift>$key'
command='$script_path/SuperKey.sh --key=$key --new'
name='Super pinned force new $key'

EOF
    item="'$custom_keybindings_path/${keybind_name}alt-$key/'"
    new_list+=( $item )
    cat - >> "$tmpfile" << EOF
[${keybind_name}alt-$key]
binding='<Super><Alt>$key'
command='$script_path/SuperKey.sh --key=$key --reverse'
name='Super pinned reverse $key'

EOF
done

new_keybindings=$(printf ", %s" "${new_list[@]}")
new_keybindings="[${new_keybindings:2}]"

dconf load "${custom_keybindings_path}/" < "$tmpfile"

# Critical, can crash the system if gsd-media-keys is not updated to ...
dconf write "${custom_keybindings_path}" "$new_keybindings"

dconf read "${custom_keybindings_path}"
dconf dump "${custom_keybindings_path}/"
rm "$tmpfile"
