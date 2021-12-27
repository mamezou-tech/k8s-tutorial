import { RequestHandler } from "express";
import dayjs from "dayjs";
import { TaskResponse, TaskSearchRequest } from "./types";
import client from "./dynamodb-client";

const listTasksHandler: RequestHandler<
  {},
  TaskResponse[],
  {},
  TaskSearchRequest
> = async (req, res) => {
  console.log("received list request", req.query);
  const name = req.query.userName;
  const start = req.query.start ? parseInt(req.query.start || "0") : dayjs().startOf("day").unix();
  const end = req.query.end ? parseInt(req.query.end || "0") : dayjs("2099-12-31").endOf("day").unix();
  const result = await client
    .query({
      TableName: process.env.TASK_TABLE_NAME || "tasks",
      IndexName: "user_index",
      KeyConditionExpression:
        "user_name=:userName AND start_at BETWEEN :start AND :end",
      ExpressionAttributeValues: {
        ":userName": name,
        ":start": start,
        ":end": end,
      },
      Limit: 100,
    })
    .promise();
  const tasks: TaskResponse[] = (result.Items || []).map((item) => {
    return {
      userName: item.user_name,
      startAt: item.start_at,
      taskId: item.task_id,
      title: item.title,
      contents: item.contents,
      notified: item.notified,
      done: item.status === "DONE",
    };
  });
  res.send(tasks);
};

export default listTasksHandler;
