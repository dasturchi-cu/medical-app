"use client";

import { useRef } from "react";
import type { ChangeEvent } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { adminActions, useAdminStore } from "@/lib/admin-store";
import { notifySuccess } from "@/lib/notify";

interface ImagePickerProps {
  label: string;
  value: string;
  helperText?: string;
  onChange: (value: string) => void;
}

export function ImagePicker({ label, value, helperText, onChange }: ImagePickerProps) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const mediaAssets = useAdminStore((state) => state.mediaAssets);

  const onFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/")) return;
    const maxBytes = 6 * 1024 * 1024;
    if (file.size > maxBytes) {
      notifySuccess("Rasm 6MB dan katta bo'lmasin.");
      return;
    }

    const dataUrl = await readFileAsDataUrl(file);
    const optimized = await optimizeImage(dataUrl, 1600, 0.78);
    onChange(optimized);
    adminActions.addMediaAsset(optimized);
    notifySuccess("Rasm yuklandi va media kutubxonaga qo'shildi.");
  };

  return (
    <div className="space-y-2">
      <Label>{label}</Label>
      <div className="flex gap-2">
        <Button type="button" variant="outline" className="h-11 rounded-xl" onClick={() => inputRef.current?.click()}>
          Rasm yuklash
        </Button>
        <Input
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder="Yoki havolani kiriting: https://..."
          className="h-11 rounded-xl border-slate-200"
        />
      </div>
      <input ref={inputRef} type="file" accept="image/*" className="hidden" onChange={onFileChange} />
      {mediaAssets.length > 0 ? (
        <div className="space-y-2">
          <p className="text-xs font-medium text-slate-600">Media kutubxona</p>
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
            {mediaAssets.map((asset) => (
              <div key={asset.id} className="group relative overflow-hidden rounded-lg border border-slate-200">
                <button
                  type="button"
                  className="block h-16 w-full bg-cover bg-center"
                  style={{ backgroundImage: `url(${asset.src})` }}
                  onClick={() => {
                    onChange(asset.src);
                    notifySuccess("Kutubxonadan rasm tanlandi.");
                  }}
                />
                <button
                  type="button"
                  className="absolute right-1 top-1 hidden rounded-md bg-white/90 px-1.5 py-0.5 text-[10px] text-red-600 group-hover:block"
                  onClick={() => adminActions.deleteMediaAsset(asset.id)}
                >
                  O&apos;chirish
                </button>
              </div>
            ))}
          </div>
        </div>
      ) : null}
      {helperText ? <p className="text-xs text-slate-500">{helperText}</p> : null}
    </div>
  );
}

function readFileAsDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ""));
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function optimizeImage(dataUrl: string, maxSize: number, quality: number) {
  return new Promise<string>((resolve) => {
    const image = new Image();
    image.onload = () => {
      const ratio = Math.min(maxSize / image.width, maxSize / image.height, 1);
      const width = Math.round(image.width * ratio);
      const height = Math.round(image.height * ratio);
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext("2d");
      if (!context) {
        resolve(dataUrl);
        return;
      }
      context.drawImage(image, 0, 0, width, height);
      resolve(canvas.toDataURL("image/jpeg", quality));
    };
    image.onerror = () => resolve(dataUrl);
    image.src = dataUrl;
  });
}
