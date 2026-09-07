import { EMediaProvider } from '@/common/definitions/enums';
import { CloudinaryStorageProvider } from './providers/cloudinary';
import { SupabaseStorageProvider } from './providers/supabase';
import type { IStorageProvider } from './types';

const cache = new Map<EMediaProvider, IStorageProvider>();

export class StorageFactory {
  static get(provider: EMediaProvider): IStorageProvider {
    if (!cache.has(provider)) {
      cache.set(provider, StorageFactory.create(provider));
    }
    return cache.get(provider)!;
  }

  private static create(provider: EMediaProvider): IStorageProvider {
    switch (provider) {
      case EMediaProvider.Cloudinary:
        return new CloudinaryStorageProvider();
      case EMediaProvider.Supabase:
        return new SupabaseStorageProvider();
      default:
        throw new Error(`Unsupported storage provider: ${provider}`);
    }
  }
}
