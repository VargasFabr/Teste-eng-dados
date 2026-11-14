# cdv_analytics

Projeto dbt para o teste técnico de Engenharia de Dados do Clube do Valor.

Os dados são de uma corretora fictícia: um CSV de transações (compras e vendas de ativos) e um CSV de clientes. O projeto carrega os dois arquivos como seeds, limpa e tipa os dados, e entrega uma tabela fato de transações, uma dimensão de clientes e a carteira de cada cliente por ativo. O banco é DuckDB, um arquivo local: não precisa de servidor nem de credencial.

## Requisitos

- Git
- Python 3.10 ou mais novo

O script de setup cria o ambiente virtual e instala o dbt. O `git clone` sozinho não instala nada.

## Como rodar

### Windows (PowerShell)

```powershell
git clone https://github.com/VargasFabr/Teste-eng-dados.git
cd Teste-eng-dados
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. .\setup.ps1
dbt seed
dbt run
dbt test
```

- `Set-ExecutionPolicy` libera scripts só nesta janela do PowerShell.
- `. .\setup.ps1` começa com ponto e espaço. Sem isso o script roda, mas o ambiente não fica ativo e o comando `dbt` não é encontrado.
- A primeira execução do setup leva alguns minutos, por causa do download do dbt.

### macOS ou Linux

```bash
git clone https://github.com/VargasFabr/Teste-eng-dados.git
cd Teste-eng-dados
source setup.sh
dbt seed
dbt run
dbt test
```

### Numa nova janela de terminal

O ambiente já está instalado. Basta ativar:

```powershell
.\.venv\Scripts\Activate.ps1
```

No macOS ou Linux: `source .venv/bin/activate`.

## Resultado esperado

| Comando | Resultado |
|---|---|
| `dbt seed` | 2 seeds carregados: 100 transações e 27 clientes |
| `dbt run` | 6 modelos construídos sem erro |
| `dbt test` | 56 testes: 55 passam, 1 aviso (`assert_no_negative_position`, 6 linhas), exit code 0 |

