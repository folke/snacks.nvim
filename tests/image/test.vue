<script setup>
import { ref } from "vue";
const greeting = ref("Hello World!");
</script>

<template>
  <p class="greeting">{{ greeting }}</p>
  <img src="test.png" alt="test" />
</template>

<style>
.greeting {
  color: red;
  font-weight: bold;
  background: url("test.png");
}
</style>
