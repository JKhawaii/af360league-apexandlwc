public inherited sharing class ReplenishmentRecommendationAction {
    public class Request {
        @InvocableVariable(required=true label='Retail Store Name')
        public String storeName;
        @InvocableVariable(label='Product Name')
        public String productName;
        @InvocableVariable(label='Maximum Recommendations')
        public Integer maximumRecommendations;
    }

    public class Response {
        @InvocableVariable(label='Replenishment Recommendations')
        public ReplenishmentResult recommendationResult;
    }

    public class ReplenishmentResult {
        @AuraEnabled @InvocableVariable public String title;
        @AuraEnabled @InvocableVariable public String summary;
        @AuraEnabled @InvocableVariable public Id storeId;
        @AuraEnabled @InvocableVariable public String storeName;
        @AuraEnabled @InvocableVariable public String storeType;
        @AuraEnabled @InvocableVariable public Date recommendationDate;
        @AuraEnabled @InvocableVariable public Integer totalRecommendedProducts;
        @AuraEnabled @InvocableVariable public Decimal estimatedTotal;
        @AuraEnabled @InvocableVariable public String riskLevel;
        @AuraEnabled @InvocableVariable public List<ProductRecommendation> recommendations;
    }

    public class ProductRecommendation {
        @AuraEnabled @InvocableVariable public Id productId;
        @AuraEnabled @InvocableVariable public String productName;
        @AuraEnabled @InvocableVariable public String name;
        @AuraEnabled @InvocableVariable public String productCode;
        @AuraEnabled @InvocableVariable public String imageUrl;
        @AuraEnabled @InvocableVariable public Decimal currentStock;
        @AuraEnabled @InvocableVariable public Decimal safetyStock;
        @AuraEnabled @InvocableVariable public Decimal averageDailySales;
        @AuraEnabled @InvocableVariable public Decimal leadTimeDays;
        @AuraEnabled @InvocableVariable public Decimal recommendedQuantity;
        @AuraEnabled @InvocableVariable public Decimal quantity;
        @AuraEnabled @InvocableVariable public Decimal unitPrice;
        @AuraEnabled @InvocableVariable public Decimal estimatedLineValue;
        @AuraEnabled @InvocableVariable public String urgency;
        @AuraEnabled @InvocableVariable public String reason;
    }

    @InvocableMethod(
        label='Get Replenishment Recommendations'
        description='Returns assortment-aware replenishment recommendations for a retail store.'
    )
    public static List<Response> recommend(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null) {
            return responses;
        }
        for (Request request : requests) {
            Response response = new Response();
            response.recommendationResult = build(request);
            responses.add(response);
        }
        return responses;
    }

    private static ReplenishmentResult build(Request request) {
        if (request == null || String.isBlank(request.storeName)) {
            throw new RecommendationException('Provide a retail store name.');
        }
        Integer maximum = request.maximumRecommendations == null
            ? 10
            : Math.max(1, Math.min(25, request.maximumRecommendations));
        String storePattern = '%' + request.storeName.trim() + '%';
        List<RetailStore> stores = [
            SELECT Id, Name, StoreType, AccountId
            FROM RetailStore
            WHERE Name LIKE :storePattern and StoreType!='' 
            WITH USER_MODE
            ORDER BY Name
            LIMIT 2
        ];
        if (stores.isEmpty()) {
            throw new RecommendationException('No retail store matches "' + request.storeName + '".');
        }
        if (stores.size() > 1) {
            throw new RecommendationException('More than one store matches. Provide the complete store name.');
        }

        RetailStore store = stores[0];
        Date today = Date.today();
        Set<Id> assortmentIds = new Set<Id>();
        List<StoreAssortment> assignments;
        if (store.AccountId == null) {
            assignments = [
                SELECT AssortmentId
                FROM StoreAssortment
                WHERE RetailStoreId = :store.Id
                  AND StartDate <= :today
                  AND (EndDate = NULL OR EndDate >= :today)
                WITH USER_MODE
            ];
        } else {
            assignments = [
                SELECT AssortmentId
                FROM StoreAssortment
                WHERE (RetailStoreId = :store.Id OR AccountId = :store.AccountId)
                  AND StartDate <= :today
                  AND (EndDate = NULL OR EndDate >= :today)
                WITH USER_MODE
            ];
        }
        for (StoreAssortment assignment : assignments) {
            assortmentIds.add(assignment.AssortmentId);
        }

        Map<Id, Decimal> defaultsByProduct = new Map<Id, Decimal>();
        if (!assortmentIds.isEmpty()) {
            for (AssortmentProduct item : [
                SELECT ProductId, DefaultOrderQuantity
                FROM AssortmentProduct
                WHERE AssortmentId IN :assortmentIds
                WITH USER_MODE
            ]) {
                Decimal candidate = zero(item.DefaultOrderQuantity);
                Decimal existing = defaultsByProduct.get(item.ProductId);
                if (existing == null || candidate > existing) {
                    defaultsByProduct.put(item.ProductId, candidate);
                }
            }
        }

        ReplenishmentResult result = emptyResult(store, today);
        if (defaultsByProduct.isEmpty()) {
            result.summary = 'No active product assortment is assigned to this store.';
            return result;
        }

        Set<Id> eligibleIds = defaultsByProduct.keySet();
        String productPattern = String.isBlank(request.productName)
            ? '%'
            : '%' + request.productName.trim() + '%';
        List<StoreProduct> storeProducts = [
            SELECT ProductId, Product.Name, Product.ProductCode, Product.DisplayUrl,
                   Current_Stock__c, Safety_Stock__c,
                   Average_Daily_Sales__c, Lead_Time_Days__c
            FROM StoreProduct
            WHERE RetailStoreId = :store.Id
              AND ProductId IN :eligibleIds
              AND Product.IsActive = TRUE
              AND StartDate <= :today
              AND (EndDate = NULL OR EndDate >= :today)
              AND Product.Name LIKE :productPattern
            WITH USER_MODE
            ORDER BY Product.Name
        ];

        Set<Id> productIds = new Set<Id>();
        for (StoreProduct item : storeProducts) {
            productIds.add(item.ProductId);
        }
        Map<Id, Decimal> prices = new Map<Id, Decimal>();
        if (!productIds.isEmpty()) {
            for (PricebookEntry entry : [
                SELECT Product2Id, UnitPrice
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                  AND IsActive = TRUE
                  AND Pricebook2.IsActive = TRUE
                  AND Pricebook2.IsStandard = TRUE
                WITH USER_MODE
            ]) {
                prices.put(entry.Product2Id, entry.UnitPrice);
            }
        }

        for (StoreProduct item : storeProducts) {
            Decimal current = zero(item.Current_Stock__c);
            Decimal safety = zero(item.Safety_Stock__c);
            Decimal daily = zero(item.Average_Daily_Sales__c);
            Decimal lead = zero(item.Lead_Time_Days__c);
            ReplenishmentFormulaService.FormulaResult formula =
                ReplenishmentFormulaService.calculate(
                    item,
                    store.StoreType,
                    defaultsByProduct.get(item.ProductId)
                );
            Decimal recommended = zero(formula.quantity);
            if (recommended <= 0) {
                continue;
            }
            ProductRecommendation recommendation = new ProductRecommendation();
            recommendation.productId = item.ProductId;
            recommendation.productName = item.Product.Name;
            recommendation.name = recommendation.productName;
            recommendation.productCode = item.Product.ProductCode;
            recommendation.imageUrl = item.Product.DisplayUrl;
            recommendation.currentStock = current;
            recommendation.safetyStock = safety;
            recommendation.averageDailySales = daily;
            recommendation.leadTimeDays = lead;
            recommendation.recommendedQuantity = recommended;
            recommendation.quantity = recommended;
            recommendation.unitPrice = prices.containsKey(item.ProductId) ? prices.get(item.ProductId) : 0;
            recommendation.estimatedLineValue = recommendation.unitPrice * recommended;
            recommendation.urgency = current <= 0 ? 'Critical' : (current < safety ? 'High' : 'Medium');
            recommendation.reason = formula.explanation;
            result.recommendations.add(recommendation);
            result.estimatedTotal += recommendation.estimatedLineValue;
            if (result.recommendations.size() >= maximum) {
                break;
            }
        }
        result.totalRecommendedProducts = result.recommendations.size();
        result.riskLevel = risk(result.recommendations);
        result.summary = result.recommendations.isEmpty()
            ? 'No products currently require replenishment.'
            : result.totalRecommendedProducts + ' product(s) require replenishment.';
        return result;
    }

    private static ReplenishmentResult emptyResult(RetailStore store, Date today) {
        ReplenishmentResult result = new ReplenishmentResult();
        result.title = 'Store replenishment recommendation';
        result.storeId = store.Id;
        result.storeName = store.Name;
        result.storeType = store.StoreType;
        result.recommendationDate = today;
        result.totalRecommendedProducts = 0;
        result.estimatedTotal = 0;
        result.riskLevel = 'Low';
        result.recommendations = new List<ProductRecommendation>();
        return result;
    }

    private static Decimal zero(Decimal value) {
        return value == null ? 0 : value;
    }

    private static String risk(List<ProductRecommendation> recommendations) {
        String value = 'Low';
        for (ProductRecommendation recommendation : recommendations) {
            if (recommendation.urgency == 'Critical') return 'Critical';
            if (recommendation.urgency == 'High') value = 'High';
            else if (recommendation.urgency == 'Medium' && value == 'Low') value = 'Medium';
        }
        return value;
    }

    public class RecommendationException extends Exception {}
}
