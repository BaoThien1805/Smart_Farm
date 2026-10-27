import { test } from "node:test";
import assert from "node:assert/strict";
import { WeatherService } from "../src/weather.js";
const location = { name: "Trang trại A", latitude: 10.8, longitude: 106.6 };
const payload = {
  main: { temp: 29.8, humidity: 80 },
  weather: [{ id: 500, description: "mưa nhẹ" }],
  wind: { speed: 2.5 },
  dt: 1791187200,
};
const meteoPayload = {
  current_units: {
    temperature_2m: "°C",
    relative_humidity_2m: "%",
    wind_speed_10m: "m/s",
  },
  current: {
    time: 1791187200,
    temperature_2m: 29.8,
    relative_humidity_2m: 80,
    wind_speed_10m: 2.5,
    weather_code: 63,
  },
};

test("weather requests coordinates, Celsius and Vietnamese; caches concurrent requests without leaking key", async () => {
  let calls = 0;
  const request: typeof fetch = async (input) => {
    calls++;
    const url = new URL(String(input));
    assert.equal(url.hostname, "api.openweathermap.org");
    assert.equal(url.searchParams.get("lat"), "10.8");
    assert.equal(url.searchParams.get("units"), "metric");
    assert.equal(url.searchParams.get("lang"), "vi");
    return Response.json(payload);
  };
  const service = new WeatherService("private-test-key", request);
  const [a, b] = await Promise.all([
    service.current(location),
    service.current({ ...location, name: "Trang trại B" }),
  ]);
  assert.equal(calls, 1);
  assert.equal(a.temperature, 29.8);
  assert.equal(b.location, "Trang trại B");
  assert.ok(!JSON.stringify(a).includes("private-test-key"));
  await service.current(location);
  assert.equal(calls, 1);
});

test("no key uses Open-Meteo with Celsius, m/s and UTC while sharing cached requests", async () => {
  let calls = 0;
  const service = new WeatherService(undefined, async (input) => {
    calls++;
    const url = new URL(String(input));
    assert.equal(url.hostname, "api.open-meteo.com");
    assert.equal(url.searchParams.get("latitude"), "10.8");
    assert.equal(url.searchParams.get("longitude"), "106.6");
    assert.equal(url.searchParams.get("temperature_unit"), "celsius");
    assert.equal(url.searchParams.get("wind_speed_unit"), "ms");
    assert.equal(url.searchParams.get("timeformat"), "unixtime");
    assert.equal(url.searchParams.get("timezone"), "GMT");
    assert.ok(
      url.searchParams.get("current")?.includes("relative_humidity_2m"),
    );
    assert.equal(url.searchParams.has("appid"), false);
    return Response.json(meteoPayload);
  });
  const [a, b] = await Promise.all([
    service.current(location),
    service.current({ ...location, name: "Trang trại B" }),
  ]);
  assert.equal(calls, 1);
  assert.deepEqual(a, {
    location: location.name,
    temperature: 29.8,
    humidity: 80,
    windSpeed: 2.5,
    description: "Mưa vừa",
    condition: 501,
    observedAt: new Date(1791187200 * 1000).toISOString(),
    provider: "Open-Meteo",
  });
  assert.equal(b.location, "Trang trại B");
  await service.current(location);
  assert.equal(calls, 1);
});

test("WMO codes map into existing UI condition groups instead of all appearing as storms", async () => {
  for (const [code, condition, description] of [
    [0, 800, "Trời quang"],
    [3, 804, "Nhiều mây"],
    [45, 741, "Sương mù"],
    [95, 200, "Dông"],
  ] as const) {
    const service = new WeatherService(undefined, async () =>
      Response.json({
        ...meteoPayload,
        current: { ...meteoPayload.current, weather_code: code },
      }),
    );
    const result = await service.current(location);
    assert.equal(result.condition, condition);
    assert.equal(result.description, description);
  }
});

test("no-key provider rejects missing measurements, wrong units, unknown conditions and HTTP failures; retries recover", async () => {
  for (const body of [
    {},
    {
      ...meteoPayload,
      current: { ...meteoPayload.current, temperature_2m: null },
    },
    {
      ...meteoPayload,
      current_units: { ...meteoPayload.current_units, wind_speed_10m: "km/h" },
    },
    {
      ...meteoPayload,
      current: { ...meteoPayload.current, weather_code: 999 },
    },
    { ...meteoPayload, current: { ...meteoPayload.current, time: 1e20 } },
  ]) {
    let calls = 0;
    const service = new WeatherService(undefined, async () =>
      Response.json(++calls === 1 ? body : meteoPayload),
    );
    await assert.rejects(service.current(location), {
      statusCode: 503,
      code: "WEATHER_UNAVAILABLE",
    });
    assert.equal((await service.current(location)).provider, "Open-Meteo");
    assert.equal(calls, 2);
  }
  const service = new WeatherService(
    undefined,
    async () => new Response("private error", { status: 429 }),
  );
  await assert.rejects(service.current(location), {
    message: "Chưa lấy được thời tiết. Vui lòng thử lại sau.",
  });
});

test("provider failures and malformed responses return sanitized errors; failed requests can retry", async () => {
  for (const response of [
    new Response("secret", { status: 401 }),
    Response.json({ invalid: true }),
  ]) {
    let calls = 0;
    const service = new WeatherService("private-test-key", async () => {
      calls++;
      return response.clone();
    });
    for (let i = 0; i < 2; i++)
      await assert.rejects(service.current(location), {
        statusCode: 503,
        code: "WEATHER_UNAVAILABLE",
      });
    assert.equal(calls, 2);
  }
  await assert.rejects(
    new WeatherService("private-test-key", async () => {
      throw new Error("private-test-key");
    }).current(location),
    { message: "Chưa lấy được thời tiết. Vui lòng thử lại sau." },
  );
});
