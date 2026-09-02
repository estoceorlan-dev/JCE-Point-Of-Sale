BEGIN;

CREATE OR REPLACE VIEW report_sales_facts AS
SELECT
  s.organization_id,
  s.branch_id,
  (s.completed_at AT TIME ZONE b.timezone)::date AS business_date,
  s.completed_at AS occurred_at,
  s.id AS sale_id,
  s.cashier_user_id,
  'sale'::text AS fact_type,
  s.total_minor AS gross_sales_minor,
  0::bigint AS returns_minor,
  s.total_minor AS net_sales_minor
FROM sales s
JOIN branches b ON b.id = s.branch_id AND b.organization_id = s.organization_id
WHERE s.status IN ('completed', 'partially_returned', 'returned')
UNION ALL
SELECT
  sr.organization_id,
  sr.branch_id,
  (sr.completed_at AT TIME ZONE b.timezone)::date AS business_date,
  sr.completed_at AS occurred_at,
  sr.sale_id,
  s.cashier_user_id,
  'return'::text AS fact_type,
  0::bigint AS gross_sales_minor,
  sr.total_minor AS returns_minor,
  -sr.total_minor AS net_sales_minor
FROM sale_returns sr
JOIN sales s ON s.id = sr.sale_id
JOIN branches b ON b.id = sr.branch_id AND b.organization_id = sr.organization_id
WHERE sr.status = 'completed' AND sr.correction_type = 'return';

CREATE OR REPLACE VIEW report_payment_facts AS
SELECT
  p.organization_id,
  p.branch_id,
  p.sale_id,
  s.cashier_user_id,
  s.completed_at AS occurred_at,
  p.payment_method,
  p.applied_amount_minor AS payments_minor,
  0::bigint AS refunds_minor,
  p.applied_amount_minor AS net_minor
FROM payments p
JOIN sales s ON s.id = p.sale_id
WHERE s.status IN ('completed', 'partially_returned', 'returned')
UNION ALL
SELECT
  rp.organization_id,
  rp.branch_id,
  sr.sale_id,
  s.cashier_user_id,
  sr.completed_at AS occurred_at,
  rp.refund_method AS payment_method,
  0::bigint AS payments_minor,
  rp.amount_minor AS refunds_minor,
  -rp.amount_minor AS net_minor
FROM refund_payments rp
JOIN sale_returns sr ON sr.id = rp.sale_return_id
JOIN sales s ON s.id = sr.sale_id
WHERE sr.status = 'completed' AND sr.correction_type = 'return';

CREATE OR REPLACE VIEW report_product_sales_facts AS
SELECT
  si.organization_id,
  si.branch_id,
  s.completed_at AS occurred_at,
  s.cashier_user_id,
  si.product_id,
  si.sku_snapshot AS sku,
  si.product_name_snapshot AS product_name,
  si.quantity_milli AS sold_quantity_milli,
  0::bigint AS returned_quantity_milli,
  si.total_amount_minor AS net_revenue_minor,
  ((si.unit_cost_minor_snapshot * si.quantity_milli + 500) / 1000)::bigint
    AS estimated_cost_minor
FROM sale_items si
JOIN sales s ON s.id = si.sale_id
WHERE s.status IN ('completed', 'partially_returned', 'returned')
UNION ALL
SELECT
  sri.organization_id,
  sri.branch_id,
  sr.completed_at AS occurred_at,
  s.cashier_user_id,
  sri.product_id,
  si.sku_snapshot AS sku,
  si.product_name_snapshot AS product_name,
  0::bigint AS sold_quantity_milli,
  sri.quantity_milli AS returned_quantity_milli,
  -sri.total_minor AS net_revenue_minor,
  -((si.unit_cost_minor_snapshot * sri.quantity_milli + 500) / 1000)::bigint
    AS estimated_cost_minor
FROM sale_return_items sri
JOIN sale_returns sr ON sr.id = sri.sale_return_id
JOIN sales s ON s.id = sr.sale_id
JOIN sale_items si ON si.id = sri.sale_item_id
WHERE sr.status = 'completed' AND sr.correction_type = 'return';

