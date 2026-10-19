export const inventoryMigration = `
CREATE TABLE feeds(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code text NOT NULL UNIQUE,name text NOT NULL,low_stock numeric(14,3) NOT NULL DEFAULT 0 CHECK(low_stock>=0),active boolean NOT NULL DEFAULT true,notes text NOT NULL DEFAULT '');
CREATE TABLE stock_entries(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),feed_id uuid NOT NULL REFERENCES feeds(id),kind text NOT NULL CHECK(kind IN ('IN','OUT')),date date NOT NULL,quantity numeric(14,3) NOT NULL CHECK(quantity>0),pen_id uuid REFERENCES pens(id),notes text NOT NULL DEFAULT '',actor_id uuid NOT NULL REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),cancelled_at timestamptz,cancelled_by uuid REFERENCES users(id),cancel_reason text,CHECK((cancelled_at IS NULL AND cancelled_by IS NULL AND cancel_reason IS NULL) OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND length(cancel_reason)>0)));
CREATE INDEX stock_feed_idx ON stock_entries(feed_id,date,created_at);
CREATE TABLE user_species_preferences(user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,configured boolean NOT NULL DEFAULT false);
CREATE TABLE user_species(user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,species_id uuid NOT NULL REFERENCES species(id) ON DELETE CASCADE,PRIMARY KEY(user_id,species_id));
ALTER TABLE animals ADD COLUMN image_data text;
INSERT INTO schema_migrations(version) VALUES(4);
`;
