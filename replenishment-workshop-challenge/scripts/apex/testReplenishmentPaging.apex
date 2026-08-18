RetailStore store = [
    SELECT Id
    FROM RetailStore
    WHERE Name = 'Kroger Store - Noe Valley'
    ORDER BY CreatedDate DESC
    LIMIT 1
];

List<Integer> expectedCounts = new List<Integer>{ 2, 2, 1 };
Integer pageNumber = 0;
for (Integer startIndex : new List<Integer>{ 0, 2, 4 }) {
    ReplenishmentController.ProductPageDTO page =
        ReplenishmentController.getEligibleProductsPage(
            store.Id,
            null,
            startIndex,
            2
        );
    System.assertEquals(expectedCounts[pageNumber], page.products.size());
    System.assertEquals(startIndex + expectedCounts[pageNumber], page.nextIndex);
    System.assertEquals(pageNumber < 2, page.hasMore);
    System.debug('PAGE ' + startIndex + ': ' + JSON.serialize(page));
    pageNumber++;
}
