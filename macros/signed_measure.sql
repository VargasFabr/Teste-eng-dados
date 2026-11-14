{% macro signed_measure(operation_col, value_col) %}
case
    when {{ operation_col }} = 'BUY' then {{ value_col }}
    when {{ operation_col }} = 'SELL' then -1 * ({{ value_col }})
end
{% endmacro %}
