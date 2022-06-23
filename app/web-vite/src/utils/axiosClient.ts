import axios from "axios";

const client = axios.create({
  baseURL: import.meta.env.VITE_API_ENDPOINT ?? "",
  timeout: 30000,
});

export default client;
