"use client";

import { useRef } from "react";
import type { ChangeEvent } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface ImagePickerProps {
  label: string;
  value: string;
  helperText?: string;
  onChange: (value: string) => void;
}

export function ImagePicker({ label, value, helperText, onChange }: ImagePickerProps) {
  const inputRef = useRef<HTMLInputElement | null>(null);

  const onFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      onChange(String(reader.result ?? ""));
    };
    reader.readAsDataURL(file);
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
      {helperText ? <p className="text-xs text-slate-500">{helperText}</p> : null}
    </div>
  );
}
