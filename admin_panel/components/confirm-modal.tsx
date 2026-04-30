import { Button } from "@/components/ui/button";
import { AppModal } from "@/components/modal";

interface ConfirmModalProps {
  open: boolean;
  title: string;
  description: string;
  confirmText?: string;
  cancelText?: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmModal({
  open,
  title,
  description,
  confirmText = "Tasdiqlash",
  cancelText = "Bekor qilish",
  onConfirm,
  onCancel,
}: ConfirmModalProps) {
  return (
    <AppModal open={open} onOpenChange={(nextOpen) => (!nextOpen ? onCancel() : undefined)} title={title} description={description}>
      <div className="flex justify-end gap-2">
        <Button variant="outline" className="h-10 rounded-xl" onClick={onCancel}>
          {cancelText}
        </Button>
        <Button variant="destructive" className="h-10 rounded-xl" onClick={onConfirm}>
          {confirmText}
        </Button>
      </div>
    </AppModal>
  );
}
