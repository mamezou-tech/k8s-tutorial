<template>
  <div class="row d-flex justify-content-center">
    <div class="col-auto">
      <p>{{ message }}</p>
    </div>
  </div>
  <div class="row d-flex justify-content-center mt-4">
    <label for="user-name" class="col-auto col-form-label"
      >ユーザー名</label
    >
    <div class="col-auto">
      <input
        type="text"
        class="form-control form-control-lg"
        id="user-name"
        v-model="userName"
      />
    </div>
    <div class="col-auto">
      <button
        class="btn btn-primary btn-lg"
        :disabled="!userName"
        @click="onClickStart"
      >
        開始する
      </button>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref } from "vue";
import { useRouter } from "vue-router";

export default defineComponent({
  name: "Home",
  setup() {
    const message = ref(
      "タスク管理ツールへようこそ！ユーザー名を入力して開始してください。"
    );
    const userName = ref("");
    const router = useRouter();

    const onClickStart = () => {
      router.push({
        path: "/tasks",
        query: {
          userName: userName.value,
        },
      });
    };
    return {
      message,
      userName,
      onClickStart,
    };
  },
});
</script>
