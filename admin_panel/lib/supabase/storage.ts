import { getSupabaseBrowserClient } from "@/lib/supabase/client";

function extFromName(fileName: string) {
  const parts = fileName.split(".");
  return parts.length > 1 ? parts.at(-1)?.toLowerCase() ?? "bin" : "bin";
}

export async function uploadFileToSupabase(params: {
  bucket: string;
  folder: string;
  file: File;
}) {
  const supabase = getSupabaseBrowserClient();
  const { bucket, folder, file } = params;
  console.log("[storage.upload.start]", { bucket, folder, name: file.name, size: file.size, type: file.type });
  if (!supabase) {
    // Hotfix fallback: keep feature usable without blocking admin workflow.
    const dataUrl = await toDataUrl(file);
    console.warn("[storage.upload.fallback.dataurl] Supabase env missing, using inline data URL.");
    return {
      path: `${folder}/inline-${Date.now()}`,
      publicUrl: dataUrl,
      storageBacked: false,
    };
  }
  const ext = extFromName(file.name);
  const path = `${folder}/${Date.now()}-${crypto.randomUUID()}.${ext}`;
  const { error } = await supabase.storage.from(bucket).upload(path, file, {
    cacheControl: "3600",
    upsert: false,
  });
  if (error) {
    const lower = (error.message || "").toLowerCase();
    if (lower.includes("bucket") && lower.includes("not found")) {
      const dataUrl = await toDataUrl(file);
      console.warn("[storage.upload.fallback.dataurl] Bucket not found, using inline data URL.");
      return {
        path: `${folder}/inline-${Date.now()}`,
        publicUrl: dataUrl,
        storageBacked: false,
      };
    }
    throw new Error(error.message || "Faylni storage ga yuklab bo'lmadi.");
  }
  const { data } = supabase.storage.from(bucket).getPublicUrl(path);
  return {
    path,
    publicUrl: data.publicUrl,
    storageBacked: true,
  };
}

function toDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ""));
    reader.onerror = () => reject(new Error("Faylni o'qib bo'lmadi."));
    reader.readAsDataURL(file);
  });
}
