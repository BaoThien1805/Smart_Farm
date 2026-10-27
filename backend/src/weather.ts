import { z } from "zod";
import { ApiError } from "./auth/service.js";

export type WeatherLocation = {
  latitude: number;
  longitude: number;
  name: string;
};
const responseSchema = z.object({
  main: z.object({ temp: z.number(), humidity: z.number().min(0).max(100) }),
  weather: z
    .array(z.object({ id: z.number().int(), description: z.string() }))
    .min(1),
  wind: z.object({ speed: z.number().nonnegative() }),
  dt: z.number().int().positive(),
});
const openMeteoSchema = z.object({
  current_units: z.object({
    temperature_2m: z.literal("°C"),
    relative_humidity_2m: z.literal("%"),
    wind_speed_10m: z.literal("m/s"),
  }),
  current: z.object({
    time: z.number().int().positive(),
    temperature_2m: z.number(),
    relative_humidity_2m: z.number().min(0).max(100),
    wind_speed_10m: z.number().nonnegative(),
    weather_code: z.number().int(),
  }),
});
// WMO codes are translated to the condition groups already used by the app.
// https://open-meteo.com/en/docs#weathervariables
function wmoCondition(code: number): [string, number] {
  switch (code) {
    case 0:
      return ["Trời quang", 800];
    case 1:
      return ["Ít mây", 801];
    case 2:
      return ["Có mây", 802];
    case 3:
      return ["Nhiều mây", 804];
    case 45:
    case 48:
      return ["Sương mù", 741];
    case 51:
    case 53:
    case 55:
      return ["Mưa phùn", 300];
    case 56:
    case 57:
      return ["Mưa phùn đóng băng", 511];
    case 61:
      return ["Mưa nhẹ", 500];
    case 63:
      return ["Mưa vừa", 501];
    case 65:
      return ["Mưa to", 502];
    case 66:
    case 67:
      return ["Mưa đóng băng", 511];
    case 71:
    case 73:
    case 75:
    case 77:
      return ["Tuyết rơi", 600];
    case 80:
    case 81:
    case 82:
      return ["Mưa rào", 520];
    case 85:
    case 86:
      return ["Mưa tuyết", 620];
    case 95:
    case 97:
      return ["Dông", 200];
    case 96:
    case 99:
      return ["Dông kèm mưa đá", 201];
    default:
      throw new Error("Unknown weather condition");
  }
}
export type WeatherData = {
  location: string;
  temperature: number;
  humidity: number;
  windSpeed: number;
  description: string;
  condition: number;
  observedAt: string;
  provider: string;
};

export class WeatherService {
  private cache = new Map<string, { data: WeatherData; expires: number }>();
  private pending = new Map<string, Promise<WeatherData>>();
  constructor(
    private apiKey?: string,
    private request: typeof fetch = fetch,
  ) {}

  async current(location: WeatherLocation): Promise<WeatherData> {
    const key = `${location.latitude},${location.longitude}`;
    const cached = this.cache.get(key);
    if (cached && cached.expires > Date.now())
      return { ...cached.data, location: location.name };
    const pending = this.pending.get(key);
    if (pending) return { ...(await pending), location: location.name };
    const task = this.load(location);
    this.pending.set(key, task);
    try {
      return await task;
    } finally {
      this.pending.delete(key);
    }
  }

  private async load(location: WeatherLocation): Promise<WeatherData> {
    const openWeather = !!this.apiKey;
    const url = new URL(
      openWeather
        ? "https://api.openweathermap.org/data/2.5/weather"
        : "https://api.open-meteo.com/v1/forecast",
    );
    url.search = new URLSearchParams(
      openWeather
        ? {
            lat: String(location.latitude),
            lon: String(location.longitude),
            appid: this.apiKey!,
            units: "metric",
            lang: "vi",
          }
        : {
            latitude: String(location.latitude),
            longitude: String(location.longitude),
            current:
              "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m",
            temperature_unit: "celsius",
            wind_speed_unit: "ms",
            timeformat: "unixtime",
            timezone: "GMT",
            forecast_days: "1",
          },
    ).toString();
    try {
      const response = await this.request(url, {
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) throw new Error("Weather provider unavailable");
      const payload: unknown = await response.json();
      let data: WeatherData;
      if (openWeather) {
        const value = responseSchema.parse(payload);
        data = {
          location: location.name,
          temperature: value.main.temp,
          humidity: value.main.humidity,
          windSpeed: value.wind.speed,
          description: value.weather[0]!.description,
          condition: value.weather[0]!.id,
          observedAt: new Date(value.dt * 1000).toISOString(),
          provider: "OpenWeather",
        };
      } else {
        const value = openMeteoSchema.parse(payload).current;
        const [description, condition] = wmoCondition(value.weather_code);
        data = {
          location: location.name,
          temperature: value.temperature_2m,
          humidity: value.relative_humidity_2m,
          windSpeed: value.wind_speed_10m,
          description,
          condition,
          observedAt: new Date(value.time * 1000).toISOString(),
          provider: "Open-Meteo",
        };
      }
      for (const [key, value] of this.cache)
        if (value.expires <= Date.now()) this.cache.delete(key);
      if (this.cache.size >= 500)
        this.cache.delete(this.cache.keys().next().value!);
      this.cache.set(`${location.latitude},${location.longitude}`, {
        data,
        expires: Date.now() + 600000,
      });
      return data;
    } catch {
      // Never propagate provider errors: request URLs contain the API key.
      throw new ApiError(
        503,
        "WEATHER_UNAVAILABLE",
        "Chưa lấy được thời tiết. Vui lòng thử lại sau.",
      );
    }
  }
}
