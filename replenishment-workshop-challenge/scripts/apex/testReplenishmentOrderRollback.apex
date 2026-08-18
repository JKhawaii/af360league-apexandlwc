RetailStore store = [
    SELECT Id
    FROM RetailStore
    WHERE Name = 'Kroger Store - Noe Valley'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
Product2 water = [
    SELECT Id
    FROM Product2
    WHERE ProductCode = 'BEV-WATER-001'
    ORDER BY CreatedDate DESC
    LIMIT 1
];

ReplenishmentController.OrderSelectionDTO selection =
    new ReplenishmentController.OrderSelectionDTO();
selection.productId = water.Id;
selection.quantity = 25;

ReplenishmentController.CreateOrderRequestDTO request =
    new ReplenishmentController.CreateOrderRequestDTO();
request.storeId = store.Id;
request.requestedDate = Date.today().addDays(1);
request.notes = 'Challenge rollback verification';
request.selections =
    new List<ReplenishmentController.OrderSelectionDTO>{ selection };

Savepoint testSavepoint = Database.setSavepoint();
ReplenishmentController.CreateOrderResultDTO result =
    ReplenishmentController.createReplenishmentOrder(request);
System.assertEquals(true, result.success);
System.assertEquals(1, result.lineCount);
System.assertEquals(25, result.totalQuantity);
Order createdOrder = [
    SELECT EffectiveDate, Description
    FROM Order
    WHERE Id = :result.orderId
];
System.assertEquals(request.requestedDate, createdOrder.EffectiveDate);
System.assertEquals(request.notes, createdOrder.Description);
System.debug(JSON.serializePretty(result));
Database.rollback(testSavepoint);
