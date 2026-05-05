# kbtool

Simplificador de operações com kubectl — autodescoberta de pods, cópia de arquivos em chunks, dumps de banco de dados e terminais com prompt colorido.

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

## Uso

```
kbtool <comando> <namespace> [args...]
```

### Comandos

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

Transferência em chunks de 5MB com validação de tamanho, retry automático (até 5 tentativas) e barra de progresso com ETA:

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
2. Transferência em chunks de 5MB com validação e retry
3. Remontagem local

O formato de saída depende da extensão:

```bash
# .sql → descompactado
kbtool pgdump production db ./dump.sql

# .gz → mantém compactado
kbtool mariadb_dump production db ./dump.sql.gz
```

## Exemplos

```bash
# Shell no pod de API
kbtool bash production api

# Baixar log do pod
kbtool cp production api:/var/log/app.log ./app.log

# Console MySQL
kbtool mysql production db

# Dump PostgreSQL (descompactado)
kbtool pgdump production db ./dump.sql

# Dump MariaDB (compactado)
kbtool mariadb_dump staging db ./dump.sql.gz
```

## Requisitos

- `kubectl` configurado e com acesso ao cluster
- Bash 3.2+

## Configuração

| Opção | Env var | Default | Descrição |
|-------|---------|---------|-----------|
| `--chunk-size=10M` | `KBTOOL_CHUNK_SIZE=10M` | `3M` | Tamanho dos chunks para transferência |
| `--retries=10` | `KBTOOL_RETRIES=10` | `20` | Tentativas por chunk em caso de falha |

As opções CLI podem ser passadas em qualquer posição:

```bash
kbtool cp --chunk-size=10M production api:/big.sql ./big.sql
kbtool pgdump --retries=5 --chunk-size=5M production db ./dump.sql
```

Ou via variável de ambiente:

```bash
KBTOOL_CHUNK_SIZE=10M kbtool cp production api:/big.sql ./big.sql
```
