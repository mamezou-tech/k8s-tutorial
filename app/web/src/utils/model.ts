export interface Task {
  taskId?: string;
  userName: string;
  title: string;
  startAt: number;
  contents: string;
  notified: boolean;
  done: boolean;
}
