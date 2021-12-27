import client from "@/utils/axiosClient";
import { Task } from "@/utils/model";
import { AxiosError } from "axios";
import dayjs from "dayjs";

export default function useTaskRepositories(userName: string) {
  const fetchTasks = async (start: number = dayjs().startOf("day").unix(), end?: number) => {
    try {
      const response = await client.get<Task[]>("/tasks", {
        params: {
          userName,
          start,
          end
        },
      });
      return response.data;
    } catch (e) {
      throw new Error(errorMessage(e));
    }
  };

  const updateTask = async (task: Task): Promise<void> => {
    if (!task.taskId) return;
    try {
      await client.put(`/tasks`, task);
    } catch (e) {
      throw new Error(errorMessage(e));
    }
  };

  const createTask = async (task: Task): Promise<string> => {
    try {
      const response = await client.post("/tasks", task);
      return response.data.taskId;
    } catch (e) {
      throw new Error(errorMessage(e));
    }
  };

  return {
    fetchTasks,
    updateTask,
    createTask,
  };
}

function errorMessage(e: unknown): string {
  if (e instanceof Error) {
    if (instanceOfAxiosError(e)) {
      return e.response?.data || e.message;
    }
    return e.message;
  }
  return "unknown error";
}

// eslint-disable-next-line
function instanceOfAxiosError(e: any): e is AxiosError {
  return "isAxiosError" in e && "config" in e && "response" in e;
}
