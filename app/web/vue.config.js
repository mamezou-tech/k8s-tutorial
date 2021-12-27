module.exports = {
  devServer: {
    port: 8080,
    proxy: {
      "/api": {
        // for minikube
        target: "http://task.minikube.local",
        // for docker-desktop
        // target: "http://localhost",
        changeOrigin: true,
      },
    },
  },
};