CREATE OR REPLACE VIEW report_inventory_valuation AS
SELECT
  ib.organization_id,
  ib.branch_id,
  ib.stock_location_id,
  sl.name AS stock_location_name,
  ib.product_id,
  p.category_id,
  p.sku,
  p.name AS product_name,
  ib.on_hand_milli,
  ib.reserved_milli,
  ib.on_hand_milli - ib.reserved_milli AS available_milli,
  ib.reorder_point_milli,
  ib.weighted_average_cost_minor,
  ((ib.on_hand_milli * ib.weighted_average_cost_minor +
    CASE WHEN ib.on_hand_milli >= 0 THEN 500 ELSE -500 END) / 1000)::bigint
    AS valuation_minor,
  (ib.on_hand_milli - ib.reserved_milli) <= ib.reorder_point_milli
    AS is_low_stock,
  ib.updated_at
FROM inventory_balances ib
JOIN products p ON p.id = ib.product_id
JOIN stock_locations sl ON sl.id = ib.stock_location_id;

CREATE OR REPLACE VIEW report_shift_reconciliation AS
SELECT
  sh.organization_id,
  sh.branch_id,
  sh.id AS shift_id,
  sh.register_id,
  r.name AS register_name,
  sh.opened_by_user_id,
  sh.status,
  sh.opened_at,
  sh.closed_at,
  sh.expected_cash_minor,
  sh.counted_cash_minor,
  sh.discrepancy_minor
FROM shifts sh
JOIN registers r ON r.id = sh.register_id;

CREATE OR REPLACE VIEW report_transfer_performance AS
SELECT
  st.organization_id,
  st.source_branch_id,
  st.destination_branch_id,
  st.id AS transfer_id,
  st.transfer_number,
  st.status,
  st.created_by_user_id,
  st.created_at,
  st.shipped_at,
  st.received_at,
  COALESCE(SUM(sti.requested_quantity_milli), 0)::bigint AS requested_quantity_milli,
  COALESCE(SUM(sti.shipped_quantity_milli), 0)::bigint AS shipped_quantity_milli,
  COALESCE(SUM(sti.received_quantity_milli), 0)::bigint AS received_quantity_milli,
  COALESCE(SUM(sti.damaged_quantity_milli), 0)::bigint AS damaged_quantity_milli,
  CASE WHEN st.shipped_at IS NULL OR st.received_at IS NULL THEN NULL
       ELSE FLOOR(EXTRACT(EPOCH FROM (st.received_at - st.shipped_at)) / 60)::bigint
  END AS lead_minutes
FROM stock_transfers st
LEFT JOIN stock_transfer_items sti ON sti.transfer_id = st.id
GROUP BY st.id;

CREATE OR REPLACE VIEW report_purchase_receiving_performance AS
SELECT
  po.organization_id,
  po.branch_id,
  po.id AS purchase_order_id,
  po.order_number,
  po.supplier_id,
  s.name AS supplier_name,
  po.status,
  po.created_by_user_id,
  po.created_at,
  COALESCE(SUM(poi.ordered_quantity_milli), 0)::bigint AS ordered_quantity_milli,
  COALESCE(SUM(poi.received_quantity_milli), 0)::bigint AS received_quantity_milli,
  COALESCE(SUM(poi.ordered_quantity_milli - poi.received_quantity_milli -
    poi.cancelled_quantity_milli), 0)::bigint AS remaining_quantity_milli,
  COALESCE(SUM((poi.ordered_quantity_milli * poi.unit_cost_minor + 500) /
    1000), 0)::bigint AS ordered_value_minor,
  COALESCE((SELECT SUM((gri.received_quantity_milli *
    gri.landed_unit_cost_minor + 500) / 1000)
    FROM goods_receipts gr
    JOIN goods_receipt_items gri ON gri.goods_receipt_id = gr.id
    WHERE gr.purchase_order_id = po.id), 0)::bigint AS received_cost_minor
FROM purchase_orders po
JOIN suppliers s ON s.id = po.supplier_id
LEFT JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
GROUP BY po.id, s.name;

COMMIT;
