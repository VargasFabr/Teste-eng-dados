# cdv_analytics

Projeto dbt de uma corretora fictícia. Os CSVs brutos entram como seeds e viram três camadas: staging (tipo e limpeza), intermediate (join com o cliente e sinal de compra/venda) e marts (fato da transação, dimensão de cliente e carteira). A carteira é a posição líquida por cliente e ativo: compras menos vendas, em quantidade e em valor negociado (`quantity * unit_price`). Não é marcação a mercado.

## Como rodar

Python 3.10 ou mais novo, já instalado. Na primeira vez, o script cria o `.venv` e instala o dbt. O git não executa isso no clone.

Windows, na raiz do projeto:

```powershell
. .\setup.ps1
dbt seed
dbt run
dbt test
```

Se o PowerShell bloquear o script, rode antes, só nesta janela: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`.

macOS ou Linux:

```bash
source setup.sh
dbt seed
dbt run
dbt test
```

O banco DuckDB é o arquivo `cdv.duckdb` nesta pasta. O `.env` aponta o dbt para o `profiles.yml` do projeto, então os três comandos não levam flag.

`dbt test` termina com exit code 0 e com um aviso em `assert_no_negative_position`. O aviso é intencional: algumas vendas válidas superam as compras daquele cliente naquele ativo, e a posição líquida fica negativa. O teste existe para mostrar essas linhas. Elas não são removidas da carteira. Os seeds também não são editados. Cliente sem cidade, quantidade negativa, cliente vazio e transação repetida são filtrados no staging.

## Incremental

`fact_transactions` carrega por `transaction_date`, com `unique_key` em `transaction_id` e estratégia `delete+insert`. Uma transação nova com data igual à máxima já carregada não entra no run seguinte, porque o filtro é `>`. Para reconstruir a fato depois de mudar a lógica:

```powershell
dbt run --full-refresh --select fact_transactions
dbt run --select fact_transactions
```

A contagem de linhas fica igual nos dois runs.

## Macro

`signed_measure` centraliza o sinal de BUY e SELL. A intermediate chama a macro na quantidade e no valor.
