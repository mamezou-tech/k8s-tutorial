<template>
  <header>
    <h1>タスク管理ツール</h1>
  </header>
  <div class="container-fluid">
    <router-view />
  </div>
</template>

<style>
#app {
  font-family: "Helvetica Neue", "Arial", "Hiragino Kaku Gothic ProN",
    "Hiragino Sans", sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  color: #2c3e50;
}
body {
  background-color: aliceblue;
}
header {
  margin: 2rem 0;
  text-align: center;
}
</style>
