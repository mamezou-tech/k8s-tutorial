import axios from "axios";

const client = axios.create({
  baseURL: process.env.VUE_APP_API_ENDPOINT ?? "",
  timeout: 30000,
});

export default client;
