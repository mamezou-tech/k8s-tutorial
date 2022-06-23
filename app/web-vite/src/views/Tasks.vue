<template>
  <message-section :message="message" />
  <div>
    <a v-if="mode === 'default'" @click="showAllTasks" href="#">全てのタスクを表示する</a>
    <a v-else @click="initTasks" href="#">予定タスクを表示する</a>
  </div>
  <div v-if="tasks.length" class="row d-flex justify-content-start mt-4">
    <div class="col-auto mt-2" v-for="task in tasks" :key="task.taskId">
      <div class="card" style="width: 18rem" :class="{'bg-secondary': !!task.done}">
        <div class="card-body">
          <h5 class="card-title">{{ task.title }}</h5>
          <h6 class="card-subtitle mb-2 text-black-50">
            {{ formatDateTime(task.startAt) }}
          </h6>
          <p class="card-text">
            <span v-for="line in task.contents.split('\n')" :key="task.taskId + line">
              {{ line }}<br />
            </span>
          </p>
          <a
            v-if="!task.done"
            class="btn btn-success btn-sm"
            @click="completeTask(task)"
            >完了にする</a
          >
        </div>
      </div>
    </div>
  </div>
  <div v-else class="row d-flex justify-content-center mt-4">
    <div class="col-auto">
      <p>タスクがありません。</p>
    </div>
  </div>
  <div class="row d-flex justify-content-center mt-4">
    <div class="col-auto">
      <button class="btn btn-primary btn-lg" @click="openTaskCreateModal">
        新しいタスクを作成する
      </button>
    </div>
  </div>

  <task-create-modal
    ref="createModal"
    @task:created="taskCreated"
    :user-name="userName"
  />
</template>

<script lang="ts">
import { defineComponent, onMounted, ref } from "vue";
import { useRoute } from "vue-router";
import TaskCreateModal from "@/components/TaskCreateModal.vue";
import useTaskRepositories from "@/composables/useTaskRepositories";
import MessageSection from "@/components/MessageSection.vue";
import { Task } from "@/utils/model";
import useDateTimeParser from "@/composables/useDateTimeParser";

export default defineComponent({
  name: "Tasks",
  components: {
    TaskCreateModal,
    MessageSection,
  },

  setup() {
    // commons
    const message = ref("");

    // task list
    const tasks = ref<Task[]>([]);
    const queryParam = useRoute().query.userName;
    const userName = Array.isArray(queryParam) ? queryParam[0] || "" : queryParam || "";
    const { fetchTasks, updateTask } = useTaskRepositories(
      userName || "unknown"
    );
    const mode = ref<"default" | "all">("default")
    const initTasks = async () => {
      try {
        message.value = "タスク一覧を取得しています...";
        mode.value = "default";
        tasks.value = await fetchTasks();
        message.value = `${userName}さんの予定タスクの一覧です`;
      } catch (e) {
        message.value = "タスク取得に失敗しました。";
      }
    };
    const showAllTasks = async () => {
      try {
        message.value = "タスク一覧を取得しています...";
        mode.value = "all";
        tasks.value = await fetchTasks(0);
        message.value = `${userName}さんの全タスクの一覧です`;
      } catch (e) {
        message.value = "タスク取得に失敗しました。";
      }
    }

    // task complete
    const completeTask = async (task: Task) => {
      try {
        task.done = true;
        await updateTask(task);
      } catch (e) {
        message.value = "タスク状態の更新に失敗しました。";
      }
    };

    // task create(modal)
    const createModal = ref<InstanceType<typeof TaskCreateModal>>();
    const openTaskCreateModal = async () => {
      if (!createModal?.value) return;
      createModal.value?.open();
    };
    const taskCreated = async () => {
      if (!createModal?.value) return;
      await initTasks();
      createModal.value?.close();
    };

    // lifecycle hook
    onMounted(initTasks);

    return {
      message,
      tasks,
      mode,
      createModal,
      userName,
      showAllTasks,
      initTasks,
      openTaskCreateModal,
      taskCreated,
      formatDateTime: useDateTimeParser().toText,
      completeTask,
    };
  },
});
</script>
