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
    if (!this.apiKey)
      throw new ApiError(
        503,
        "WEATHER_NOT_CONFIGURED",
        "Chưa cấu hình dịch vụ thời tiết.",
      );
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
    const url = new URL("https://api.openweathermap.org/data/2.5/weather");
    url.search = new URLSearchParams({
      lat: String(location.latitude),
      lon: String(location.longitude),
      appid: this.apiKey!,
      units: "metric",
      lang: "vi",
    }).toString();
    try {
      const response = await this.request(url, {
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) throw new Error("Weather provider unavailable");
      const value = responseSchema.parse(await response.json());
      const data: WeatherData = {
        location: location.name,
        temperature: value.main.temp,
        humidity: value.main.humidity,
        windSpeed: value.wind.speed,
        description: value.weather[0]!.description,
        condition: value.weather[0]!.id,
        observedAt: new Date(value.dt * 1000).toISOString(),
        provider: "OpenWeather",
      };
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
