export type TaskCreateRequest = {
  userName: string;
  title: string;
  startAt: number;
  contents: string;
};

export type TaskSearchRequest = {
  userName: string;
  start?: string;
  end?: string;
};

export type TaskUpdateRequest = TaskCreateRequest & {
  taskId: string;
  notified: boolean;
  done: boolean;
};

export type TaskResponse = TaskCreateRequest & {
  taskId: string;
  notified: boolean;
  done: boolean;
};
