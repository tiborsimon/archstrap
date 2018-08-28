#! /bin/bash
set -e


readonly DEFAULT_BOOT_SIZE="200M"
readonly DEFAULT_SWAP_SIZE="4G"
readonly DEFAULT_ROOT_SIZE="10G"


repartition_init () {
  local window_width=$1
  local message="You are about to repartition your disk.\n\nYour current setup:"
  local current_text=$(lsblk -o NAME,SIZE,TYPE,FSTYPE,VENDOR)
  local divider=$(python -c "print('\n'+'-'*($window_width-4))")
  local lines=$(echo "$current_text" | wc -l)

  whiptail \
    --title "Disk partitioning (1/5)" \
    --ok-button "Next" \
    --msgbox "${message}${divider}${current_text}${divider}" $((11 + $lines)) ${window_width}
}

repartition_select_disk () {
  local window_width=$1
  local disks=$(lsblk -n -o NAME,TYPE | grep disk | tr -s '[:space:]' | cut -d ' ' -f 1)
  local count=$(echo "$disks" | wc -l)

  local selection="on"
  local command=""
  for disk in $disks; do
    command="$command $disk $selection"
    selection="off"
  done

  local header="\nSelect the disk you want to repartition:"

  local selected_disk=$(whiptail \
    --title "Disk partitioning (2/5)" \
    --ok-button "Select" \
    --nocancel \
    --noitem \
    --radiolist "${header}" "$((8 + ${count}))" ${window_width} ${count} ${command} \
    3>&1 1>&2 2>&3)
  echo $selected_disk
}

repartition_input_size () {
  local window_width=$1
  local disk=$2


  local divider=$(python -c "print('-'*($window_width-4))")
  local header="\nTarget disk: ${disk}\n\nSet partition sizes:\n${divider}\n"`
              `" ${disk}1 - boot - ? ${DEFAULT_BOOT_SIZE} ?\n"`
              `" ${disk}2 - swap - ? ${DEFAULT_SWAP_SIZE} ?\n"`
              `" ${disk}3 - root - ? ${DEFAULT_ROOT_SIZE} ?\n"`
              `" ${disk}4 - home - remaining\n${divider}\n"`
              `"\nBOOT SWAP and ROOT partition sizes:"
  local sizes=$(whiptail \
    --title "Disk partitioning (3/5)" \
    --ok-button "Next" \
    --nocancel \
    --noitem \
    --inputbox "${header}" 19 ${window_width} "${DEFAULT_BOOT_SIZE} ${DEFAULT_SWAP_SIZE} ${DEFAULT_ROOT_SIZE}" \
    3>&1 1>&2 2>&3)
    echo $(echo "$sizes" | tr -s '[:space:]')
}

repartition_summary () {
  local window_width=$1
  local disk=$2
  local sizes=$3
  local boot_size=$(echo "$sizes"| cut -d ' ' -f 1)
  local swap_size=$(echo "$sizes"| cut -d ' ' -f 2)
  local root_size=$(echo "$sizes"| cut -d ' ' -f 3)
  local divider=$(python -c "print('-'*($window_width-4))")
  echo $sizes

  local header="Selected configuration for ${disk}:\n${divider}\n"`
              `" ${disk}1 - boot - ${boot_size}\n"`
              `" ${disk}2 - swap - ${swap_size}\n"`
              `" ${disk}3 - root - ${root_size}\n"`
              `" ${disk}4 - home - remaining\n${divider}\n"`
              `"\nAre you ABSOLUTELY sure you want to repartition disk $disk?\n\nThere is NO GOING BACK after this! Existing data will be lost!"
  if (! whiptail \
      --title "Disk partitioning (4/5)" \
      --yes-button "DO IT!" \
      --no-button "CANCEL" \
      --defaultno \
      --fullbuttons \
      --yesno "$header" 21 ${window_width} ) then
    return 1
  fi
}

repartition_execute () {
  local disk=$1
  local sizes=$2

  local boot_size=$(echo "$sizes"| cut -d ' ' -f 1)
  local swap_size=$(echo "$sizes"| cut -d ' ' -f 2)
  local root_size=$(echo "$sizes"| cut -d ' ' -f 3)

  echo "
    o # clear the in memory partition table
    n # new partition
    p # primary partition
    1 # partition number 1
      # default - start at beginning of disk 
    +${boot_size} # 100 MB boot partition
    n # new partition
    p # primary partition
    2 # partion number 2
      # default, start immediately after preceding partition
    +${swap_size} # predefined swap partition size
    n # new partition
    p # primary partition
    3 # partion number 3
      # default, start immediately after preceding partition
    +${root_size} # predefined root partition size
    n # new partition
    p # last primary partition, partition number will be selected automatically
      # default, start immediately after preceding partition
      # default, fill up the disk
    w # write the partition table" \
      | sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' | fdisk /dev/${disk} 2>&1 >/dev/null
  return $?
}

repartition_result () {
  local window_width=$1
  local current=$(lsblk -o NAME,SIZE,TYPE,FSTYPE,VENDOR)
  local lines=$(echo "$current" | wc -l)

  local divider=$(python -c "print('\n'+'-'*($window_width-4))")
  local message="Disk partitioning finished!\n\nThe resulted configuration:"
  if (! whiptail \
      --title "Disk partitioning (5/5)" \
      --yes-button "Ok" \
      --msgbox "${message}${divider}${current}${divider}" $((11 + $lines)) ${window_width} ) then
    return
  fi
}


repartition () {
  local window_width=44

  repartition_init $window_width
  local disk=$(repartition_select_disk $window_width)
  local sizes=$(repartition_input_size $window_width $disk)
  if ( repartition_summary $window_width $disk "$sizes" ) then
    if ( repartition_execute $disk "$sizes" ) then
      repartition_result $window_width
    else
      echo "Unexpected error happened.."
    fi
  else
    echo "Skipping disk partitioning."
  fi
}


repartition

# clear
echo "Install script finished."



