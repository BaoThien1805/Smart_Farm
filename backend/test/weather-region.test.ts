import { test } from "node:test";
import assert from "node:assert/strict";
import { WeatherRegionService } from "../src/weather-region.js";

const location = { latitude: 11.9404, longitude: 108.4583 };

test("weather region prefers province over district/city, deduplicates and caches coordinates", async () => {
  let calls = 0;
  const service = new WeatherRegionService(async (input) => {
    calls++;
    const url = new URL(String(input));
    assert.equal(url.hostname, "photon.komoot.io");
    assert.equal(url.searchParams.get("lat"), String(location.latitude));
    assert.equal(url.searchParams.get("lon"), String(location.longitude));
    assert.equal(url.searchParams.get("lang"), "default");
    return Response.json({
      features: [{ properties: { state: "Lâm Đồng", city: "Đà Lạt" } }],
    });
  });
  assert.deepEqual(
    await Promise.all([service.current(location), service.current(location)]),
    ["Lâm Đồng", "Lâm Đồng"],
  );
  assert.equal(await service.current(location), "Lâm Đồng");
  assert.equal(calls, 1);
  await service.current({ ...location, latitude: 10.8 });
  assert.equal(calls, 2);
});

test("weather region falls back to city when province is missing", async () => {
  const service = new WeatherRegionService(async () =>
    Response.json({ features: [{ properties: { city: "Hồ Chí Minh" } }] }),
  );
  assert.equal(await service.current(location), "Hồ Chí Minh");
});

test("unavailable, empty and malformed geocoding returns no region without breaking weather", async () => {
  for (const response of [
    new Response("unavailable", { status: 503 }),
    Response.json({}),
    Response.json({ features: [] }),
    Response.json({ features: [{ properties: { name: "Đường Hùng Vương" } }] }),
  ]) {
    const service = new WeatherRegionService(async () => response.clone());
    assert.equal(await service.current(location), null);
  }
  const service = new WeatherRegionService(async () => {
    throw new Error("network unavailable");
  });
  assert.equal(await service.current(location), null);
});
