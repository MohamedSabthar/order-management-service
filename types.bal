import ballerina/sql;

type Pizza record {|
    string id;
    string name;
    string description;
    @sql:Column {
        name: "base_price"
    }
    decimal basePrice;
    json toppings;
|};

type PizzaResponse record {|
    string id;
    string name;
    string description;
    decimal basePrice;
    string[] toppings;
|};

type OrderPizza record {|
    @sql:Column {
        name: "pizza_id"
    }
    string pizzaId;
    int quantity;
    json customizations;
|};

type OrderPizzaResponse record {|
    string pizzaId;
    int quantity;
    string[] customizations;
|};

type OrderPizzaRequest record {|
    string pizzaId;
    int quantity;
    string[] customizations;
|};

type OrderRequest record {|
    string customerName;
    OrderPizzaRequest[] pizzas;
|};

enum OrderStatus {
    PENDING,
    PREPARING,
    OUT_FOR_DELIVERY,
    DELIVERED,
    CANCELLED
}

type Order record {|
    string id;
    @sql:Column {
        name: "customer_name"
    }
    string customerName;
    OrderStatus status;
    @sql:Column {
        name: "total_price"
    }
    decimal totalPrice;
    OrderPizza[] pizzas;
|};

type OrderResponse record {|
    string id;
    string customerName;
    OrderStatus status;
    decimal totalPrice;
    OrderPizzaResponse[] pizzas;
|};

type OrderUpdate record {|
    OrderStatus status;
|};
