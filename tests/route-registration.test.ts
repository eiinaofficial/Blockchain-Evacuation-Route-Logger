import { describe, it, expect, beforeEach } from "vitest";

const ERR_NOT_AUTHORIZED = 100;
const ERR_INVALID_HASH = 101;
const ERR_INVALID_DESCRIPTION = 102;
const ERR_INVALID_SAFETY_LEVEL = 103;
const ERR_INVALID_GEOLOCATION = 104;
const ERR_ROUTE_ALREADY_EXISTS = 105;
const ERR_ROUTE_NOT_FOUND = 107;
const ERR_INVALID_BOUNDARIES = 111;
const ERR_MAX_ROUTES_EXCEEDED = 114;
const ERR_INVALID_ROUTE_TYPE = 115;
const ERR_INVALID_DISTANCE = 116;
const ERR_INVALID_ELEVATION = 117;
const ERR_INVALID_WEATHER_CONDITION = 118;
const ERR_INVALID_TRAFFIC_STATUS = 119;
const ERR_INVALID_UPDATE_HASH = 113;

interface Geolocation {
  lat: number;
  lon: number;
}
interface Boundaries {
  minLat: number;
  maxLat: number;
  minLon: number;
  maxLon: number;
}
interface Route {
  hash: string;
  description: string;
  safetyLevel: number;
  geolocation: Geolocation;
  boundaries: Boundaries;
  timestamp: number;
  creator: string;
  routeType: string;
  distance: number;
  elevation: number;
  weatherCondition: string;
  trafficStatus: string;
  emergencyStatus: boolean;
}
interface RouteUpdate {
  updateHash: string;
  updateDescription: string;
  updateSafetyLevel: number;
  updateTimestamp: number;
  updater: string;
}

class RouteRegistrationMock {
  state!: {
    nextRouteId: number;
    maxRoutes: number;
    routes: Map<number, Route>;
    routeUpdates: Map<number, RouteUpdate>;
  };
  blockHeight = 0;
  caller = "ST1TEST"; // simulated caller
  authorities = new Set<string>();

  constructor() {
    this.reset();
  }
  reset() {
    this.state = {
      nextRouteId: 0,
      maxRoutes: 1000,
      routes: new Map(),
      routeUpdates: new Map(),
    };
    this.blockHeight = 0;
    this.caller = "ST1TEST";
    this.authorities = new Set(["ST1TEST"]); // caller is authorized
  }

  isVerifiedAuthority(principal: string) {
    return { ok: true, value: this.authorities.has(principal) };
  }

  registerRoute(
    routeHash: string,
    description: string,
    safetyLevel: number,
    geolocation: Geolocation,
    boundaries: Boundaries,
    routeType: string,
    distance: number,
    elevation: number,
    weatherCondition: string,
    trafficStatus: string,
    emergencyStatus: boolean
  ) {
    const nextId = this.state.nextRouteId;
    if (nextId >= this.state.maxRoutes) return { ok: false, value: ERR_MAX_ROUTES_EXCEEDED };
    if (routeHash.length !== 64 || !/^[0-9a-fA-F]+$/.test(routeHash)) return { ok: false, value: ERR_INVALID_HASH };
    if (!description || description.length > 500) return { ok: false, value: ERR_INVALID_DESCRIPTION };
    if (safetyLevel < 1 || safetyLevel > 5) return { ok: false, value: ERR_INVALID_SAFETY_LEVEL };
    if (geolocation.lat < -90 || geolocation.lat > 90 || geolocation.lon < -180 || geolocation.lon > 180)
      return { ok: false, value: ERR_INVALID_GEOLOCATION };
    if (boundaries.minLat > boundaries.maxLat || boundaries.minLon > boundaries.maxLon)
      return { ok: false, value: ERR_INVALID_BOUNDARIES };
    if (!["road", "path", "water"].includes(routeType)) return { ok: false, value: ERR_INVALID_ROUTE_TYPE };
    if (distance > 1000000) return { ok: false, value: ERR_INVALID_DISTANCE };
    if (elevation > 10000) return { ok: false, value: ERR_INVALID_ELEVATION };
    if (!["clear", "rainy", "stormy"].includes(weatherCondition)) return { ok: false, value: ERR_INVALID_WEATHER_CONDITION };
    if (!["low", "medium", "high"].includes(trafficStatus)) return { ok: false, value: ERR_INVALID_TRAFFIC_STATUS };

    if (!this.isVerifiedAuthority(this.caller).value) return { ok: false, value: ERR_NOT_AUTHORIZED };
    if (Array.from(this.state.routes.values()).some(r => r.hash === routeHash))
      return { ok: false, value: ERR_ROUTE_ALREADY_EXISTS };

    const newRoute: Route = {
      hash: routeHash,
      description,
      safetyLevel,
      geolocation,
      boundaries,
      timestamp: this.blockHeight,
      creator: this.caller,
      routeType,
      distance,
      elevation,
      weatherCondition,
      trafficStatus,
      emergencyStatus,
    };
    this.state.routes.set(nextId, newRoute);
    this.state.nextRouteId++;
    return { ok: true, value: nextId };
  }

