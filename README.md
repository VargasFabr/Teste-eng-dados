# cdv_analytics

Projeto dbt de uma corretora fictícia. Os CSVs brutos entram como seeds e viram três camadas: staging (tipo e limpeza), intermediate (join com o cliente e sinal de compra/venda) e marts (fato da transação, dimensão de cliente e carteira). A carteira é a posição líquida por cliente e ativo: compras menos vendas, em quantidade e em valor negociado (`quantity * unit_price`). Não é marcação a mercado.

## Como rodar

Python 3.10 ou mais novo.

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install dbt-duckdb
mkdir C:\tmp -Force
dbt seed --profiles-dir .
dbt run --profiles-dir .
dbt test --profiles-dir .
```

O banco DuckDB fica em `C:/tmp/cdv.duckdb`. Crie a pasta `C:\tmp` se ela não existir. Os comandos acima precisam do `--profiles-dir .` porque o `profiles.yml` está na raiz do projeto.

`dbt test` termina com exit code 0 e com um aviso em `assert_no_negative_position`. O aviso é intencional: algumas vendas válidas superam as compras daquele cliente naquele ativo, e a posição líquida fica negativa. O teste existe para mostrar essas linhas. Elas não são removidas da carteira. Os seeds também não são editados. Cliente sem cidade, quantidade negativa, cliente vazio e transação repetida são filtrados no staging.

## Incremental

`fact_transactions` carrega por `transaction_date`, com `unique_key` em `transaction_id` e estratégia `delete+insert`. Uma transação nova com data igual à máxima já carregada não entra no run seguinte, porque o filtro é `>`. Para reconstruir a fato depois de mudar a lógica:

```powershell
dbt run --profiles-dir . --full-refresh --select fact_transactions
dbt run --profiles-dir . --select fact_transactions
```

A contagem de linhas fica igual nos dois runs.

## Macro

`signed_measure` centraliza o sinal de BUY e SELL. A intermediate chama a macro na quantidade e no valor.
