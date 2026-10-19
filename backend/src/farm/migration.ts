export const farmMigration = `
CREATE TABLE species(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL UNIQUE);
CREATE TABLE breeds(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, species_id uuid NOT NULL REFERENCES species(id), UNIQUE(species_id,name));
CREATE TABLE areas(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL UNIQUE);
CREATE TABLE pens(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE, name text NOT NULL, area_id uuid NOT NULL REFERENCES areas(id), capacity integer NOT NULL CHECK(capacity>0), active boolean NOT NULL DEFAULT true);
CREATE TABLE animals(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE, breed_id uuid NOT NULL REFERENCES breeds(id), gender text NOT NULL CHECK(gender IN ('MALE','FEMALE','UNKNOWN')), birth_date date, arrival_date date NOT NULL, origin text NOT NULL DEFAULT '', notes text NOT NULL DEFAULT '', pen_id uuid NOT NULL REFERENCES pens(id), status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','DEAD','SOLD')), health_status text NOT NULL DEFAULT 'NORMAL' CHECK(health_status IN ('NORMAL','NEEDS_CARE')), ended_date date, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE transfers(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), animal_id uuid NOT NULL REFERENCES animals(id), from_pen_id uuid NOT NULL REFERENCES pens(id), to_pen_id uuid NOT NULL REFERENCES pens(id), date date NOT NULL, notes text NOT NULL, actor_id uuid NOT NULL REFERENCES users(id));
CREATE TABLE weights(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), animal_id uuid NOT NULL REFERENCES animals(id), date date NOT NULL, kg numeric(10,2) NOT NULL CHECK(kg>0), notes text NOT NULL, actor_id uuid NOT NULL REFERENCES users(id), UNIQUE(animal_id,date));
CREATE TABLE care_tasks(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), animal_id uuid NOT NULL REFERENCES animals(id), kind text NOT NULL CHECK(kind IN ('VACCINATION','CHECKUP')), title text NOT NULL, due_date date NOT NULL, notes text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','DONE','CANCELLED')), actual_date date, actor_id uuid NOT NULL REFERENCES users(id));
CREATE TABLE health_records(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), animal_id uuid NOT NULL REFERENCES animals(id), date date NOT NULL, content text NOT NULL, status text NOT NULL CHECK(status IN ('NORMAL','NEEDS_CARE')), notes text NOT NULL DEFAULT '', task_id uuid UNIQUE REFERENCES care_tasks(id), actor_id uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE INDEX animals_pen_idx ON animals(pen_id) WHERE status='ACTIVE';
CREATE INDEX animals_breed_idx ON animals(breed_id);
CREATE INDEX transfers_animal_idx ON transfers(animal_id,date);
CREATE INDEX health_animal_idx ON health_records(animal_id,date,created_at);
CREATE INDEX care_due_idx ON care_tasks(status,due_date);
CREATE TABLE farm_operations(actor_id uuid NOT NULL REFERENCES users(id), request_id uuid NOT NULL, digest text NOT NULL, result jsonb NOT NULL, PRIMARY KEY(actor_id,request_id));
INSERT INTO schema_migrations(version) VALUES(2);
`;
