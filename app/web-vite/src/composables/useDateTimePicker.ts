import { onMounted, Ref } from "vue";
import flatpickr from "flatpickr";
import { Japanese } from "flatpickr/dist/l10n/ja";
import "flatpickr/dist/flatpickr.css";

flatpickr.l10ns.default.firstDayOfWeek = 0; // sunday

export default function useDateTimePicker(
  node: Ref<Node | undefined>
): unknown {
  onMounted(() => {
    if (node.value) {
      flatpickr(node.value, {
        locale: Japanese,
        enableTime: true,
        dateFormat: "Y-m-d H:i",
      });
    }
  });
  return {};
}
