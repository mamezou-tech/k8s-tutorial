<template>
  <section
    v-if="message"
    class="alert"
    :class="error ? 'alert-danger' : 'alert-primary'"
    role="alert"
  >
    {{ message }}
  </section>
</template>

<script lang="ts">
import { defineComponent } from "vue";

export default defineComponent({
  name: "MessageSection",
  props: {
    message: {
      type: String,
      default: "",
    },
    error: {
      type: Boolean,
      default: false,
    },
  },
});
</script>

<style scoped></style>
