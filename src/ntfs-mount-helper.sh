#!/bin/bash

# Script: ntfs-mount-helper.sh
# Descrição: Verifica e corrige problemas com montagem de discos NTFS
# Uso: Executado como serviço após login

LOG_FILE="/var/log/ntfs-mount-helper.log"
FSTAB_FILE="/etc/fstab"
NTFS_FIX_COMMAND="ntfsfix"
MOUNT_COMMAND="mount"
UMOUNT_COMMAND="umount"
DMESG_CMD="dmesg"

# Função para log
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Função para verificar se dispositivo é NTFS
is_ntfs_device() {
    local device=$1
    local fstype=$(blkid -s TYPE -o value "$device" 2>/dev/null)
    [[ "$fstype" == "ntfs" ]] || [[ "$fstype" == "ntfs-3g" ]] || [[ "$fstype" == "ntfs3" ]]
}

# Função para obter discos NTFS do fstab
get_ntfs_fstab_entries() {
    # Extrai entradas NTFS não comentadas do fstab (inclui ntfs3)
    grep -E '^\s*[^#].*ntfs' "$FSTAB_FILE" | awk '{print $1, $2}'
}

# Função para verificar montagem
check_mount_status() {
    local mount_point=$1
    mountpoint -q "$mount_point"
    return $?
}

# Função para analisar dmesg em busca de erros NTFS
check_dmesg_for_errors() {
    local device=$1
    local device_name=$(basename "$device")
    
    # Verifica erros comuns no dmesg
    # Se encontrar erros, retorna 0 (true)
    if $DMESG_CMD -T | tail -50 | grep -i "ntfs" | grep -i "$device_name" | grep -E -i "(error|fail|dirty|corrupt)"; then
        return 0  # Encontrou erros
    fi
    
    return 1  # Sem erros encontrados
}

# Função para desmontar com segurança
safe_umount() {
    local mount_point=$1
    
    if check_mount_status "$mount_point"; then
        log_message "Desmontando $mount_point..."
        if $UMOUNT_COMMAND "$mount_point" 2>/dev/null; then
            log_message "Desmontagem bem-sucedida de $mount_point"
            return 0
        else
            log_message "Aviso: Não foi possível desmontar $mount_point normalmente, tentando lazy unmount..."
            $UMOUNT_COMMAND -l "$mount_point" 2>/dev/null
            sleep 2
            return 1
        fi
    fi
    return 0
}

# Função principal
main() {
    log_message "=== Iniciando verificação de discos NTFS ==="
    
    # Aguardar um pouco mais para garantir montagens do systemd
    sleep 5
    
    # Contadores
    local total_ntfs=0
    local fixed_count=0
    local error_count=0
    
    # Ler entradas NTFS do fstab
    while read -r device mount_point; do
        ((total_ntfs++))
        
        # Pular se device for UUID ou LABEL - converter para dispositivo
        if [[ "$device" =~ ^UUID= ]]; then
            uuid=${device#UUID=}
            device=$(blkid -U "$uuid" 2>/dev/null || echo "$device")
        elif [[ "$device" =~ ^LABEL= ]]; then
            label=${device#LABEL=}
            device=$(blkid -L "$label" 2>/dev/null || echo "$device")
        fi
        
        # Verificar se o dispositivo existe
        if [[ ! -b "$device" ]]; then
            log_message "AVISO: Dispositivo $device não encontrado, pulando..."
            continue
        fi
        
        # Verificar se é NTFS
        if ! is_ntfs_device "$device"; then
            log_message "INFO: $device não é NTFS, pulando..."
            continue
        fi
        
        log_message "Processando: $device -> $mount_point"
        
        # Verificar status de montagem
        if check_mount_status "$mount_point"; then
            log_message "  ✓ Montado corretamente em $mount_point"
            
            # Verificar erros no dmesg mesmo estando montado
            if ! check_dmesg_for_errors "$device"; then
                log_message "  ✓ Sem erros no dmesg, mantendo montado"
                continue  # Tudo OK, próximo dispositivo
            else
                log_message "  ✗ Problemas detectados no dmesg para $device"
                error_count=$((error_count + 1))
                
                # Desmontar para corrigir
                if safe_umount "$mount_point"; then
                    log_message "  Desmontado para correção"
                fi
            fi
        else
            log_message "  ✗ Não montado em $mount_point"
            error_count=$((error_count + 1))
        fi
        
        # Aplicar ntfsfix apenas se não estiver montado
        log_message "  Aplicando ntfsfix em $device..."
        
        # Tentar desmontar se estiver montado
        safe_umount "$mount_point"
        
        # Executar ntfsfix
        if $NTFS_FIX_COMMAND -d "$device" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "  ✓ ntfsfix aplicado com sucesso"
            fixed_count=$((fixed_count + 1))
        else
            log_message "  ✗ Falha ao aplicar ntfsfix"
            continue
        fi
        
        # Aguardar um momento
        sleep 2
        
        # Tentar montar - usar as opções originais do fstab
        log_message "  Montando $mount_point..."
        if $MOUNT_COMMAND "$mount_point" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "  ✓ Montagem bem-sucedida"
        else
            log_message "  ✗ Falha na montagem"
            
            # Extrair tipo de filesystem do fstab
            fs_type=$(grep "$mount_point" /etc/fstab | awk '{print $3}')
            
            # Tentar montagem com o tipo correto
            log_message "  Tentando montagem com tipo $fs_type..."
            if $MOUNT_COMMAND -t "$fs_type" "$device" "$mount_point" 2>&1 | tee -a "$LOG_FILE"; then
                log_message "  ✓ Montagem com tipo $fs_type bem-sucedida"
            else
                log_message "  ✗ Todas as tentativas de montagem falharam"
            fi
        fi
        
        echo "----------------------------------------"
        
    done < <(get_ntfs_fstab_entries)
    
    # Executar mount -a para garantir todas as montagens
    log_message "Executando 'mount -a' para montar todos os sistemas de arquivos..."
    $MOUNT_COMMAND -a 2>&1 | tee -a "$LOG_FILE"
    
    # Relatório final
    log_message "=== Relatório Final ==="
    log_message "Discos NTFS no fstab: $total_ntfs"
    log_message "Discos com problemas: $error_count"
    log_message "Discos corrigidos: $fixed_count"
    log_message "=== Verificação concluída ==="
    
    # Salvar última execução
    date > /var/run/ntfs-mount-helper.lastrun
}

# Executar função principal
main

exit 0