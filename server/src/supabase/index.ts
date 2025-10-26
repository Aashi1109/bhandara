// Deprecated: Supabase service retained for legacy support
// Postgrest types kept for backwards compatibility with old DB service
import { PostgrestError } from "@supabase/supabase-js";

import { decode } from "base64-arraybuffer";
import { supabase } from "../connections";
import { SupabaseCustomError } from "@/exceptions";

const throwSupabaseError = (res: any) => {
  throw new SupabaseCustomError(
    res.message || res.error?.message,
    res?.status,
    res.name || res?.statusText
  );
};

export type SupabaseClient = typeof supabase;

class SupabaseService {
  private readonly supabaseClient = supabase;

  /**
   * Uploads a file to a specified bucket in Supabase storage.
   *
   * @param params - The parameters for the file upload.
   * @param params.bucket - The name of the bucket where the file will be uploaded.
   * @param params.base64FileData - The file to be uploaded. Must be in base64 format.
   * @param params.path - The path within the bucket where the file will be stored.
   * @param params.mimeType - The MIME type of the file being uploaded.
   * @param params.options - Optional additional options for the upload, such as custom headers.
   *
   * @returns A promise that resolves with the result of the upload operation.
   */
  async uploadFile({
    bucket,
    path,
    base64FileData,
    mimeType,
    options = {},
  }: {
    bucket: string;
    path: string;
    mimeType: string;
    options?: Record<string, any>;
    base64FileData: string;
  }) {
    const res = await this.supabaseClient.storage
      .from(bucket)
      .upload(path, decode(base64FileData), {
        contentType: mimeType,
        cacheControl: "3600",
        upsert: true,
        ...options,
      });

    if (res.error) throwSupabaseError(res);

    return res;
  }

  /**
   * Deletes a file from a specified bucket in Supabase storage.
   *
   * @param params - The parameters for the file deletion.
   * @param params.bucket - The name of the bucket where the file is located.
   * @param params.paths - An array of paths to the files to be deleted.
   *
   * @returns A promise that resolves with the result of the deletion operation.
   */
  async deleteFile({ bucket, paths }: { bucket: string; paths: string[] }) {
    const res = await this.supabaseClient.storage.from(bucket).remove(paths);

    if (res.error) throwSupabaseError(res);

    return res;
  }

  /**
   * Generates a signed URL for downloading a file from a specified bucket in Supabase storage.
   *
   * @param params - The parameters for the signed URL generation.
   * @param params.bucket - The name of the bucket where the file is located.
   * @param params.path - The path to the file in the bucket.
   * @param params.options - Optional additional options for the signed URL, such as expiration time and transformations.
   *
   * @returns A promise that resolves with the signed URL for downloading the file.
   */
  async getSignedUrlForDownload({
    bucket,
    path,
    options = {},
  }: {
    bucket: string;
    path: string;
    options?: {
      expiresIn?: number;
      transformations?: Record<string, any>;
    };
  }) {
    const _options = {
      expiresIn: 60,
      ...options,
    };
    const res = await this.supabaseClient.storage
      .from(bucket)
      .createSignedUrl(
        path,
        _options?.expiresIn,
        _options?.transformations || {}
      );

    if (res.error) throwSupabaseError(res);

    return res;
  }

  /**
   * Execute multiple database operations within a transaction
   * @param callback Function containing the operations to execute in transaction
   * @returns Result of the transaction
   *
   * @example
   * // Example 1: Create user and profile in a transaction
   * const { data, error } = await supabaseService.transaction(async (client) => {
   *   // Insert a new user
   *   const { data: user } = await client
   *     .from('users')
   *     .insert({ name: 'John Doe', email: 'john@example.com' })
   *     .select()
   *     .single();
   *
   *   // Insert profile for the user
   *   const { data: profile } = await client
   *     .from('profiles')
   *     .insert({ user_id: user.id, bio: 'Software Developer' })
   *     .select()
   *     .single();
   *
   *   return { user, profile };
   * });
   *
   */
  async transaction<T>(
    callback: (client: typeof this.supabaseClient) => Promise<T>
  ): Promise<{ data: T | null; error: PostgrestError | null }> {
    try {
      // Begin transaction
      await this.supabaseClient.rpc("begin");

      // Execute the callback with transaction
      const result = await callback(this.supabaseClient);

      // Commit transaction
      await this.supabaseClient.rpc("commit");

      return result as {
        data: T | null;
        error: PostgrestError | null;
      };
    } catch (error) {
      // Rollback transaction on error
      const res = await this.supabaseClient.rpc("rollback");
      throwSupabaseError(error);
    }
  }

  async getSignedUrlForUpload({
    bucket,
    path,
    options,
  }: {
    bucket: string;
    path: string;
    options?: {
      upsert?: boolean;
    };
  }) {
    const res = await this.supabaseClient.storage
      .from(bucket)
      .createSignedUploadUrl(path, {
        upsert: true,
        ...options,
      });

    if (res.error) throwSupabaseError(res);

    return res;
  }

  async uploadFileToSignedUrl({
    bucket,
    path,
    base64FileData,
    mimeType,
    token,
  }: {
    bucket: string;
    path: string;
    base64FileData: string;
    mimeType: string;
    token: string;
  }) {
    const res = await this.supabaseClient.storage
      .from(bucket)
      .uploadToSignedUrl(path, token, decode(base64FileData), {
        contentType: mimeType,
        upsert: true,
      });

    if (res.error) throwSupabaseError(res);

    return res;
  }

  async getPublicUrl({
    bucket,
    path,
    expiresIn = 60,
    options = {},
  }: {
    bucket: string;
    path: string;
    expiresIn?: number;
    options?: {
      transformations?: any;
      download?: boolean;
    };
  }) {
    const res = await this.supabaseClient.storage
      .from(bucket)
      .createSignedUrl(path, expiresIn, options);

    if (res.error) throwSupabaseError(res);

    return res;
  }

  async getBulkPublicUrls({
    bucket,
    paths,
    expiresIn = 60,
    options = { download: false },
  }: {
    bucket: string;
    paths: string[];
    expiresIn?: number;
    options?: {
      download: boolean;
    };
  }) {
    const res = await this.supabaseClient.storage
      .from(bucket)
      .createSignedUrls(paths, expiresIn, options);

    if (res.error) throwSupabaseError(res);

    return res;
  }

  async executeRpc<T>(
    name: string,
    params: Record<string, any>
  ): Promise<{ data: T | null; error: PostgrestError | null }> {
    const res = await this.supabaseClient.rpc(name, params);
    if (res.error) throwSupabaseError(res);
    return res;
  }
}

export default SupabaseService;
