<template>
  <div
    class="modal fade"
    id="task-create-modal"
    tabindex="-1"
    aria-hidden="true"
    ref="modal"
  >
    <div class="modal-dialog">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">新規タスクを作成する</h5>
          <button
            type="button"
            class="btn-close"
            @click="close"
            aria-label="Close"
          ></button>
        </div>
        <div class="modal-body">
          <message-section :message="message" :error="error" />
          <div class="mb-3">
            <label for="start-at" class="form-label">開始時刻</label>
            <input
              type="text"
              class="form-control"
              id="start-at"
              v-model="startAt"
              ref="startAtInput"
            />
          </div>
          <div class="mb-3">
            <label for="title" class="form-label">タイトル</label>
            <input
              type="text"
              class="form-control"
              id="title"
              v-model="task.title"
              maxlength="30"
            />
          </div>
          <div class="mb-3">
            <label for="task-contents" class="form-label">内容</label>
            <textarea
              id="task-contents"
              class="form-control"
              rows="5"
              v-model="task.contents"
              maxlength="300"
            ></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" @click="close">
            キャンセル
          </button>
          <button
            type="button"
            class="btn btn-primary"
            @click="entry(task)"
            :disabled="!task.startAt || !task.title"
          >
            作成
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { computed, defineComponent, ref } from "vue";
import { Task } from "@/utils/model";
import useTaskRepositories from "@/composables/useTaskRepositories";
import useDateTimePicker from "@/composables/useDateTimePicker";
import useModalFeature from "@/composables/useModalFeature";
import MessageSection from "@/components/MessageSection.vue";
import useDateTimeParser from "@/composables/useDateTimeParser";

export default defineComponent({
  name: "TaskCreateModal",
  components: {
    MessageSection,
  },
  props: {
    userName: {
      type: String,
      required: true,
    },
  },
  setup(props, { emit }) {
    // commons
    const message = ref("新しいタスクを登録してください。");
    const emptyTask = (): Task => ({
      title: "",
      contents: "",
      notified: false,
      startAt: 0,
      userName: props.userName,
      done: false,
    });

    // datetime parser
    const { toUnixTime, toText } = useDateTimeParser();
    const startAt = computed({
      set(value: string): void {
        task.value.startAt = toUnixTime(value);
      },
      get(): string {
        return toText(task.value.startAt);
      },
    });

    // datetime picker
    const startAtInput = ref<Node>();
    useDateTimePicker(startAtInput);

    // modal feature(refs)
    const modal = ref<Element>();

    // task entry
    const task = ref<Task>(emptyTask());
    const error = ref(false);
    const { createTask } = useTaskRepositories(props.userName);
    const entry = async (target: Task) => {
      try {
        message.value = "タスクを登録中です...";
        const taskId = await createTask(target);
        error.value = false;
        task.value = emptyTask();
        emit("task:created", taskId);
        message.value = "新しいタスクを登録してください。";
      } catch (e) {
        message.value = "タスクの登録に失敗しました。";
        error.value = true;
      }
    };

    return {
      task,
      startAt,
      entry,
      error,
      message,
      startAtInput,
      modal,
      ...useModalFeature(modal),
    };
  },
});
</script>
