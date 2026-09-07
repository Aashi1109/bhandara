export type ClusterSeedConfig = {
  name: string;
  latitude: number;
  longitude: number;
  nearCount: number;
  mediumCount: number;
  farCount: number;
};

export const clusterSeedConfigs: ClusterSeedConfig[] = [
  {
    name: 'Mumbai',
    latitude: 19.076,
    longitude: 72.8777,
    nearCount: 24,
    mediumCount: 12,
    farCount: 6,
  },
  {
    name: 'Delhi',
    latitude: 28.6139,
    longitude: 77.209,
    nearCount: 22,
    mediumCount: 10,
    farCount: 6,
  },
  {
    name: 'Bengaluru',
    latitude: 12.9716,
    longitude: 77.5946,
    nearCount: 20,
    mediumCount: 10,
    farCount: 5,
  },
  {
    name: 'Pune',
    latitude: 18.5204,
    longitude: 73.8567,
    nearCount: 18,
    mediumCount: 8,
    farCount: 4,
  },
];

export const fallbackTagSeeds = [
  {
    name: 'Street Food',
    value: 'street-food',
    description: 'Casual food meetups and tasting spots.',
    icon: '🌮',
    color: '#E67E22',
  },
  {
    name: 'Community Dinner',
    value: 'community-dinner',
    description: 'Shared meals for local community members.',
    icon: '🍛',
    color: '#27AE60',
  },
  {
    name: 'Food Festival',
    value: 'food-festival',
    description: 'Large-scale food gatherings with multiple stalls.',
    icon: '🎪',
    color: '#FF5733',
  },
  {
    name: 'Brunch Social',
    value: 'brunch-social',
    description: 'Daytime gatherings built around brunch.',
    icon: '🥞',
    color: '#F39C12',
  },
  {
    name: 'Late Night Bites',
    value: 'late-night-bites',
    description: 'Evening food crawls and supper clubs.',
    icon: '🌙',
    color: '#34495E',
  },
  {
    name: 'Regional Special',
    value: 'regional-special',
    description: 'Cuisine-focused community events.',
    icon: '🍲',
    color: '#2980B9',
  },
];
