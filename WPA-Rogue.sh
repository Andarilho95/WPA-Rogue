#!/usr/bin/bash

select_nic() {
# localiza as wifi_nics no sistema
  local nics=()
  while read -r iface; do
    if [[ -d "$iface/wireless" ]]; then
      nics+=("$(basename "$iface")")
    fi
  done < <(find /sys/class/net -type l)
#verifica a existencia de wifi_nics se não script ends
  if [[ ${#nics[@]} -eq 0 ]]; then
      echo "No Wi-Fi interfaces found."
      exit 1
  fi
  # Print numbered list of network interfaces
  echo "Select a network interface:"
  for i in "${!nics[@]}"; do
    echo "$((i+1))) ${nics[i]}"
  done

  # Prompt the user to choose one
  local choice
  while true; do
    read -rp "Enter the number of the desired interface: " choice
    # Check if input is a valid number within range
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#nics[@]} )); then
      # Store the selected interface in a global variable
      selected_nic="${nics[choice-1]}"
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done
}

kill_process() {
  raw_output=$(airmon-ng check "$selected_nic") #checa necessidade de finalização de processos
  if [ -n "$raw_output" ]; then # verfifica se se há output do airmon-ng
    echo "há output"
    #echo "$raw_output"   # Debug opcional
    # extrai todos os PIDs do raw_output apenas os respectivos numeros
    mapfile -t pids < <(echo "$raw_output" | awk 'NR > 1 && $1 ~ /^[0-9]+$/ { print $1 }')
    echo "Esses processos podem impactar na captura do WPA-Handshake"
    echo "$raw_output" | awk '/PID/ {f=1} f' 
    # perguntando se quer finalizar processos
      read -p "Deseja finalizalos? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
          echo "iniciando kill"
          check_dead() {
          for i in {1..10}; do
          sleep 0.5
            if kill -0 "$pid" 2>/dev/null; then
              echo "processo rodando $pid"
              if [ "$i" -eq 10 ]; then
              echo "Falha ao finalizar $pid"
              break
              fi
            else
              echo "processo morto"
              break
            fi
          done
          }

          for pid in "${pids[@]}"; do
            service_name=$(systemctl status "$pid" | grep -oP 'Loaded:.*?\K\w+\.service') #captura o nome dos serviços systemd
            if [ -n "$service_name" ]; then
              echo "é um serviço $service_name"
              echo "finalizando via systemd"
              systemctl stop "$service_name"
              echo "$pid"
              check_dead
            # else
            #   echo "não é um service"
            #   echo "finalizando via kill"
            fi
          done
          # finaliza processos
          for pid in "${pids[@]}"; do
            echo "Tentando finalizar PID $pid..."
            kill "$pid" 2>/dev/null
            check_dead
          done
          # mata processos
          for pid in "${pids[@]}"; do
            echo "Tentando matar a força $pid..."
            kill -9 "$pid" 2>/dev/null
            check_dead
          done

        fi
    else
    echo "não output"
  fi
}

select_nic

echo "You selected: $selected_nic"

kill_process