  getRoute(id: number) {
    const route = this.state.routes.get(id);
    return route ? { ok: true, value: route } : { ok: false, value: null };
  }

  updateRoute(id: number, updateHash: string, desc: string, level: number) {
    const route = this.state.routes.get(id);
    if (!route) return { ok: false, value: ERR_ROUTE_NOT_FOUND };
    if (route.creator !== this.caller) return { ok: false, value: ERR_NOT_AUTHORIZED };
    if (updateHash.length !== 64 || !/^[0-9a-fA-F]+$/.test(updateHash)) return { ok: false, value: ERR_INVALID_UPDATE_HASH };
    if (!desc || desc.length > 500) return { ok: false, value: ERR_INVALID_DESCRIPTION };
    if (level < 1 || level > 5) return { ok: false, value: ERR_INVALID_SAFETY_LEVEL };

    const updated: Route = { ...route, hash: updateHash, description: desc, safetyLevel: level, timestamp: this.blockHeight };
    this.state.routes.set(id, updated);
    this.state.routeUpdates.set(id, {
      updateHash,
      updateDescription: desc,
      updateSafetyLevel: level,
      updateTimestamp: this.blockHeight,
      updater: this.caller,
    });
    return { ok: true, value: true };
  }
}

describe("RouteRegistration", () => {
  let contract: RouteRegistrationMock;
  beforeEach(() => (contract = new RouteRegistrationMock()));

  it("registers a valid route", () => {
    const result = contract.registerRoute(
      "a".repeat(64),
      "Safe path",
      3,
      { lat: 40, lon: -74 },
      { minLat: 39, maxLat: 41, minLon: -75, maxLon: -73 },
      "road",
      5000,
      100,
      "clear",
      "low",
      false
    );
    expect(result.ok).toBe(true);
    expect(contract.getRoute(0).value?.description).toBe("Safe path");
  });

  it("rejects invalid hash", () => {
    expect(
      contract.registerRoute("bad", "desc", 3, { lat: 0, lon: 0 }, { minLat: -1, maxLat: 1, minLon: -1, maxLon: 1 }, "road", 10, 5, "clear", "low", false)
    ).toEqual({ ok: false, value: ERR_INVALID_HASH });
  });

  it("rejects invalid geolocation", () => {
    expect(
      contract.registerRoute("a".repeat(64), "desc", 3, { lat: 100, lon: 0 }, { minLat: -1, maxLat: 1, minLon: -1, maxLon: 1 }, "road", 10, 5, "clear", "low", false)
    ).toEqual({ ok: false, value: ERR_INVALID_GEOLOCATION });
  });

  it("rejects duplicate route", () => {
    contract.registerRoute("a".repeat(64), "desc", 3, { lat: 0, lon: 0 }, { minLat: -1, maxLat: 1, minLon: -1, maxLon: 1 }, "road", 10, 5, "clear", "low", false);
    expect(
      contract.registerRoute("a".repeat(64), "desc2", 3, { lat: 0, lon: 0 }, { minLat: -1, maxLat: 1, minLon: -1, maxLon: 1 }, "road", 10, 5, "clear", "low", false)
    ).toEqual({ ok: false, value: ERR_ROUTE_ALREADY_EXISTS });
  });

  it("updates a valid route", () => {
    contract.registerRoute("a".repeat(64), "old", 2, { lat: 0, lon: 0 }, { minLat: -1, maxLat: 1, minLon: -1, maxLon: 1 }, "road", 10, 5, "clear", "low", false);
    const res = contract.updateRoute(0, "b".repeat(64), "new", 4);
    expect(res.ok).toBe(true);
    expect(contract.getRoute(0).value?.description).toBe("new");
  });

  it("rejects update for non-existent route", () => {
    expect(contract.updateRoute(99, "b".repeat(64), "x", 3)).toEqual({ ok: false, value: ERR_ROUTE_NOT_FOUND });
  });
});