O aviso é esperado. Ele está explicado em [Posições negativas](#posições-negativas).

## Estrutura

```text
seeds/
  transactions.csv                  -- transações brutas, sem edição
  clients.csv                       -- cadastro bruto, sem edição
models/
  staging/
    stg_transactions.sql            -- tipagem, filtro de inválidos, deduplicação
    stg_clients.sql                 -- tipagem, um registro por cliente
    _stg.yml                        -- documentação e testes
  intermediate/
    int_transactions.sql            -- join com cliente e sinal de compra/venda
    _int.yml
  marts/
    fact_transactions.sql           -- fato no grão da transação (incremental)
    dim_clients.sql                 -- dimensão no grão do cliente
    mart_client_portfolio.sql       -- posição líquida por cliente e ativo
    _marts.yml
macros/
  signed_measure.sql                -- sinal de BUY (+) e SELL (-)
tests/
  assert_no_negative_position.sql   -- teste singular
dbt_project.yml
profiles.yml                        -- conexão DuckDB no arquivo cdv.duckdb
.env                                -- aponta o dbt para o profiles.yml desta pasta
requirements.txt                    -- dbt-duckdb com versão fixa
setup.ps1 / setup.sh                -- cria o .venv, instala e ativa
```

## Camadas

| Camada | Modelo | Uma linha é | Materialização | Linhas |
|---|---|---|---|---|
| staging | `stg_transactions` | uma transação válida | view | 97 |
| staging | `stg_clients` | um cliente | view | 25 |
| intermediate | `int_transactions` | uma transação válida com cliente cadastrado e sinal | view | 97 |
| marts | `fact_transactions` | uma transação | incremental | 97 |
| marts | `dim_clients` | um cliente | table | 25 |
| marts | `mart_client_portfolio` | um par cliente + ativo | table | 55 |

**Staging** prepara cada fonte: converte tipos, renomeia `name` para `client_name` e tira as linhas que não podem ser usadas. Continua no grão do arquivo.

**Intermediate** concentra a regra que mais de um modelo usa: liga a transação ao cliente e calcula `signed_quantity` e `signed_amount`, positivos na compra e negativos na venda.

**Marts** é o que se consulta. A dimensão traz todos os clientes, inclusive os 15 que nunca negociaram. A fato traz cada operação. A carteira soma a intermediate por cliente e ativo.

A carteira é o financeiro negociado (`quantity * unit_price`), compras menos vendas. Não é marcação a mercado: não usa preço atual.

## Qualidade dos dados

Os CSVs têm problemas intencionais. Os arquivos em `seeds/` não foram editados. O tratamento acontece no SQL do staging.

| Problema no seed | Linha | Tratamento |
|---|---|---|
| Transação sem `client_id` | T021 | Descartada em `stg_transactions` |
| Quantidade negativa (`-50`) | T037 | Descartada em `stg_transactions` |
| Mesma operação gravada duas vezes com ids diferentes (C4, ITUB4, BUY, 120 a 28,50 em 2024-03-27) | T035 e T036 | Fica a T035, o menor `transaction_id` |
| Cliente repetido com dados iguais | C1 | Fica um registro |
| Cliente repetido, uma cópia sem cidade | C6 | Fica a cópia com cidade (Brasilia) |
| Venda maior que a compra do mesmo cliente no mesmo ativo | 6 posições | Mantida. O teste singular aponta |

Resultado: 100 transações viram 97, e 27 clientes viram 25.

As regras do staging de transações descartam também, se aparecerem, ticker vazio, operação diferente de BUY/SELL, preço nulo ou não positivo e data inválida. Nenhum desses casos existe nos dados atuais.

## Testes

Testes genéricos, declarados nos `.yml` de cada camada:

- `unique` e `not_null` nas chaves: `transaction_id` e `client_id`
- `not_null` nas colunas obrigatórias de todos os modelos
- `accepted_values` em `operation` (`BUY`, `SELL`)
- `relationships`: `client_id` da intermediate, da fato e da carteira existe em `dim_clients`

Teste singular `tests/assert_no_negative_position.sql`: devolve as linhas da carteira com `net_quantity < 0`.

Todos os modelos e colunas têm descrição nos `.yml`.

## Posições negativas

O teste singular encontra 6 posições em que o cliente vendeu mais do que comprou:

| Cliente | Ativo | Comprado | Vendido | Posição | Financeiro líquido |
|---|---|---|---|---|---|
| C5 | BBDC4 | 200 | 600 | -400 | -6.140,00 |
| C7 | WEGE3 | 0 | 60 | -60 | -2.430,00 |
| C1 | BBDC4 | 0 | 50 | -50 | -800,00 |
| C6 | ITUB4 | 0 | 50 | -50 | -1.445,00 |
| C3 | WEGE3 | 0 | 30 | -30 | -1.194,00 |
| C8 | VALE3 | 0 | 30 | -30 | -2.130,00 |

São transações estruturalmente válidas. Pode ser venda a descoberto ou compra anterior ao período do arquivo. Não é papel do modelo apagar essas vendas: a carteira mostra o que os dados dizem, e o teste sinaliza.

O teste está com `severity: warn`. Assim o `dbt test` mostra as 6 linhas no log e termina com exit code 0, como o enunciado pede. Para tratar como erro e quebrar a execução:

```powershell
dbt test --warn-error
```

Ou troque `severity='warn'` por `severity='error'` em `tests/assert_no_negative_position.sql`.

## Incremental (bônus)

`fact_transactions` é incremental:

- `unique_key`: `transaction_id`
- `incremental_strategy`: `delete+insert`
- filtro no run incremental: `transaction_date > max(transaction_date)` da tabela já carregada

Para conferir que um segundo run não duplica linhas:

```powershell
dbt run --full-refresh --select fact_transactions
dbt show --inline "select count(*) as n from {{ ref('fact_transactions') }}"
dbt run --select fact_transactions
dbt show --inline "select count(*) as n from {{ ref('fact_transactions') }}"
```

As duas contagens dão 97.

Limite: uma transação nova com data igual à maior data já carregada não entra no run seguinte, porque o filtro é `>`. Com dados que chegam atrasados, o filtro deveria reprocessar uma janela de alguns dias (`>=` data máxima menos N dias). O `delete+insert` pela `unique_key` evita duplicar nesse caso.

## Macro (bônus)

`macros/signed_measure.sql` devolve o valor positivo para BUY e negativo para SELL. A intermediate chama a macro duas vezes:

```sql
{{ signed_measure('t.operation', 't.quantity') }} as signed_quantity,
{{ signed_measure('t.operation', 't.gross_amount') }} as signed_amount
```

A fato e a carteira leem essas colunas prontas. A regra do sinal fica num só lugar.

## Consultar os resultados

Ver as linhas de um modelo:

```powershell
dbt show --select mart_client_portfolio --limit 20
```

Rodar uma consulta própria. Sem `--limit`, o `dbt show` mostra só 5 linhas. O limite vai na opção, não dentro do SQL:

```powershell
dbt show --inline "select client_id, asset_ticker, net_quantity, net_amount from {{ ref('mart_client_portfolio') }} where net_quantity < 0" --limit 10
```

Documentação navegável, com linhagem dos modelos e descrição das colunas:

```powershell
dbt docs generate
dbt docs serve
```

Abre em `http://localhost:8080`. `Ctrl+C` encerra.

## Configuração

- `profiles.yml` fica na raiz do projeto, não em `~/.dbt`. Ele não tem senha.
- `.env` contém `DBT_PROFILES_DIR=.`. O dbt lê esse arquivo e acha o `profiles.yml` da pasta, por isso os comandos não precisam de `--profiles-dir`.
- O banco é o arquivo `cdv.duckdb`, criado na raiz pelo `dbt seed`. Ele não vai para o Git.
- `threads: 1`, porque o DuckDB aceita um processo escrevendo no arquivo por vez.
- Versões testadas: dbt-core 1.12.7, dbt-duckdb 1.11.1, Python 3.12.

## Problemas comuns

**`dbt` não é reconhecido.** O ambiente não está ativo. Rode `. .\setup.ps1` (com o ponto) ou `.\.venv\Scripts\Activate.ps1`.

**O PowerShell bloqueia o script.** Rode `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` e repita.

**`CERTIFICATE_VERIFY_FAILED` durante a instalação.** O Python da máquina não confia no certificado do PyPI. O `setup.ps1` trata isso sozinho: instala o `pip-system-certs`, que faz o Python usar os certificados do Windows, e repete a instalação. Os avisos em vermelho podem aparecer antes de a instalação terminar.

**Arquivo `cdv.duckdb` travado.** Outro processo está com o banco aberto (outro `dbt`, um notebook, um cliente SQL). Feche esse processo. Se a pasta estiver sincronizada com OneDrive ou Dropbox, clone o projeto fora dela.
