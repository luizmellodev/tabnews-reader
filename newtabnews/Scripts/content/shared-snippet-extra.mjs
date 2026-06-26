/** 50º snippet compartilhado entre Big O e AlgoSpot. */

export const sharedSnippetExtra = {
  snippet:
    "function findMin(arr):\n  minVal = arr[0]\n  for i in 1..arr.length:\n    if arr[i] < minVal:\n      minVal = arr[i]\n  return minVal",
  bigO: {
    id: "shared-find-min",
    title: "Encontrar mínimo",
    options: ["O(1)", "O(n)", "O(n log n)", "O(n²)"],
    answer: "O(n)",
    difficulty: "easy",
    caseNote: "pior caso",
    explanation: "Compara cada elemento uma vez para achar o menor valor.",
    hint: "Um único loop sobre n elementos.",
    reference: "https://www.geeksforgeeks.org/dsa/minimum-element-in-an-array/",
  },
  algoSpot: {
    id: "shared-as-find-min",
    title: "Encontrar mínimo",
    options: ["Encontrar mínimo", "Encontrar máximo", "Busca linear", "Moore voting"],
    answer: "Encontrar mínimo",
    difficulty: "easy",
    category: "basico",
    complexity: "O(n)",
    explanation: "Percorre o array mantendo o menor valor visto até o momento.",
    hint: "Compara arr[i] com minVal a cada passo.",
    reference: "https://www.geeksforgeeks.org/dsa/minimum-element-in-an-array/",
    whatItIs:
      "Percorre o array uma vez para encontrar o menor elemento — o oposto de encontrar o máximo.",
  },
};
