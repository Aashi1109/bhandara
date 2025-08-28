import { RedisCache } from "@/features/cache";
import { CACHE_NAMESPACE_CONFIG } from "@/constants";

const exploreCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Explore.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Explore.ttl,
});

export const getExplorePage = (userId: string) =>
  exploreCache.getItem<number>(userId);

export const setExplorePage = (userId: string, page: number) =>
  exploreCache.setItem(userId, page);

export const deleteExplorePage = (userId: string) =>
  exploreCache.deleteItem(userId);

export enum EExploreComponents {
  TasteCalendar = "taste-calendar",
  FoodieFeed = "foodie-feed",
  Reels = "reels",
  Collaborations = "collaborations",
  Trending = "trending",
}

interface BasePayload {
  id: string;
  title: string;
  media: {
    type: string;
    url: string;
    thumbnailUrl: string;
  };
  location: Record<string, any>;
  startTime: Date | string | undefined;
  endTime: Date | string | undefined;
  tags: any[];
  creator: any;
  createdAt: Date | string;
  status: string;
}

export interface ExploreSection {
  component: EExploreComponents;
  title: string;
  subtitle: string;
  payload: any;
}

export const componentMeta: Record<
  EExploreComponents,
  { title: string; subtitle: string }
> = {
  [EExploreComponents.TasteCalendar]: {
    title: "Taste Calendar",
    subtitle: "Discover food events by time of day",
  },
  [EExploreComponents.FoodieFeed]: {
    title: "Foodie Feed",
    subtitle: "Live events happening now",
  },
  [EExploreComponents.Reels]: {
    title: "Food Reels",
    subtitle: "Watch latest event highlights",
  },
  [EExploreComponents.Collaborations]: {
    title: "Collaborations",
    subtitle: "Special events with chefs & influencers",
  },
  [EExploreComponents.Trending]: {
    title: "Trending",
    subtitle: "Popular events in your area",
  },
};

const toBasePayload = (ev: any): BasePayload => {
  const firstMedia =
    Array.isArray(ev.media) && ev.media.length ? ev.media[0] : null;
  return {
    id: ev.id,
    title: ev.name,
    media: firstMedia
      ? {
          type: firstMedia.type,
          url: firstMedia.url,
          thumbnailUrl: firstMedia.thumbnail || firstMedia.url,
        }
      : { type: "", url: "", thumbnailUrl: "" },
    location: ev.location,
    startTime: ev.timings?.start,
    endTime: ev.timings?.end,
    tags: ev.tags || [],
    creator: ev.creator,
    createdAt: ev.createdAt,
    status: ev.status,
  };
};

const getTimeOfDay = (date?: Date | string) => {
  const d = date ? new Date(date) : new Date();
  const h = d.getHours();
  if (h >= 5 && h < 12) return "morning";
  if (h >= 12 && h < 18) return "evening";
  return "night";
};

export const buildExploreSections = (events: any[]): ExploreSection[] => {
  const baseEvents = events.map(toBasePayload);

  const tasteCalendarPayload = events.map((ev) => ({
    ...toBasePayload(ev),
    filter: [getTimeOfDay(ev.timings?.start)],
  }));

  const foodieFeedPayload = baseEvents.filter(
    (ev) => ev.status === "ongoing" || ev.status === "upcoming"
  );

  const reelsPayload = events
    .filter(
      (ev) =>
        Array.isArray(ev.media) && ev.media.some((m) => m.type === "video")
    )
    .map((ev) => ({
      ...toBasePayload(ev),
      likes: (ev.reactions || []).length || 0,
      comments: 0,
      user: ev.creator,
    }));

  const collaborationsPayload = events
    .filter((ev) => Array.isArray(ev.verifiers) && ev.verifiers.length)
    .map((ev) => ({
      ...toBasePayload(ev),
      chef: ev.creator?.name || "",
      time: ev.timings?.start,
      going: Array.isArray(ev.participants) ? ev.participants.length : 0,
      verifiers: ev.verifiers,
    }));

  const trendingPayload = [...events]
    .sort(
      (a, b) =>
        (Array.isArray(b.participants) ? b.participants.length : 0) -
        (Array.isArray(a.participants) ? a.participants.length : 0)
    )
    .map((ev) => ({
      ...toBasePayload(ev),
      going: Array.isArray(ev.participants) ? ev.participants.length : 0,
      verifiers: ev.verifiers,
    }));

  const sections: ExploreSection[] = [];

  if (tasteCalendarPayload.length)
    sections.push({
      component: EExploreComponents.TasteCalendar,
      title: componentMeta[EExploreComponents.TasteCalendar].title,
      subtitle: componentMeta[EExploreComponents.TasteCalendar].subtitle,
      payload: tasteCalendarPayload,
    });

  if (foodieFeedPayload.length)
    sections.push({
      component: EExploreComponents.FoodieFeed,
      title: componentMeta[EExploreComponents.FoodieFeed].title,
      subtitle: componentMeta[EExploreComponents.FoodieFeed].subtitle,
      payload: foodieFeedPayload,
    });

  if (reelsPayload.length)
    sections.push({
      component: EExploreComponents.Reels,
      title: componentMeta[EExploreComponents.Reels].title,
      subtitle: componentMeta[EExploreComponents.Reels].subtitle,
      payload: reelsPayload,
    });

  if (collaborationsPayload.length)
    sections.push({
      component: EExploreComponents.Collaborations,
      title: componentMeta[EExploreComponents.Collaborations].title,
      subtitle: componentMeta[EExploreComponents.Collaborations].subtitle,
      payload: collaborationsPayload,
    });

  if (trendingPayload.length)
    sections.push({
      component: EExploreComponents.Trending,
      title: componentMeta[EExploreComponents.Trending].title,
      subtitle: componentMeta[EExploreComponents.Trending].subtitle,
      payload: trendingPayload,
    });

  return sections;
};
