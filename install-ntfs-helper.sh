#!/bin/bash

# Script de instalação do NTFS Mount Helper

echo "Instalando NTFS Mount Helper..."

# 1. Verificar dependências
echo "Verificando dependências..."
if ! command -v ntfsfix &> /dev/null; then
    echo "Instalando ntfs-3g..."
    pacman -Sy --noconfirm ntfs-3g 
fi

if ! command -v blkid &> /dev/null; then
    echo "Instalando util-linux..."
    pacman -Sy --noconfirm util-linux
fi

# 2. Criar diretório para logs
mkdir -p /usr/local/bin
mkdir -p /var/log

# 3. Copiar script principal
echo "Copiando script principal..."
cp ./src/ntfs-mount-helper.sh /usr/local/bin/
chmod 755 /usr/local/bin/ntfs-mount-helper.sh

# 4. Configurar serviço systemd
echo "Configurando serviço systemd..."
cp ./systemd/ntfs-mount-helper.service /etc/systemd/system/

# 5. Recarregar systemd
echo "Recarregando systemd..."
systemctl daemon-reload

# 6. Habilitar serviço
echo "Habilitando serviços..."
systemctl enable ntfs-mount-helper.service

# 7. Iniciar serviço
echo "Iniciando serviço..."
systemctl start ntfs-mount-helper.service

echo "Instalação concluída!"
echo ""
echo "Comandos úteis:"
echo "  Ver status: systemctl status ntfs-mount-helper"
echo "  Ver logs: journalctl -u ntfs-mount-helper -f"
echo "  Log detalhado: tail -f /var/log/ntfs-mount-helper.log"
echo "  Executar manualmente: /usr/local/bin/ntfs-mount-helper.sh"