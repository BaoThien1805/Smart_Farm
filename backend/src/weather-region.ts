import { z } from "zod";
import type { WeatherLocation } from "./weather.js";

const regionSchema = z.object({
  features: z.array(
    z.object({
      properties: z.object({
        state: z.string().trim().min(1).optional(),
        city: z.string().trim().min(1).optional(),
      }),
    }),
  ),
});

// Resolve the same coordinates as the weather, never the device's IP location.
export class WeatherRegionService {
  private cache = new Map<string, { region: string | null; expires: number }>();
  private pending = new Map<string, Promise<string | null>>();

  constructor(private request: typeof fetch = fetch) {}

  async current(
    location: Pick<WeatherLocation, "latitude" | "longitude">,
  ): Promise<string | null> {
    const key = `${location.latitude},${location.longitude}`;
    const cached = this.cache.get(key);
    if (cached && cached.expires > Date.now()) return cached.region;
    const pending = this.pending.get(key);
    if (pending) return pending;
    const task = this.load(location);
    this.pending.set(key, task);
    try {
      const region = await task;
      for (const [entry, value] of this.cache)
        if (value.expires <= Date.now()) this.cache.delete(entry);
      if (this.cache.size >= 500)
        this.cache.delete(this.cache.keys().next().value!);
      this.cache.set(key, {
        region,
        expires: Date.now() + (region ? 86400000 : 60000),
      });
      return region;
    } finally {
      this.pending.delete(key);
    }
  }

  private async load(
    location: Pick<WeatherLocation, "latitude" | "longitude">,
  ): Promise<string | null> {
    const url = new URL("https://photon.komoot.io/reverse");
    url.search = new URLSearchParams({
      lat: String(location.latitude),
      lon: String(location.longitude),
      limit: "1",
      // Photon's public server uses local OSM names with its default language.
      lang: "default",
    }).toString();
    try {
      const response = await this.request(url, {
        signal: AbortSignal.timeout(3000),
      });
      if (!response.ok) return null;
      const value = regionSchema.parse(await response.json()).features[0]
        ?.properties;
      return value?.state ?? value?.city ?? null;
    } catch {
      // A failed place lookup must not hide valid weather measurements.
      return null;
    }
  }
}
