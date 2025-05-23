import ballerina/http;
import ballerina/sql;
import ballerina/uuid;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

final mysql:Client dbClient = check new (
    host = dbHost,
    user = dbUser,
    password = dbPassword,
    database = dbName,
    port = dbPort
);

service /v1 on new http:Listener(8080) {

    resource function get pizzas() returns PizzaResponse[]|error {
        do {
            Pizza[] pizzas = check getPizzasFromDb();
            return check pizzas.cloneWithType();
        } on fail error e {
            return error("Failed to obtain pizza from database", e);
        }
    }

    resource function post orders(@http:Payload OrderRequest orderRequest) returns OrderResponse|error {
        do {
            Order newOrder = {
                id: uuid:createType1AsString(),
                customerName: orderRequest.customerName,
                status: PENDING,
                totalPrice: check getTotalPrice(orderRequest.pizzas),
                pizzas: orderRequest.pizzas
            };

            sql:ParameterizedQuery query = `INSERT INTO orders (id, customer_name, status, total_price) 
                                      VALUES (${newOrder.id}, ${newOrder.customerName}, ${newOrder.status}, ${newOrder.totalPrice})`;
            _ = check dbClient->execute(query);

            foreach OrderPizza pizza in orderRequest.pizzas {
                sql:ParameterizedQuery pizzaQuery = `INSERT INTO order_pizzas (order_id, pizza_id, quantity, customizations) 
                                               VALUES (${newOrder.id}, ${pizza.pizzaId}, ${pizza.quantity}, ${pizza.customizations.toJsonString()})`;
                _ = check dbClient->execute(pizzaQuery);
            }
            return check newOrder.cloneWithType();
        } on fail error e {
            return error("Failed to create order", e);
        }
    }

    // resource function get orders(string customerName) returns OrderResponse[]|error {
    //     sql:ParameterizedQuery query = `SELECT * FROM orders WHERE customer_name = ${customerName}`;
    //     stream<Order, sql:Error?> orderStream = dbClient->query(query);
    //     OrderResponse[] orders = check from Order 'order in orderStream
    //         select {
    //             id: 'order.id,
    //             customerName: 'order.customerName,
    //             status: 'order.status,
    //             totalPrice: 'order.totalPrice,
    //             pizzas: check (check getOrderPizzas('order.customerName)).cloneWithType()
    //         };
    //     return orders;
    // }

    resource function get orders/[string orderId]() returns OrderResponse|error {
        do {
            sql:ParameterizedQuery query = `SELECT * FROM orders WHERE id = ${orderId}`;
            Order? 'order = check dbClient->queryRow(query);
            if 'order is () {
                return error("Order not found");
            }
            'order.pizzas = check getOrderPizzas('order.customerName);
            return check 'order.cloneWithType();
        } on fail error e {
            return error(string `Failed to obtain order with id ${orderId}`, e);
        }
    }

    resource function patch orders/[string orderId](@http:Payload OrderUpdate orderUpdate) returns OrderResponse|error {
        do {
            sql:ParameterizedQuery query = `UPDATE orders SET status = ${orderUpdate.status} WHERE id = ${orderId}`;
            sql:ExecutionResult result = check dbClient->execute(query);
            if result.affectedRowCount == 0 {
                return error("Order not found");
            }

            // Query the updated order
            sql:ParameterizedQuery getQuery = `SELECT * FROM orders WHERE id = ${orderId}`;
            Order? updatedOrder = check dbClient->queryRow(getQuery);
            if updatedOrder is () {
                return error("Order not found after update");
            }
            updatedOrder.pizzas = check getOrderPizzas(updatedOrder.customerName);
            return check updatedOrder.cloneWithType();
        } on fail error e {
            return error(string `Failed to update order with id ${orderId}`, e);
        }
    }
}
