import type { Pool, PoolClient } from "pg";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { createFarmTables, transaction } from "../src/database.js";
import { hashPassword } from "../src/security.js";
import { normalizeAnimalImage } from "../src/farm/images.js";
import { today } from "../src/farm/routes.js";

export const demoFarmId = "d3e00001-2026-4000-8000-000000000001";
const controlFarmId = "d3e00001-2026-4000-8000-000000000002";
export const demoPassword = "SmartFarmDemo@2026";
export const demoAccounts = [
  {
    email: "chutrai@demo.smartfarm.local",
    name: "Nguyễn Minh An",
    role: "ADMIN",
    code: "CT-01",
    active: true,
  },
  {
    email: "nhanvien@demo.smartfarm.local",
    name: "Trần Thị Mai",
    role: "STAFF",
    code: "NV-01",
    active: true,
  },
  {
    email: "thuy@demo.smartfarm.local",
    name: "Lê Hoàng Nam",
    role: "VET",
    code: "TY-01",
    active: true,
  },
  {
    email: "ketoan@demo.smartfarm.local",
    name: "Phạm Ngọc Linh",
    role: "ACCOUNTANT",
    code: "KT-01",
    active: true,
  },
  {
    email: "bikhoa@demo.smartfarm.local",
    name: "Võ Bảo — tài khoản đã khóa",
    role: "STAFF",
    code: "NV-02",
    active: false,
  },
  {
    email: "thuxoa@demo.smartfarm.local",
    name: "Tài khoản dùng thử xóa",
    role: "STAFF",
    code: "NV-03",
    active: true,
  },
] as const;
export const controlEmail = "doichieu@demo.smartfarm.local";
const farmName = "Trang trại Mầm Xanh · DEMO";
type SpeciesPlan = {
  name: string;
  code: string;
  breeds: [string, string];
  area: number;
  kg: number;
  growth: number;
  art?: string;
  count?: number;
};
const plans: SpeciesPlan[] = [
  {
    name: "Bò",
    code: "BO",
    breeds: ["Holstein Friesian", "Lai Sind"],
    area: 0,
    kg: 220,
    growth: 8,
    art: "cow",
    count: 6,
  },
  {
    name: "Trâu",
    code: "TR",
    breeds: ["Murrah", "Trâu nội"],
    area: 0,
    kg: 300,
    growth: 9,
  },
  {
    name: "Heo",
    code: "HE",
    breeds: ["Landrace", "Yorkshire"],
    area: 0,
    kg: 45,
    growth: 6,
    art: "pig",
    count: 6,
  },
  {
    name: "Dê",
    code: "DE",
    breeds: ["Boer", "Bách Thảo"],
    area: 0,
    kg: 18,
    growth: 1.2,
    art: "goat",
    count: 6,
  },
  {
    name: "Cừu",
    code: "CU",
    breeds: ["Phan Rang", "Dorper"],
    area: 0,
    kg: 20,
    growth: 1.5,
  },
  {
    name: "Gà",
    code: "GA",
    breeds: ["Gà Ri", "Lương Phượng"],
    area: 1,
    kg: 1.2,
    growth: 0.15,
    art: "chicken",
    count: 6,
  },
  {
    name: "Vịt",
    code: "VI",
    breeds: ["Vịt cỏ", "Vịt bầu"],
    area: 1,
    kg: 1.1,
    growth: 0.18,
  },
  {
    name: "Ngan",
    code: "NG",
    breeds: ["Ngan Pháp", "Ngan dé"],
    area: 1,
    kg: 1.5,
    growth: 0.2,
  },
  {
    name: "Ngỗng",
    code: "NO",
    breeds: ["Ngỗng sư tử", "Ngỗng cỏ"],
    area: 1,
    kg: 2.3,
    growth: 0.25,
  },
  {
    name: "Cá",
    code: "CA",
    breeds: ["Rô phi", "Trắm cỏ"],
    area: 2,
    kg: 0.35,
    growth: 0.025,
  },
  {
    name: "Tôm",
    code: "TO",
    breeds: ["Thẻ chân trắng", "Tôm sú"],
    area: 2,
    kg: 0.008,
    growth: 0.001,
  },
  {
    name: "Thỏ",
    code: "TH",
    breeds: ["New Zealand", "California"],
    area: 0,
    kg: 1.2,
    growth: 0.12,
  },
];
function day(offset: number) {
  const value = new Date(`${today()}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + offset);
  return value.toISOString().slice(0, 10);
}
async function audit(
  c: PoolClient,
  entryId: string,
  actor: string,
  action = "CREATE",
  before: unknown = null,
  reason = "Dữ liệu minh họa DEMO",
) {
  await c.query(
    "INSERT INTO finance_audit(entry_id,action,before_data,after_data,reason,actor_id) SELECT id,$2,$3::jsonb,jsonb_set(to_jsonb(e),'{amount}',to_jsonb(e.amount::text)),$4,$5 FROM finance_entries e WHERE id=$1",
    [
      entryId,
      action,
      before === null ? null : JSON.stringify(before),
      reason,
      actor,
    ],
  );
}
async function createFarm(c: PoolClient, id: string, name: string) {
  const schema = "farm_" + id.replaceAll("-", "");
  if (!/^farm_[a-f0-9]{32}$/.test(schema))
    throw new Error("Invalid demo schema");
  await c.query(
    "INSERT INTO public.farms(id,name,schema_name,latitude,longitude) VALUES($1,$2,$3,11.9404,108.4583)",
    [id, name, schema],
  );
  await createFarmTables(c, schema);
  return schema;
}
export async function seedShowcase(pool: Pool) {
  return transaction(pool, async (c) => {
    await c.query("SELECT pg_advisory_xact_lock(73201004)");
    const existing = await c.query(
      "SELECT name,schema_name FROM public.farms WHERE id=$1",
      [demoFarmId],
    );
    if (existing.rowCount) {
      if (
        existing.rows[0].schema_name !==
        "farm_" + demoFarmId.replaceAll("-", "")
      )
        throw new Error("Demo identity collision");
      // Never reset passwords, users, dates or work performed during a demo.
      return {
        created: false,
        farmId: demoFarmId,
        farmName: existing.rows[0].name,
        accounts: demoAccounts,
        controlEmail,
      };
    }
    const hash = await hashPassword(demoPassword);
    await createFarm(c, demoFarmId, farmName);
    const actors: Record<string, string> = {};
    for (const account of demoAccounts) {
      const user = await c.query(
        "INSERT INTO public.users(email,name,password_hash,role,farm_id,code,active) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id",
        [
          account.email,
          account.name,
          hash,
          account.role,
          demoFarmId,
          account.code,
          account.active,
        ],
      );
      if (!actors[account.role]) actors[account.role] = user.rows[0].id;
    }
    const admin = actors.ADMIN!,
      staff = actors.STAFF!,
      vet = actors.VET!,
      accountant = actors.ACCOUNTANT!;
    const areas: string[] = [];
    for (const [i, name] of [
      "Khu gia súc",
      "Khu gia cầm",
      "Khu thủy sản",
      "Khu cách ly",
    ].entries())
      areas.push(
        (
          await c.query(
            "INSERT INTO areas(code,name) VALUES($1,$2) RETURNING id",
            [`KV-${i + 1}`, name],
          )
        ).rows[0].id,
      );
    const species = await c.query("SELECT id,name FROM species");
    const selected: string[] = [];
    const special: Record<string, { id: string; pen: string; spare: string }> =
      {};
    let animals = 0;
    for (const plan of plans) {
      const speciesId = species.rows.find((s) => s.name === plan.name)?.id;
      if (!speciesId) throw new Error("Missing default species " + plan.name);
      selected.push(speciesId);
      await c.query("UPDATE species SET code=$2 WHERE id=$1", [
        speciesId,
        plan.code,
      ]);
      const breeds: string[] = [];
      for (const [i, name] of plan.breeds.entries())
        breeds.push(
          (
            await c.query(
              "INSERT INTO breeds(code,name,species_id) VALUES($1,$2,$3) RETURNING id",
              [`${plan.code}-G${i + 1}`, name, speciesId],
            )
          ).rows[0].id,
        );
      const pens: string[] = [];
      for (let i = 1; i <= 2; i++)
        pens.push(
          (
            await c.query(
              "INSERT INTO pens(code,name,area_id,capacity) VALUES($1,$2,$3,$4) RETURNING id",
              [
                `${plan.code}-C${i}`,
                `${plan.area === 2 ? "Khu nuôi" : "Chuồng"} ${plan.name.toLowerCase()} ${i === 1 ? "chính" : "dự phòng"}`,
                areas[plan.area],
                plan.code === "BO" && i === 1 ? 4 : 10,
              ],
            )
          ).rows[0].id,
        );
      let picture: string | null = null;
      if (plan.art)
        picture = await normalizeAnimalImage(
          (
            await readFile(
              path.resolve("../assets/illustrations", plan.art + ".png"),
            )
          ).toString("base64"),
        );
      for (let i = 1; i <= (plan.count ?? 4); i++) {
        const code = `${plan.code}-${String(i).padStart(3, "0")}`;
        const pen = pens[i <= 4 ? 0 : 1]!;
        const noHistory = code === "TH-004";
        const result = await c.query(
          "INSERT INTO animals(code,name,breed_id,gender,birth_date,arrival_date,origin,notes,pen_id,image_data) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id",
          [
            code,
            `${plan.name} ${["Bông", "Mây", "Nắng", "Đốm", "Mít", "Mun"][i - 1]}`,
            breeds[(i - 1) % 2],
            i % 2 ? "FEMALE" : "MALE",
            day(-180 - i),
            day(-90),
            "Trại giống minh họa",
            noHistory
              ? "DEMO: Chưa có lịch sử, dùng thử xóa hồ sơ."
              : "DEMO: Dữ liệu mô phỏng. Ảnh nếu có là ảnh minh họa, không phải ảnh vật nuôi thật.",
            pen,
            i === 1 ? picture : null,
          ],
        );
        const id = result.rows[0].id;
        special[code] = { id, pen, spare: pens[1]! };
        animals++;
        if (noHistory) continue;
        for (const [index, offset] of [-60, -45, -30, -15].entries())
          await c.query(
            "INSERT INTO weights(animal_id,date,kg,notes,actor_id) VALUES($1,$2,$3,'Cân theo dõi — dữ liệu DEMO',$4)",
            [
              id,
              day(offset),
              Math.round(
                (plan.kg + plan.growth * (index + (i - 1) / 4)) * 1000,
              ) / 1000,
              staff,
            ],
          );
        const health = i === 2 || code === "DE-005" ? "NEEDS_CARE" : "NORMAL";
        await c.query(
          "INSERT INTO health_records(animal_id,date,content,status,notes,actor_id) VALUES($1,$2,$3,$4,'Quan sát minh họa DEMO',$5)",
          [
            id,
            day(-3),
            health === "NORMAL"
              ? "Theo dõi ăn uống định kỳ"
              : "Ghi nhận ăn ít, cần kiểm tra thêm",
            health,
            staff,
          ],
        );
        await c.query(
          "INSERT INTO health_records(animal_id,date,content,status,notes,actor_id,record_type,diagnosis,treatment) VALUES($1,$2,'Khám định kỳ (DEMO)',$3,'Bản ghi dùng thử giao diện',$4,'EXAM','Kết quả mô phỏng cho đồ án','Không dùng bản ghi này làm hướng dẫn điều trị thực tế')",
          [id, day(-2), health, vet],
        );
        await c.query("UPDATE animals SET health_status=$2 WHERE id=$1", [
          id,
          health,
        ]);
        if (i === 1)
          await c.query(
            "INSERT INTO transfers(animal_id,from_pen_id,to_pen_id,date,notes,actor_id) VALUES($1,$2,$3,$4,'Chuyển về chuồng chính (DEMO)',$5)",
            [id, pens[1], pen, day(-14), staff],
          );
        if (i <= 4) {
          const done = i === 4,
            offset = i === 1 ? -2 : i === 2 ? 0 : i === 3 ? 2 : -7;
          const title =
            i === 2
              ? "Tiêm phòng theo lịch nhập tay (DEMO)"
              : "Kiểm tra sức khỏe định kỳ (DEMO)";
          const task = (
            await c.query(
              "INSERT INTO care_tasks(animal_id,kind,title,due_date,notes,status,actual_date,actor_id) VALUES($1,$2,$3,$4,'Lịch minh họa, không phải khuyến cáo thú y',$5,$6,$7) RETURNING id",
              [
                id,
                i === 2 ? "VACCINATION" : "CHECKUP",
                title,
                day(offset),
                done ? "DONE" : "PENDING",
                done ? day(-7) : null,
                staff,
              ],
            )
          ).rows[0].id;
          if (done)
            await c.query(
              "INSERT INTO health_records(animal_id,date,content,status,notes,task_id,actor_id) VALUES($1,$2,$3,'NORMAL','Đã thực hiện — DEMO',$4,$5)",
              [id, day(-7), title, task, vet],
            );
        }
      }
    }
    await c.query(
      "INSERT INTO pens(code,name,area_id,capacity,active) VALUES('CL-01','Chuồng cách ly dự phòng',$1,5,true),('NGHI-01','Chuồng đang bảo trì',$1,8,false)",
      [areas[3]],
    );
    for (const actor of [admin, staff, vet, accountant]) {
      await c.query(
        "INSERT INTO user_species_preferences(user_id,configured) VALUES($1,true)",
        [actor],
      );
      await c.query(
        "INSERT INTO user_species(user_id,species_id) SELECT $1,unnest($2::uuid[])",
        [actor, selected],
      );
    }
    // All sale/death events follow the animal's latest weight/health dates.
    for (const [code, amount, cancelled] of [
      ["BO-005", 32000000, false],
      ["HE-005", 5200000, false],
      ["GA-005", 250000, false],
      ["BO-006", 28500000, true],
    ] as const) {
      const animal = special[code]!;
      const sale = (
        await c.query(
          "INSERT INTO sales(animal_id,date,amount,buyer,notes,actor_id) VALUES($1,$2,$3,'Khách hàng minh họa','Giao dịch DEMO',$4) RETURNING id",
          [animal.id, day(-1), amount, admin],
        )
      ).rows[0].id;
      const entry = (
        await c.query(
          "INSERT INTO finance_entries(date,kind,category,amount,content,sale_id,actor_id) VALUES($1,'IN','ANIMAL_SALE',$2,$3,$4,$5) RETURNING id",
          [day(-1), amount, `Bán ${code} (DEMO)`, sale, admin],
        )
      ).rows[0].id;
      await audit(c, entry, admin);
      if (cancelled) {
        const before = (
          await c.query(
            "SELECT *,amount::text AS amount FROM finance_entries WHERE id=$1",
            [entry],
          )
        ).rows[0];
        await c.query(
          "UPDATE sales SET cancelled_at=now(),cancelled_by=$2,cancel_reason='Khách trả lại — DEMO',restore_date=$3,restore_pen_id=$4 WHERE id=$1",
          [sale, admin, today(), animal.spare],
        );
        await c.query(
          "UPDATE finance_entries SET cancelled_at=now(),cancelled_by=$2,cancel_reason='Hủy bán — DEMO' WHERE id=$1",
          [entry, admin],
        );
        await audit(c, entry, admin, "CANCEL", before, "Hủy bán — DEMO");
        await c.query(
          "INSERT INTO transfers(animal_id,from_pen_id,to_pen_id,date,notes,actor_id) VALUES($1,$2,$2,$3,'Nhận lại sau hủy bán — DEMO',$4)",
          [animal.id, animal.spare, today(), admin],
        );
      } else
        await c.query(
          "UPDATE animals SET status='SOLD',ended_date=$2 WHERE id=$1",
          [animal.id, day(-1)],
        );
      await c.query(
        "INSERT INTO care_tasks(animal_id,kind,title,due_date,status,notes,actor_id) VALUES($1,'CHECKUP','Lịch đã hủy khi bán', $2,'CANCELLED','Không tự phục hồi khi hủy bán',$3)",
        [animal.id, day(3), staff],
      );
    }
    for (const code of ["HE-006", "DE-006"]) {
      await c.query(
        "UPDATE animals SET status='DEAD',ended_date=$2,notes=notes||' Đã kết thúc nuôi (DEMO).' WHERE id=$1",
        [special[code]!.id, day(-1)],
      );
      await c.query(
        "INSERT INTO care_tasks(animal_id,kind,title,due_date,status,notes,actor_id) VALUES($1,'CHECKUP','Lịch đã hủy khi kết thúc nuôi',$2,'CANCELLED','Lưu lịch sử DEMO',$3)",
        [special[code]!.id, day(3), staff],
      );
    }
    const feedPlans = [
      { name: "Cám tổng hợp", input: 500, output: 420, low: 100 },
      { name: "Cỏ khô", input: 200, output: 100, low: 40 },
      { name: "Thóc gia cầm", input: 80, output: 80, low: 20 },
      { name: "Bắp nghiền — chưa nhập", input: 0, output: 0, low: 15 },
      { name: "Thức ăn thủy sản", input: 60, output: 20, low: 20 },
      { name: "Cám thỏ", input: 30, output: 5, low: 10 },
      { name: "Khoáng bổ sung", input: 15, output: 5, low: 15 },
      { name: "Thức ăn ngừng sử dụng", input: 0, output: 0, low: 0 },
    ];
    for (const [index, feed] of feedPlans.entries()) {
      const id = (
        await c.query(
          "INSERT INTO feeds(code,name,low_stock,active,notes) VALUES($1,$2,$3,$4,'Danh mục DEMO') RETURNING id",
          [
            `TA-${String(index + 1).padStart(2, "0")}`,
            feed.name,
            feed.low,
            index !== 7,
          ],
        )
      ).rows[0].id;
      if (feed.input)
        await c.query(
          "INSERT INTO stock_entries(feed_id,kind,date,quantity,notes,actor_id) VALUES($1,'IN',$2,$3,'Nhập thức ăn DEMO',$4)",
          [id, day(-14), feed.input, staff],
        );
      if (feed.output)
        await c.query(
          "INSERT INTO stock_entries(feed_id,kind,date,quantity,pen_id,notes,actor_id) VALUES($1,'OUT',$2,$3,$4,'Xuất sử dụng DEMO',$5)",
          [id, day(-4), feed.output, special["BO-001"]!.pen, staff],
        );
      if (index === 1 || index === 5)
        await c.query(
          "INSERT INTO stock_entries(feed_id,kind,date,quantity,notes,actor_id,cancelled_at,cancelled_by,cancel_reason) VALUES($1,$2,$3,10,'Phiếu mẫu đã hủy',$4,now(),$5,'Ghi nhầm — DEMO')",
          [id, index === 1 ? "OUT" : "IN", day(-3), staff, admin],
        );
    }
    for (let month = 0; month < 6; month++) {
      const samples = [
        {
          kind: "IN",
          category: "OTHER",
          amount: 1500000 + month * 300000,
          content: "Thu khác",
        },
        {
          kind: "OUT",
          category: "FEED",
          amount: 1200000 + month * 50000,
          content: "Mua thức ăn",
        },
        {
          kind: "OUT",
          category: "MEDICINE",
          amount: 150000 + month * 10000,
          content: "Vật tư chăm sóc",
        },
        {
          kind: "OUT",
          category: "ANIMAL_PURCHASE",
          amount: 2000000 + month * 100000,
          content: "Nhập giống",
        },
      ];
      for (const sample of samples) {
        const id = (
          await c.query(
            "INSERT INTO finance_entries(date,kind,category,amount,content,actor_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING id",
            [
              day(-150 + month * 30),
              sample.kind,
              sample.category,
              sample.amount,
              `${sample.content} — kỳ ${month + 1} (DEMO)`,
              accountant,
            ],
          )
        ).rows[0].id;
        await audit(c, id, accountant);
        if (month === 5 && sample.category === "OTHER") {
          const before = (
            await c.query(
              "SELECT *,amount::text AS amount FROM finance_entries WHERE id=$1",
              [id],
            )
          ).rows[0];
          await c.query(
            "UPDATE finance_entries SET amount=amount+500000,updated_at=clock_timestamp() WHERE id=$1",
            [id],
          );
          await audit(
            c,
            id,
            accountant,
            "EDIT",
            before,
            "Bổ sung chứng từ minh họa",
          );
        }
      }
    }
    const cancelled = (
      await c.query(
        "INSERT INTO finance_entries(date,kind,category,amount,content,actor_id) VALUES($1,'OUT','OTHER',300000,'Khoản ghi nhầm (DEMO)',$2) RETURNING id",
        [today(), accountant],
      )
    ).rows[0].id;
    await audit(c, cancelled, accountant);
    const before = (
      await c.query(
        "SELECT *,amount::text AS amount FROM finance_entries WHERE id=$1",
        [cancelled],
      )
    ).rows[0];
    await c.query(
      "UPDATE finance_entries SET cancelled_at=now(),cancelled_by=$2,cancel_reason='Chứng từ trùng (DEMO)' WHERE id=$1",
      [cancelled, accountant],
    );
    await audit(
      c,
      cancelled,
      accountant,
      "CANCEL",
      before,
      "Chứng từ trùng (DEMO)",
    );
    // A second owner sees only this small, separate farm.
    await createFarm(c, controlFarmId, "Trại đối chứng · DEMO");
    const owner = (
      await c.query(
        "INSERT INTO public.users(email,name,password_hash,role,farm_id,code) VALUES($1,'Chủ trại đối chứng',$2,'ADMIN',$3,'CT-02') RETURNING id",
        [controlEmail, hash, controlFarmId],
      )
    ).rows[0].id;
    const s = (await c.query("SELECT id FROM species WHERE name='Bò'")).rows[0]
      .id;
    const b = (
      await c.query(
        "INSERT INTO breeds(name,species_id) VALUES('Bò đối chứng',$1) RETURNING id",
        [s],
      )
    ).rows[0].id;
    const a = (
      await c.query(
        "INSERT INTO areas(name) VALUES('Khu đối chứng') RETURNING id",
      )
    ).rows[0].id;
    const p = (
      await c.query(
        "INSERT INTO pens(code,name,area_id,capacity) VALUES('DC-C1','Chuồng đối chứng',$1,5) RETURNING id",
        [a],
      )
    ).rows[0].id;
    await c.query(
      "INSERT INTO animals(code,name,breed_id,gender,arrival_date,pen_id,notes) VALUES('DC-001','Con thuộc trại khác',$1,'FEMALE',$2,$3,'Dùng kiểm tra cô lập dữ liệu')",
      [b, day(-10), p],
    );
    await c.query(
      "INSERT INTO user_species_preferences(user_id,configured) VALUES($1,true)",
      [owner],
    );
    await c.query(
      "INSERT INTO user_species(user_id,species_id) VALUES($1,$2)",
      [owner, s],
    );
    return {
      created: true,
      farmId: demoFarmId,
      farmName,
      accounts: demoAccounts,
      controlEmail,
      animals,
      species: plans.length,
      pens: plans.length * 2 + 2,
      feeds: feedPlans.length,
    };
  });
}
