export const financeMigration = `
CREATE TABLE sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), animal_id uuid NOT NULL REFERENCES animals(id),
  date date NOT NULL, amount bigint NOT NULL CHECK(amount BETWEEN 1 AND 1000000000000),
  buyer text NOT NULL DEFAULT '', notes text NOT NULL DEFAULT '', actor_id uuid NOT NULL REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(), cancelled_at timestamptz,
  cancelled_by uuid REFERENCES public.users(id), cancel_reason text, restore_date date, restore_pen_id uuid REFERENCES pens(id),
  CHECK ((cancelled_at IS NULL AND cancelled_by IS NULL AND cancel_reason IS NULL AND restore_date IS NULL AND restore_pen_id IS NULL)
    OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND length(cancel_reason)>0 AND restore_date IS NOT NULL AND restore_date>=date AND restore_pen_id IS NOT NULL))
);
CREATE UNIQUE INDEX sales_active_animal_idx ON sales(animal_id) WHERE cancelled_at IS NULL;
CREATE TABLE finance_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), date date NOT NULL, kind text NOT NULL CHECK(kind IN ('IN','OUT')),
  category text NOT NULL CHECK(category IN ('ANIMAL_SALE','FEED','MEDICINE','ANIMAL_PURCHASE','OTHER')),
  amount bigint NOT NULL CHECK(amount BETWEEN 1 AND 1000000000000), content text NOT NULL,
  sale_id uuid UNIQUE REFERENCES sales(id), actor_id uuid NOT NULL REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(), updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  cancelled_at timestamptz, cancelled_by uuid REFERENCES public.users(id), cancel_reason text,
  CHECK ((sale_id IS NULL AND category<>'ANIMAL_SALE') OR (sale_id IS NOT NULL AND category='ANIMAL_SALE' AND kind='IN')),
  CHECK ((cancelled_at IS NULL AND cancelled_by IS NULL AND cancel_reason IS NULL)
    OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND length(cancel_reason)>0))
);
CREATE INDEX finance_entries_date_idx ON finance_entries(date,id);
CREATE TABLE finance_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entry_id uuid NOT NULL REFERENCES finance_entries(id),
  action text NOT NULL CHECK(action IN ('CREATE','EDIT','CANCEL')), before_data jsonb, after_data jsonb NOT NULL,
  reason text NOT NULL, actor_id uuid NOT NULL REFERENCES public.users(id), created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX finance_audit_entry_idx ON finance_audit(entry_id,created_at);
`;

export const stockPurchaseMigration = `
ALTER TABLE finance_entries ADD COLUMN stock_entry_id uuid UNIQUE REFERENCES stock_entries(id);
ALTER TABLE finance_entries ADD CONSTRAINT finance_stock_purchase_check
  CHECK(stock_entry_id IS NULL OR (sale_id IS NULL AND kind='OUT' AND category='FEED'));
`;
