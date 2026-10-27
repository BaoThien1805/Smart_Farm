export const reproductionMigration = `
ALTER TABLE species ADD COLUMN reproduction_mode text NOT NULL DEFAULT 'UNSPECIFIED'
  CHECK(reproduction_mode IN ('LIVE_BIRTH','EGGS','UNSPECIFIED'));
UPDATE species SET reproduction_mode='LIVE_BIRTH'
  WHERE lower(trim(name)) IN ('bò','trâu','heo','lợn','dê','cừu','thỏ');
UPDATE species SET reproduction_mode='EGGS'
  WHERE lower(trim(name)) IN ('gà','vịt','ngan','ngỗng','vịt xiêm');
CREATE TABLE reproduction_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mother_id uuid NOT NULL REFERENCES animals(id),
  kind text NOT NULL CHECK(kind IN ('LIVE_BIRTH','EGG_COLLECTION','HATCH')),
  date date NOT NULL,
  quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 1000000),
  collection_id uuid REFERENCES reproduction_events(id),
  breed_id uuid NOT NULL REFERENCES breeds(id),
  pen_id uuid NOT NULL REFERENCES pens(id),
  notes text NOT NULL DEFAULT '' CHECK(length(notes)<=2000),
  actor_id uuid NOT NULL REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK((kind='HATCH' AND collection_id IS NOT NULL) OR
        (kind<>'HATCH' AND collection_id IS NULL))
);
CREATE INDEX reproduction_mother_idx ON reproduction_events(mother_id,date,id);
CREATE INDEX reproduction_collection_idx ON reproduction_events(collection_id);
ALTER TABLE animals ADD COLUMN mother_id uuid REFERENCES animals(id);
ALTER TABLE animals ADD COLUMN birth_event_id uuid REFERENCES reproduction_events(id);
ALTER TABLE animals ADD CONSTRAINT animals_mother_not_self CHECK(mother_id IS NULL OR mother_id<>id);
CREATE INDEX animals_mother_idx ON animals(mother_id);
CREATE INDEX animals_birth_event_idx ON animals(birth_event_id);
`;
