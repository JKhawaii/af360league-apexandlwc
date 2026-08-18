#!/usr/bin/env bash
set -euo pipefail

TARGET_ORG="${1:-replenishment-workshop}"

sf data export tree \
  --target-org "${TARGET_ORG}" \
  --query "SELECT Id, Name FROM Account WHERE Name = 'Northern Trail Outfitters' ORDER BY CreatedDate DESC LIMIT 1" \
  --query "SELECT Id, Name, StoreType, AccountId FROM RetailStore WHERE Name = 'Kroger Store - Noe Valley' ORDER BY CreatedDate DESC LIMIT 1" \
  --query "SELECT Id, Name, cgcloud__Valid_From__c, cgcloud__Valid_Thru__c FROM Assortment WHERE Name = 'Kroger HQ Listing' ORDER BY CreatedDate DESC LIMIT 1" \
  --query "SELECT Id, Name, ProductCode, IsActive FROM Product2 WHERE Id IN (SELECT ProductId FROM StoreProduct WHERE RetailStore.Name = 'Kroger Store - Noe Valley') ORDER BY Name" \
  --query "SELECT Id, AssortmentId, ProductId, DefaultOrderQuantity FROM AssortmentProduct WHERE Assortment.Name = 'Kroger HQ Listing' AND ProductId IN (SELECT ProductId FROM StoreProduct WHERE RetailStore.Name = 'Kroger Store - Noe Valley')" \
  --query "SELECT Id, RetailStoreId, ProductId, Current_Stock__c, Safety_Stock__c, Average_Daily_Sales__c, Lead_Time_Days__c, StartDate, EndDate FROM StoreProduct WHERE RetailStore.Name = 'Kroger Store - Noe Valley' ORDER BY Product.Name" \
  --plan \
  --prefix workshop \
  --output-dir data/tree

python3 - <<'PY'
import json
from pathlib import Path

plan_path = Path("data/tree/plan.json")
order = {
    "Account": 0,
    "RetailStore": 1,
    "Assortment": 2,
    "Product2": 3,
    "AssortmentProduct": 4,
    "StoreProduct": 5,
}
plan = json.loads(plan_path.read_text())
plan.sort(key=lambda item: order[item["sobject"]])
plan_path.write_text(json.dumps(plan, indent=4) + "\n")
PY

echo "Export complete. data/tree/plan.json is ordered parent-first."
