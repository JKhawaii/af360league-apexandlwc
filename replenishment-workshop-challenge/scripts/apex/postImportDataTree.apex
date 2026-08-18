Map<String, Decimal> pricesByCode = new Map<String, Decimal>{
    'BEV-WATER-001' => 1.25,
    'BEV-CRAN-001' => 2.75,
    'BEV-SPRING-001' => 1.50,
    'BEV-SPARK-001' => 1.75,
    'BEV-FLAVOR-001' => 2.25
};

List<Product2> products = [
    SELECT Id, ProductCode, IsActive
    FROM Product2
    WHERE ProductCode IN :pricesByCode.keySet()
    ORDER BY CreatedDate DESC
];
Map<String, Product2> productByCode = new Map<String, Product2>();
for (Product2 product : products) {
    if (!productByCode.containsKey(product.ProductCode)) {
        product.IsActive = true;
        productByCode.put(product.ProductCode, product);
    }
}
update productByCode.values();

Pricebook2 standardPricebook = [
    SELECT Id, IsActive
    FROM Pricebook2
    WHERE IsStandard = true
    LIMIT 1
];
if (!standardPricebook.IsActive) {
    standardPricebook.IsActive = true;
    update standardPricebook;
}

Map<Id, PricebookEntry> entryByProduct = new Map<Id, PricebookEntry>();
for (PricebookEntry entry : [
    SELECT Id, Product2Id, UnitPrice, IsActive
    FROM PricebookEntry
    WHERE Pricebook2Id = :standardPricebook.Id
        AND Product2Id IN :productByCode.values()
]) {
    entryByProduct.put(entry.Product2Id, entry);
}

List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
List<PricebookEntry> entriesToUpdate = new List<PricebookEntry>();
for (String code : productByCode.keySet()) {
    Product2 product = productByCode.get(code);
    if (entryByProduct.containsKey(product.Id)) {
        PricebookEntry entry = entryByProduct.get(product.Id);
        entry.UnitPrice = pricesByCode.get(code);
        entry.IsActive = true;
        entriesToUpdate.add(entry);
    } else {
        entriesToInsert.add(new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = product.Id,
            UnitPrice = pricesByCode.get(code),
            IsActive = true
        ));
    }
}
if (!entriesToInsert.isEmpty()) insert entriesToInsert;
if (!entriesToUpdate.isEmpty()) update entriesToUpdate;

RetailStore store = [
    SELECT Id, AccountId
    FROM RetailStore
    WHERE Name = 'Kroger Store - Noe Valley'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
Date activeFrom = Date.today();
Date activeUntil = Date.today().addYears(1);
Account accountRecord = [
    SELECT Id, cgcloud__Account_Template__c
    FROM Account
    WHERE Id = :store.AccountId
];
List<cgcloud__Account_Template__c> accountTemplates = [
    SELECT Id
    FROM cgcloud__Account_Template__c
    WHERE Name = 'Customer'
        AND cgcloud__Active__c = true
    ORDER BY CreatedDate DESC
    LIMIT 1
];
System.assert(
    !accountTemplates.isEmpty(),
    'An active Consumer Goods Account Template named Customer is required.'
);
accountRecord.cgcloud__Account_Template__c = accountTemplates[0].Id;
update accountRecord;

Assortment assortment = [
    SELECT Id, cgcloud__Product_Assortment_Template__c,
        cgcloud__Valid_From__c, cgcloud__Valid_Thru__c
    FROM Assortment
    WHERE Name = 'Kroger HQ Listing'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
List<cgcloud__Product_Assortment_Template__c> assortmentTemplates = [
    SELECT Id
    FROM cgcloud__Product_Assortment_Template__c
    WHERE Name = 'Listing'
        AND cgcloud__Active__c = true
    ORDER BY CreatedDate DESC
    LIMIT 1
];
System.assert(
    !assortmentTemplates.isEmpty(),
    'An active Consumer Goods Product Assortment Template named Listing is required.'
);
assortment.cgcloud__Product_Assortment_Template__c = assortmentTemplates[0].Id;
assortment.cgcloud__Valid_From__c = activeFrom.addYears(-1);
assortment.cgcloud__Valid_Thru__c = activeUntil;
update assortment;

List<StoreAssortment> assignments = [
    SELECT Id, StartDate, EndDate
    FROM StoreAssortment
    WHERE AccountId = :store.AccountId
        AND AssortmentId = :assortment.Id
];
for (StoreAssortment assignment : assignments) {
    assignment.StartDate = activeFrom;
    assignment.EndDate = activeUntil;
}
if (assignments.isEmpty()) {
    insert new StoreAssortment(
        AccountId = store.AccountId,
        AssortmentId = assortment.Id,
        StartDate = activeFrom,
        EndDate = activeUntil
    );
} else {
    update assignments;
}

List<StoreProduct> storeProducts = [
    SELECT Id, StartDate, EndDate
    FROM StoreProduct
    WHERE RetailStoreId = :store.Id
        AND ProductId IN :productByCode.values()
];
for (StoreProduct storeProduct : storeProducts) {
    storeProduct.StartDate = activeFrom;
    storeProduct.EndDate = activeUntil;
}
if (!storeProducts.isEmpty()) update storeProducts;

System.debug(
    'Completed post-import setup for ' + productByCode.size() +
    ' products, ' + entriesToInsert.size() + ' new prices, and ' +
    entriesToUpdate.size() + ' updated prices.'
);
