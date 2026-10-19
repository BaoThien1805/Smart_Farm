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

test("missing key, provider failures and malformed responses return sanitized errors; failed requests can retry", async () => {
  await assert.rejects(new WeatherService().current(location), {
    statusCode: 503,
    code: "WEATHER_NOT_CONFIGURED",
  });
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
