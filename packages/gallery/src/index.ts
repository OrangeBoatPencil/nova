import { StorageClient } from '@supabase/storage-js';
import { nanoid } from 'nanoid';
import { searchFiles } from './search';

export interface FileUploadOptions {
  file: File;
  bucket: string;
  path?: string;
  metadata?: Record<string, string>;
}

export interface FileMetadata {
  id: string;
  name: string;
  bucket: string;
  path: string;
  size: number;
  mimeType: string;
  createdAt: string;
  updatedAt: string;
  metadata?: Record<string, string>;
}

/**
 * Creates a gallery storage client
 * @param storageClient Supabase storage client
 */
export const createGalleryClient = (storageClient: StorageClient) => {
  const upload = async ({ file, bucket, path = '', metadata = {} }: FileUploadOptions) => {
    const fileId = nanoid();
    const fileName = `${fileId}-${file.name}`;
    const fullPath = path ? `${path}/${fileName}` : fileName;

    const { data, error } = await storageClient
      .from(bucket)
      .upload(fullPath, file, {
        upsert: true,
        contentType: file.type,
      });

    if (error) {
      throw error;
    }

    // Store metadata in database if needed
    const fileMetadata: FileMetadata = {
      id: fileId,
      name: file.name,
      bucket,
      path: data?.path || fullPath,
      size: file.size,
      mimeType: file.type,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      metadata,
    };

    return fileMetadata;
  };

  const getPublicUrl = (bucket: string, path: string) => {
    const { data } = storageClient.from(bucket).getPublicUrl(path);
    return data.publicUrl;
  };

  const remove = async (bucket: string, path: string) => {
    const { error } = await storageClient.from(bucket).remove([path]);
    if (error) {
      throw error;
    }
    return true;
  };

  return {
    upload,
    getPublicUrl,
    remove,
  };
};

export type GalleryClient = ReturnType<typeof createGalleryClient>;

// Export search utilities
export { searchFiles }; 