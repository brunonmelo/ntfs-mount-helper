# NTFS Mount Helper

Um serviço systemd para Arch Linux que automaticamente detecta e corrige problemas de montagem de discos NTFS após a inicialização do sistema.

## 📋 Descrição

Este projeto resolve um problema comum em sistemas Linux com discos NTFS: ocasionalmente, após a inicialização, os discos NTFS não montam automaticamente devido ao estado "dirty" (sujo). O serviço monitora as entradas NTFS no fstab, detecta falhas na montagem e aplica automaticamente as correções necessárias usando `ntfsfix`.

## ✨ Funcionalidades

- ✅ Detecta automaticamente discos NTFS configurados no `/etc/fstab`
- ✅ Verifica o status de montagem de cada disco NTFS
- ✅ Aplica `ntfsfix -d` em discos com problemas
- ✅ Tenta remontar discos após correção
- ✅ Logs detalhados em `/var/log/ntfs-mount-helper.log`
- ✅ Integração com systemd (journalctl)
- ✅ Suporte a dispositivos identificados por UUID ou LABEL
- ✅ Verificação de erros no kernel via `dmesg`

## 🛠 Requisitos

- Arch Linux (ou distribuições derivadas)
- Pacote `ntfs-3g` (contém `ntfsfix`)
- Pacote `util-linux` (contém `blkid`, `mountpoint`)
- Systemd (já incluído no Arch)

## 📁 Estrutura do Projeto

```
ntfs-mount-helper/
├── bin/
│   └── ntfs-mount-helper.sh     # Script principal
├── services/
│   └── ntfs-mount-helper.service # Serviço systemd
├── install.sh                   # Script de instalação
└── README.md                    # Este arquivo
```

## 🚀 Instalação

1. **Clone ou copie os arquivos do projeto**

2. **Execute o script de instalação como root:**
```bash
sudo ./install.sh
```

O script de instalação irá:
- Instalar as dependências necessárias (`ntfs-3g` e `util-linux`)
- Copiar o script principal para `/usr/local/bin/`
- Configurar o serviço systemd em `/etc/systemd/system/`
- Habilitar e iniciar o serviço

## ⚙️ Configuração

### Configuração do fstab
Certifique-se de que seus discos NTFS estão corretamente configurados no `/etc/fstab`. Exemplo:

```bash
# Montagem por UUID (recomendado)
UUID=1234-5678 /mnt/dados ntfs-3g defaults,uid=1000,gid=1000 0 0

# Montagem por dispositivo
/dev/sdb1 /mnt/backup ntfs-3g defaults 0 0

# Montagem por label
LABEL=MeuHD /mnt/hd ntfs-3g defaults 0 0
```

### Opções de montagem recomendadas para NTFS:
- `ntfs-3g` (em vez de apenas `ntfs`)
- `uid=1000,gid=1000` (substitua pelos seus IDs de usuário/grupo)
- `windows_names` (para compatibilidade com nomes de arquivos Windows)
- `noatime` (para melhor desempenho)

## 📊 Uso

### Comandos do sistema:

```bash
# Verificar status do serviço
sudo systemctl status ntfs-mount-helper

# Ver logs do serviço no journal
sudo journalctl -u ntfs-mount-helper -f

# Ver logs detalhados do script
sudo tail -f /var/log/ntfs-mount-helper.log

# Executar verificação manualmente
sudo /usr/local/bin/ntfs-mount-helper.sh

# Verificar montagens NTFS atuais
mount | grep -i ntfs

# Desabilitar o serviço (se necessário)
sudo systemctl disable ntfs-mount-helper
sudo systemctl stop ntfs-mount-helper
```

### Quando o serviço é executado:

O serviço é configurado para executar:
- **Após** as tentativas de montagem do systemd (`After=local-fs.target`)
- **Antes** do sistema ficar pronto para o usuário (`Before=multi-user.target`)
- Isto garante que o serviço execute logo após as tentativas de montagem do fstab, corrigindo quaisquer falhas antes que o usuário precise acessar os discos.

## 🔍 Logs e Diagnóstico

O serviço gera logs em dois locais:

1. **Log do systemd** (via journalctl):
```bash
sudo journalctl -u ntfs-mount-helper -n 50 --no-pager
```

2. **Log detalhado do script**:
```bash
sudo tail -n 100 /var/log/ntfs-mount-helper.log
```

O log detalhado inclui:
- Timestamp de cada operação
- Status de cada disco NTFS
- Resultado das correções aplicadas
- Erros encontrados no dmesg
- Relatório final com estatísticas

## 🐛 Solução de Problemas

### Problema: Disco não monta mesmo com o serviço
1. Verifique se o disco aparece no fstab:
   ```bash
   grep -i ntfs /etc/fstab
   ```

2. Teste manualmente a montagem:
   ```bash
   sudo mount -a
   ```

3. Execute o script manualmente para ver mensagens detalhadas:
   ```bash
   sudo /usr/local/bin/ntfs-mount-helper.sh
   ```

### Problema: Serviço não inicia
1. Verifique se as dependências estão instaladas:
   ```bash
   which ntfsfix blkid mountpoint
   ```

2. Recarregue as configurações do systemd:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart ntfs-mount-helper
   ```

### Problema: Montagem funciona manualmente mas não automaticamente
1. Verifique as permissões do ponto de montagem:
   ```bash
   ls -la /mnt/
   ```

2. Verifique se há erros de disco físico:
   ```bash
   sudo dmesg | grep -i ntfs
   sudo ntfsfix -d /dev/sdXN  # Substitua sdXN pelo seu dispositivo
   ```

## ⚠️ Limitações e Considerações

1. **Apenas discos NTFS**: O serviço só lida com sistemas de arquivos NTFS.
2. **Require privilégios root**: O serviço executa como root para poder montar discos.
3. **Linux apenas**: Projetado especificamente para sistemas Linux com systemd.
4. **Discos externos**: Para discos USB/externos, certifique-se de que estejam conectados durante a inicialização.

## 🔄 Reinstalação/Remoção

Para reinstalar:
```bash
sudo ./install.sh
```

Para remover completamente:
```bash
# Parar e desabilitar o serviço
sudo systemctl stop ntfs-mount-helper
sudo systemctl disable ntfs-mount-helper

# Remover os arquivos
sudo rm /usr/local/bin/ntfs-mount-helper.sh
sudo rm /etc/systemd/system/ntfs-mount-helper.service
sudo rm /var/log/ntfs-mount-helper.log 2>/dev/null

# Recarregar systemd
sudo systemctl daemon-reload
```

## 🤝 Contribuição

Contribuições são bem-vindas! Sinta-se à vontade para:
1. Reportar problemas (issues)
2. Sugerir melhorias
3. Enviar pull requests

## 📄 Licença

Este projeto é distribuído sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.

## 🙏 Agradecimentos

- Desenvolvedores do `ntfs-3g` pela excelente suporte a NTFS no Linux
- Comunidade Arch Linux pela documentação e suporte
- Systemd por fornecer um sistema de init robusto e flexível

---

**Nota**: Este serviço é particularmente útil para usuários dual-boot (Windows + Linux) que frequentemente encontram problemas com o estado "dirty" dos discos NTFS após desligamento inadequado do Windows.