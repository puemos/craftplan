# Inventory Control

The Inventory module in Craftplan helps you track and manage raw materials, monitor stock levels, maintain movement history, and plan materials needs. This guide reflects the features available today.

## Accessing Inventory Management

1. Click on **Inventory** in the left navigation menu
2. The main inventory page displays a list of all your raw materials and their current stock levels

![Inventory Main Page Screenshot Placeholder](#)

## Raw Material List

The inventory list provides an overview of all your raw materials with key information:

- Material name
- SKU/Code
- Current stock level
- Unit of measurement
- Minimum stock level
- Maximum stock level
 - Cost per unit

### Sorting

Materials are listed alphabetically by name. Click a material to view its details and stock history.

## Adding a New Raw Material

1. Click the **Add Material** button in the top right corner of the inventory page
2. Fill in the material details in the form:
    - **Basic Information**
      - Name
      - SKU/Code
      - Unit of measurement
   - **Stock Settings**
     - Initial stock level
     - Minimum stock level
     - Maximum stock level
   - **Cost Information**
     - Unit price (material cost)
   - Allergens and Nutritional Facts can be managed after creation from the material page

![Add Material Form Screenshot Placeholder](#)

3. Click **Save** to create the raw material

## Managing Stock Levels

### Recording Stock Movements

1. Navigate to the material detail page by clicking on a material in the list
2. Click on the **Stock Movements** tab
3. Click **Add Movement** to record:
   - **Stock In**: When you receive new inventory
   - **Stock Out**: When you use or remove inventory
   - **Adjustment**: To correct inventory discrepancies

![Stock Movement Form Screenshot Placeholder](#)

4. For each movement, specify:
   - Date and time
   - Quantity
   - Movement type (In, Out, Adjustment)
   - Reference (e.g., order number, supplier invoice)
   - Notes (optional)
   - Cost (for Stock In movements)

5. The system automatically updates the current stock level

### Stock Movement History

View the complete history of stock movements for each material:

1. Navigate to the material detail page
2. Click on the **Stock Movements** tab
3. Review the chronological list of all stock movements
4. Use filters to narrow down movements by date range or type

![Stock Movement History Screenshot Placeholder](#)

## Costs

Materials have a unit price used for product cost calculations. When creating purchase orders, you can optionally set unit prices on items to reflect supplier quotes; receiving POs updates stock levels. A full costing method (e.g., weighted average) is not yet implemented.

## Allergen Management

For materials with allergen concerns:

1. Navigate to the material detail page
2. Click on the **Allergens** tab
3. Mark which allergens are present in the material
4. This information will automatically propagate to products using this material

![Allergen Management Screenshot Placeholder](#)

## Nutritional Facts

For food-related raw materials:

1. Navigate to the material detail page
2. Click on the **Nutrition** tab
3. Enter nutritional information for the material
4. This information will be used to calculate nutritional facts for products

![Nutritional Facts Screenshot Placeholder](#)

## Purchasing and Receiving

Use the Purchasing module to create purchase orders from suppliers. When you receive a PO, the system creates positive stock movements for each item and marks the PO as received. Open PO items for a material are shown on the material details page.

## Forecasting

The Forecast tab shows upcoming materials requirements by day based on scheduled order deliveries. Use it to anticipate shortages and plan purchasing.

## Best Practices

- **Regular Audits**: Perform physical inventory counts regularly and use stock adjustments to correct discrepancies
- **Consistent Units**: Use consistent units of measurement for similar materials
- **Timely Recording**: Record stock movements as they happen for accurate inventory levels
- **Set Appropriate Levels**: Review and adjust minimum and maximum stock levels based on usage patterns
- **Cost Monitoring**: Update material prices as supplier pricing changes to keep product costing accurate
