import pino from "pino";
import { readConfig } from "../src/config.js";
import { createPool, transaction, migrate } from "../src/database.js";
import { today } from "../src/farm/routes.js";
const log = pino();
const pool = createPool(readConfig().DATABASE_URL);
function day(offset: number) {
  const d = new Date(`${today()}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + offset);
  return d.toISOString().slice(0, 10);
}
try {
  await migrate(pool);
  await transaction(pool, async (c) => {
    await c.query("SELECT pg_advisory_xact_lock(73201003)");
    const admin = await c.query(
      "SELECT id FROM users WHERE role='ADMIN' AND active AND farm_id='00000000-0000-4000-8000-000000000001' ORDER BY created_at LIMIT 1",
    );
    if (!admin.rows[0]) throw new Error("Run db:seed before demo seed.");
    const actor = admin.rows[0].id;
    const species = await c.query(
      "INSERT INTO species(name) VALUES('Dê (demo)') ON CONFLICT(name) DO UPDATE SET name=EXCLUDED.name RETURNING id",
    );
    const breed = await c.query(
      "INSERT INTO breeds(name,species_id) VALUES('Boer (demo)',$1) ON CONFLICT(species_id,name) DO UPDATE SET name=EXCLUDED.name RETURNING id",
      [species.rows[0].id],
    );
    const area = await c.query(
      "INSERT INTO areas(name) VALUES('Khu chăn nuôi demo') ON CONFLICT(name) DO UPDATE SET name=EXCLUDED.name RETURNING id",
    );
    const pens: string[] = [];
    for (let i = 1; i <= 3; i++) {
      const result = await c.query(
        "INSERT INTO pens(code,name,area_id,capacity) VALUES($1,$2,$3,10) ON CONFLICT(code) DO NOTHING RETURNING id",
        [`DEMO-P${i}`, `Chuồng demo ${i}`, area.rows[0].id],
      );
      const p =
        result.rows[0] ??
        (await c.query("SELECT id FROM pens WHERE code=$1", [`DEMO-P${i}`]))
          .rows[0];
      pens.push(p.id);
    }
    let created = 0;
    for (let i = 1; i <= 20; i++) {
      const code = `DEMO-G${String(i).padStart(2, "0")}`;
      if (
        (await c.query("SELECT 1 FROM animals WHERE code=$1", [code])).rowCount
      )
        continue;
      const pen = pens[i <= 10 ? 0 : i <= 17 ? 1 : 2]!;
      const room = await c.query(
        "SELECT p.active,p.capacity,count(a.id)::int AS n FROM pens p LEFT JOIN animals a ON a.pen_id=p.id AND a.status='ACTIVE' WHERE p.id=$1 GROUP BY p.id",
        [pen],
      );
      if (!room.rows[0].active || room.rows[0].n >= room.rows[0].capacity)
        throw new Error("Demo pen unavailable; no demo data changed.");
      const result = await c.query(
        "INSERT INTO animals(code,breed_id,gender,birth_date,arrival_date,origin,notes,pen_id) VALUES($1,$2,$3,$4,$5,'Dữ liệu mẫu','Dùng trình diễn đồ án',$6) RETURNING id",
        [
          code,
          breed.rows[0].id,
          i % 2 ? "FEMALE" : "MALE",
          day(-180 - i),
          day(-60),
          pen,
        ],
      );
      const id = result.rows[0].id;
      for (let j = 0; j < 4; j++)
        await c.query(
          "INSERT INTO weights(animal_id,date,kg,notes,actor_id) VALUES($1,$2,$3,$4,$5)",
          [
            id,
            day(-60 + j * 14),
            15 + i * 0.4 + j * 2.3,
            "Cân định kỳ (demo)",
            actor,
          ],
        );
      const status = i <= 3 ? "NEEDS_CARE" : "NORMAL";
      await c.query(
        "INSERT INTO health_records(animal_id,date,content,status,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6)",
        [
          id,
          day(-3),
          "Kiểm tra định kỳ (demo)",
          status,
          i <= 3 ? "Theo dõi ăn uống" : "Ổn định",
          actor,
        ],
      );
      await c.query("UPDATE animals SET health_status=$2 WHERE id=$1", [
        id,
        status,
      ]);
      if (i <= 8)
        await c.query(
          "INSERT INTO care_tasks(animal_id,kind,title,due_date,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6)",
          [
            id,
            i % 2 ? "CHECKUP" : "VACCINATION",
            i % 2 ? "Kiểm tra lại sức khỏe" : "Tiêm phòng theo lịch demo",
            day(i - 3),
            "Ngày hẹn nhập tay, không phải khuyến cáo thú y",
            actor,
          ],
        );
      created++;
    }
    let createdFeeds = 0;
    for (const f of [
      {
        code: "DEMO-F1",
        name: "Cám dê (demo)",
        input: 100,
        output: 90,
        threshold: 20,
      },
      {
        code: "DEMO-F2",
        name: "Cỏ khô (demo)",
        input: 80,
        output: 15,
        threshold: 10,
      },
    ]) {
      const result = await c.query(
        "INSERT INTO feeds(code,name,low_stock,notes) VALUES($1,$2,$3,$4) ON CONFLICT(code) DO NOTHING RETURNING id",
        [f.code, f.name, f.threshold, "Dữ liệu mẫu giai đoạn 4"],
      );
      if (!result.rowCount) continue;
      for (const entry of [
        { kind: "IN", quantity: f.input, date: day(-2) },
        { kind: "OUT", quantity: f.output, date: day(-1) },
      ]) {
        await c.query(
          "INSERT INTO stock_entries(feed_id,kind,date,quantity,notes,actor_id) VALUES($1,$2,$3,$4,$5,$6)",
          [
            result.rows[0].id,
            entry.kind,
            entry.date,
            entry.quantity,
            "Phiếu kho demo",
            actor,
          ],
        );
      }
      createdFeeds++;
    }
    let createdFinance = 0;
    for (const [index, sample] of [
      {
        kind: "IN",
        category: "OTHER",
        amount: 3000000,
        content: "Thu khác (demo)",
        offset: -1,
      },
      {
        kind: "OUT",
        category: "FEED",
        amount: 1500000,
        content: "Mua thức ăn (demo)",
        offset: -1,
      },
      {
        kind: "OUT",
        category: "MEDICINE",
        amount: 250000,
        content: "Thuốc/vaccine (demo)",
        offset: 0,
      },
      {
        kind: "OUT",
        category: "ANIMAL_PURCHASE",
        amount: 4000000,
        content: "Mua vật nuôi (demo)",
        offset: -35,
      },
    ].entries()) {
      const id = `55550000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`;
      const added = await c.query(
        "INSERT INTO finance_entries(id,date,kind,category,amount,content,actor_id) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(id) DO NOTHING RETURNING id",
        [
          id,
          day(sample.offset),
          sample.kind,
          sample.category,
          sample.amount,
          sample.content,
          actor,
        ],
      );
      if (added.rowCount) {
        await c.query(
          "INSERT INTO finance_audit(entry_id,action,after_data,reason,actor_id) SELECT id,'CREATE',jsonb_set(to_jsonb(e),'{amount}',to_jsonb(e.amount::text)),'Dữ liệu demo',$2 FROM finance_entries e WHERE id=$1",
          [id, actor],
        );
        createdFinance++;
      }
    }
    log.info(
      { created, createdFeeds, createdFinance },
      "Demo seed applied; existing data preserved.",
    );
  });
} finally {
  await pool.end();
}
