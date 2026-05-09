export interface IUploadFileParams {
  bucket: string;
  path: string;
  base64FileData: string;
  mimeType: string;
  options?: Record<string, any>;
}

export interface IMediaThumbnails {
  sm: string;
  md: string;
  xl: string;
}

export interface IUploadResult {
  path: string;
  thumbnails?: IMediaThumbnails;
  variants?: IMediaThumbnails;
  streamUrl?: string;
}

export interface IDeleteFileParams {
  bucket: string;
  path: string;
}

export interface IGetPublicUrlParams {
  bucket: string;
  path: string;
  expiresIn?: number;
  options?: Record<string, any>;
}

export interface IGetPublicUrlResult {
  signedUrl: string;
  expiresAt: Date | number;
}

export interface IGetClientUploadParamsInput {
  bucket: string;
  path: string;
  resourceType: string;
  rid: string;
}

export interface IGetClientUploadParamsResult {
  signedURL: string;
  path: string;
  token?: string;
}

export interface IStorageProvider {
  uploadFile(params: IUploadFileParams): Promise<IUploadResult>;
  deleteFile(params: IDeleteFileParams): Promise<void>;
  getPublicUrl(params: IGetPublicUrlParams): Promise<IGetPublicUrlResult>;
  getBulkPublicUrls(params: {
    bucket: string;
    paths: string[];
    expiresIn?: number;
  }): Promise<Record<string, IGetPublicUrlResult>>;
  getClientUploadParams(params: IGetClientUploadParamsInput): Promise<IGetClientUploadParamsResult>;
}
