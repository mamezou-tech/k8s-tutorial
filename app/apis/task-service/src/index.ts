import express, { ErrorRequestHandler } from "express";
import createTaskHandler from "./create-task";
import updateTaskHandler from "./update-task";
import listTasksHandler from "./list-tasks";
import Router from "express-promise-router";

const app = express();
app.use(express.json());

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  if (res.headersSent) {
    return next(err);
  }
  console.log("[ERROR]", err);
  res.header("Content-Type", "text/plain");
  res.status(500).send(err instanceof Error ? err.message : "error");
};
app.use(errorHandler);

const router = Router();
app.use("/api", router);
router.post("/tasks", () => createTaskHandler);
router.put("/tasks", updateTaskHandler);
router.get("/tasks", listTasksHandler);

app.get("/health/liveness", (req, res) => {
  res.send("liveness OK");
});
app.get("/health/readiness", (req, res) => {
  res.send("readiness OK");
});
app.get("/health/startup", (req, res) => {
  res.send("startup OK");
});

const port = 3000;
const host = "0.0.0.0"
app.listen(port, host, () => {
  console.log(`task-service listening at http://${host}:${port}`);
});
