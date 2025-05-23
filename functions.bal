import ballerina/sql;

isolated function getOrderPizzas(string customerName) returns OrderPizza[]|error {
    sql:ParameterizedQuery query = `
        SELECT op.pizza_id, 
               CAST(SUM(op.quantity) AS UNSIGNED) as quantity, 
               JSON_ARRAYAGG(op.customizations) as customizations
        FROM order_pizzas op
        INNER JOIN orders o ON op.order_id = o.id
        WHERE o.customer_name = ${customerName}
        GROUP BY op.pizza_id`;

    stream<OrderPizza, sql:Error?> pizzaStream = dbClient->query(query);
    OrderPizza[] orderPizzas = check from OrderPizza orderPizza in pizzaStream
        select {
            pizzaId: orderPizza.pizzaId,
            quantity: orderPizza.quantity,
            customizations: flattenJsonArrayToStringArray(orderPizza.customizations)
        };
    return orderPizzas;
}

isolated function flattenJsonArrayToStringArray(json arr, string[] result = []) returns string[] {
    if arr is json[] {
        foreach var item in arr {
            if item is json[] {
                result.push(...flattenJsonArrayToStringArray(item, result));
            } else if item is string {
                result.push(item);
            } else {
                continue;
            }
        }
    }
    return result;
}

isolated function getTotalPrice(OrderPizza[] orderPizzas) returns decimal|error {
    decimal totalPrice = 0;
    Pizza[] pizzas = check getPizzasFromDb();
    foreach OrderPizza orderPizza in orderPizzas {
        Pizza? matchingPizza = getPizza(pizzas, orderPizza.pizzaId);

        if matchingPizza is Pizza {
            totalPrice += matchingPizza.basePrice * <decimal>orderPizza.quantity;
        }
    }

    return totalPrice;
}

isolated function getPizza(Pizza[] pizzas, string pizzaId) returns Pizza? {
    foreach var pizza in pizzas {
        if pizza.id == pizzaId {
            return pizza;
        }
    }
    return;
}

isolated function getPizzasFromDb() returns Pizza[]|error {
    sql:ParameterizedQuery query = `SELECT * FROM pizzas`;
    stream<Pizza, sql:Error?> pizzaStream = dbClient->query(query);
    Pizza[] pizzas = check from Pizza pizza in pizzaStream
        select pizza;
    return pizzas;
}
