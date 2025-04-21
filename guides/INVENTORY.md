# Inventory Control

The Inventory module in Craftday helps you track and manage your raw materials, monitor stock levels, and maintain inventory history. This guide will walk you through all the inventory management features.

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
- Status indicators (below minimum, optimal, excess)

### Filtering and Searching

You can filter the inventory list by:
- Stock status (Low, Optimal, Excess)
- Category
- Search term (material name or SKU)

![Inventory Filtering Screenshot Placeholder](#)

## Adding a New Raw Material

1. Click the **Add Material** button in the top right corner of the inventory page
2. Fill in the material details in the form:
   - **Basic Information**
     - Name
     - SKU/Code
     - Description
     - Category
     - Unit of measurement
   - **Stock Settings**
     - Initial stock level
     - Minimum stock level
     - Maximum stock level
   - **Cost Information**
     - Purchase cost
     - Currency
   - **Allergen Information** (if applicable)
     - Contains allergens checkbox
     - Allergen selection
   - **Nutritional Facts** (if applicable)
     - Nutritional information per unit

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

## Cost Tracking

Craftday helps you track the cost of your raw materials over time:

1. Navigate to the material detail page
2. Click on the **Cost History** tab
3. View the history of cost changes
4. The system uses weighted average costing to calculate the current cost of your inventory

![Cost Tracking Screenshot Placeholder](#)

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

## Low Stock Alerts

Craftday can alert you when stock levels fall below the minimum threshold:

1. Go to **Settings** > **Notifications**
2. Enable low stock alerts
3. Configure how you want to be notified (in-app, email)

When materials fall below their minimum stock level, they will be highlighted in the inventory list and included in the alerts section of your dashboard.

![Low Stock Alerts Screenshot Placeholder](#)

## Inventory Reports

Access inventory reports to gain insights into your stock:

1. Go to the Inventory page
2. Click on **Reports** in the top navigation
3. Choose from available reports:
   - Current Stock Value
   - Low Stock Items
   - Stock Movement History
   - Cost Analysis

![Inventory Reports Screenshot Placeholder](#)

## Best Practices

- **Regular Audits**: Perform physical inventory counts regularly and use the adjustment feature to correct discrepancies
- **Consistent Units**: Use consistent units of measurement for similar materials
- **Timely Recording**: Record stock movements as they happen for accurate inventory levels
- **Set Appropriate Levels**: Review and adjust minimum and maximum stock levels based on usage patterns
- **Cost Monitoring**: Keep track of cost changes to ensure accurate product pricing
