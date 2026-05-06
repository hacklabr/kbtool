# kbtool

Simplificador de operações com kubectl — gerenciamento de kubeconfigs, autodescoberta de pods, cópia de arquivos em chunks, dumps de banco de dados e terminais com prompt colorido.

## Instalação

```bash
# Copiar para algum diretório no PATH
sudo cp kbtool /usr/local/bin/kbtool
sudo chmod +x /usr/local/bin/kbtool

# Ou via symlink
ln -s $(pwd)/kbtool ~/bin/kbtool
```

### Autocomplete

**Bash:**

```bash
echo 'source /caminho/para/kbtool-completion.bash' >> ~/.bashrc
```

**Zsh:**

```bash
echo 'autoload -U +X bashcompinit && bashcompinit' >> ~/.zshrc
echo 'source /caminho/para/kbtool-completion.bash' >> ~/.zshrc
```

## Gerenciamento de Clusters

Os kubeconfigs são salvos em `~/.config/kbtool/clusters/<slug>.yaml`. O cluster ativo é por sessão de terminal (cada terminal pode usar um cluster diferente).

### Comandos

| Comando | Descrição |
|---------|-----------|
| `cluster add <slug>` | Adiciona kubeconfig interativamente |
| `cluster rm <slug>` | Remove kubeconfig (pede confirmação) |
| `cluster update <slug>` | Atualiza kubeconfig interativamente |
| `cluster list` | Lista clusters cadastrados (`*` = ativo) |
| `use <slug>` | Ativa cluster na sessão atual |
| `use` | Mostra cluster ativo na sessão atual |

### Fluxo

```bash
# 1. Adicionar cluster (pede para colar o kubeconfig)
kbtool cluster add production
# Paste the kubeconfig content, then press Ctrl-D to finish:
<colar conteúdo do kubeconfig>
^D
✓ Cluster 'production' added successfully

# 2. Ativar cluster na sessão
kbtool use production
✓ Now using cluster: production

# 3. Usar comandos normalmente
kbtool bash production api
kbtool pgdump production db ./dump.sql

# 4. Trocar de cluster em outro terminal
kbtool use staging

# 5. Listar clusters
kbtool cluster list
  * production
    staging

# 6. Atualizar kubeconfig
kbtool cluster update production

# 7. Remover cluster
kbtool cluster rm production
Remove cluster 'production'? [y/N] y
✓ Cluster 'production' removed
```

### Validação

Ao colar o kubeconfig, o kbtool verifica automaticamente se contém `apiVersion` e `kind: Config`. Conteúdo inválido é rejeitado.

### Armazenamento

| Caminho | Descrição |
|---------|-----------|
| `~/.config/kbtool/clusters/*.yaml` | Kubeconfigs salvos (chmod 600) |
| `/tmp/kbtool_active_<tty>` | Cluster ativo por sessão de terminal |

## Comandos de Pod

```
kbtool <comando> <namespace> [args...]
```

| Comando | Descrição |
|---------|-----------|
| `cp <ns> <src> <dst>` | Copia arquivos entre pod e local |
| `bash <ns> <pod>` | Shell interativo no pod |
| `mariadb <ns> <pod>` | Console MariaDB |
| `mysql <ns> <pod>` | Console MySQL |
| `psql <ns> <pod>` | Console PostgreSQL |
| `pgdump <ns> <pod> <output>` | Dump PostgreSQL |
| `mariadb_dump <ns> <pod> <output>` | Dump MariaDB |
| `mysql_dump <ns> <pod> <output>` | Dump MySQL |

### Autodescoberta de Pods

Não é preciso digitar o nome completo do pod — basta um substring:

```bash
kbtool bash production api        # encontra "api-deployment-7b8f9c-x2k4j"
kbtool mysql staging db           # encontra "mysql-5dcdf866d5-xv62j"
```

- **1 match** → usa automaticamente
- **Múltiplos matches** → lista e pede seleção interativa
- **0 matches** → mostra pods disponíveis

Se o pod tiver múltiplos containers, também será pedido para escolher.

### Copiar Arquivos

Transferência em chunks com validação de tamanho, retry automático e barra de progresso com ETA:

```bash
# Download (remoto → local)
kbtool cp production api:/var/log/app.log ./app.log

# Upload (local → remoto)
kbtool cp production ./config.yaml api:/app/config.yaml
```

### Shell Interativo

Prompt colorido com namespace (amarelo) e pod (verde) em vermelho:

```bash
kbtool bash production api
# [production:api-7b8f9c-x2k4j] /app #
```

### Consoles de Banco de Dados

Credenciais lidas automaticamente das variáveis de ambiente do container (`MYSQL_USER`, `MYSQL_PASSWORD`, `POSTGRES_USER`, etc.). Prompt colorido igual ao bash:

```bash
kbtool mariadb production db
kbtool mysql production db
kbtool psql production db
```

### Dumps de Banco de Dados

O dump é feito em 3 etapas para evitar o erro `unexpected EOF` do `kubectl cp`:

1. Dump + compressão (gzip) no pod
2. Transferência em chunks com validação e retry
3. Remontagem local

O formato de saída depende da extensão:

```bash
# .sql → descompactado
kbtool pgdump production db ./dump.sql

# .gz → mantém compactado
kbtool mariadb_dump production db ./dump.sql.gz
```

## Configuração

### Valores Padrão

Persistido em `~/.config/kbtool/config`:

```bash
# Ver config atual
kbtool config

# Alterar padrões
kbtool config chunk-size=10M
kbtool config retries=25

# Ambos de uma vez
kbtool config chunk-size=10M retries=25
```

### Prioridade

```
CLI flags (--chunk-size=10M) > config file > env vars > defaults (3M / 20)
```

| Opção | Env var | Default | Descrição |
|-------|---------|---------|-----------|
| `--chunk-size=SIZE` | `KBTOOL_CHUNK_SIZE` | `3M` | Tamanho dos chunks para transferência |
| `--retries=N` | `KBTOOL_RETRIES` | `20` | Tentativas por chunk em caso de falha |

As opções CLI podem ser passadas em qualquer posição:

```bash
kbtool cp --chunk-size=1M production api:/big.sql ./big.sql
kbtool pgdump --retries=5 --chunk-size=5M production db ./dump.sql
```

Ou via variável de ambiente:

```bash
KBTOOL_CHUNK_SIZE=1M kbtool cp production api:/big.sql ./big.sql
```

## Requisitos

- `kubectl` configurado e com acesso ao cluster
- Bash 3.2+
