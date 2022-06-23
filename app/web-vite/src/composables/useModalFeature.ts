import { onMounted, Ref } from "vue";
import { Modal } from "bootstrap";

export default function useModalFeature(element: Ref<Element | undefined>) {
  let bsModal: Modal | null = null;
  onMounted(() => {
    if (element?.value) {
      bsModal = new Modal(element?.value, {
        keyboard: false,
        backdrop: true,
      });
    }
  });

  const open = () => {
    if (bsModal) bsModal.show();
  };
  const close = () => {
    if (bsModal) bsModal.hide();
  };

  return {
    open,
    close,
  };
}
