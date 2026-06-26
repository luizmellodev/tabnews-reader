#!/usr/bin/env node
/**
 * Seeds algo_spot_daily.json and algo_spot_free.json with algorithm-identification challenges.
 * Run: node newtabnews/Scripts/seed-algo-spot-content.mjs
 */
import { writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { sharedSnippetExtra } from "./content/shared-snippet-extra.mjs";
import { algoSpotExclusiveExtra } from "./content/algo-spot-exclusive-extra.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "../newtabnews/Core/Views/RestGames/AlgoSpot");

const DAILY_COUNT = 35;

/** Uma frase: categoria + para que serve o algoritmo. */
const WHAT_IT_IS = {
  "Altura da árvore": "Calcula a profundidade máxima de uma árvore binária — quantos níveis existem do root até a folha mais distante.",
  "BFS": "Busca em largura: explora um grafo ou árvore nível a nível, usando uma fila.",
  "BFS caminho mínimo": "Encontra o menor número de passos entre dois pontos em um grafo sem pesos nas arestas.",
  "BST degenerada": "Caso patológico de árvore binária de busca que perdeu o balanceamento e virou uma lista ligada.",
  "Bellman-Ford": "Algoritmo de grafo que calcula caminhos mínimos a partir de uma fonte, inclusive com arestas de peso negativo.",
  "Bubble sort": "Algoritmo de ordenação que compara pares adjacentes e troca se estiverem fora de ordem.",
  "Busca binária": "Algoritmo de busca em array ordenado que divide o intervalo pela metade a cada passo.",
  "Busca binária recursiva": "Versão recursiva da busca binária em array ordenado.",
  "Busca de substring": "Procura um padrão dentro de um texto testando cada posição possível (força bruta).",
  "Busca em BST": "Busca um valor em árvore binária de busca descendo para esquerda ou direita conforme a comparação.",
  "Busca linear": "Algoritmo de busca que percorre o array elemento a elemento até encontrar o alvo.",
  "Busca ternária": "Busca em array unimodal ou ordenado dividindo o intervalo em três partes a cada passo.",
  "Contar números pares": "Percorre o array e conta quantos elementos são divisíveis por 2.",
  "Contar pares de índices": "Conta quantos pares de índices (i, j) existem — padrão de força bruta com dois loops.",
  "Copiar array": "Operação linear que duplica todos os elementos de um array para um novo buffer.",
  "Counting sort": "Algoritmo de ordenação que conta frequências de valores em um range limitado.",
  "Crivo de Eratóstenes": "Algoritmo para encontrar todos os números primos até n eliminando múltiplos de cada primo.",
  "DFS": "Busca em profundidade: explora um grafo ou árvore indo o mais fundo possível antes de voltar.",
  "Detecção de ciclo": "Detecta se uma lista ligada tem ciclo usando dois ponteiros (tartaruga e lebre).",
  "Dijkstra": "Algoritmo de grafo que encontra caminhos mínimos a partir de uma fonte com pesos não negativos.",
  "Dividir por 2": "Padrão logarítmico que divide um valor pela metade repetidamente até chegar a 1.",
  "Dobrar até n": "Padrão logarítmico que dobra um valor até ultrapassar n, contando quantos passos.",
  "Dutch national flag": "Algoritmo de particionamento que ordena array de três valores (ex.: 0, 1, 2) em uma passagem.",
  "Edit distance": "Calcula o custo mínimo de transformar uma string em outra com inserção, deleção e substituição.",
  "Encontrar máximo": "Percorre o array uma vez para achar o maior elemento.",
  "Fibonacci recursivo": "Calcula o n-ésimo número de Fibonacci com duas chamadas recursivas por nível.",
  "Floyd-Warshall": "Algoritmo de grafo que calcula caminhos mínimos entre todos os pares de vértices.",
  "Hash linear probing": "Técnica de hash que resolve colisões procurando o próximo slot livre linearmente.",
  "Heap pop": "Remove o elemento mínimo (ou máximo) de uma heap e restaura a propriedade da árvore.",
  "Heap push": "Insere um elemento em uma heap e sobe até restaurar a propriedade da árvore.",
  "Heap sort": "Algoritmo de ordenação que usa uma heap para extrair repetidamente o maior elemento.",
  "Insertion sort": "Algoritmo de ordenação que insere cada elemento na posição correta do trecho já ordenado.",
  "Inverter recursivo": "Inverte uma lista ligada trocando os ponteiros next de forma recursiva.",
  "Kadane": "Encontra a subarray contígua de soma máxima em um array.",
  "Kruskal": "Algoritmo de grafo que constrói uma árvore geradora mínima ordenando arestas por peso.",
  "LCS": "Encontra o comprimento da maior subsequência comum entre duas strings.",
  "LIS": "Encontra o tamanho da maior subsequência estritamente crescente de um array.",
  "MDC de Euclides": "Calcula o máximo divisor comum de dois inteiros usando resto sucessivo.",
  "Mediana dois arrays": "Encontra a mediana de dois arrays já ordenados fundindo-os até a posição central.",
  "Merge de ordenados": "Funde dois arrays ordenados em um único array ordenado com dois ponteiros.",
  "Merge sort": "Algoritmo de ordenação divide-e-conquista que divide o array e faz merge das metades.",
  "Moore voting": "Encontra candidato a elemento majoritário (que aparece mais de n/2 vezes) em uma passagem.",
  "Multiplicação de matrizes": "Calcula o produto de duas matrizes quadradas com três loops aninhados.",
  "Multiplicação ingênua": "Multiplica dois números dígito a dígito como na multiplicação escolar.",
  "N-Queens": "Conta (ou gera) soluções do problema das n rainhas em um tabuleiro usando backtracking.",
  "Ordenação topológica": "Ordena vértices de um grafo direcionado acíclico respeitando dependências entre eles.",
  "Percorrer matriz": "Visita todas as células de uma matriz 2D com loops aninhados.",
  "Permutações": "Gera todas as ordens possíveis dos elementos de um array usando backtracking.",
  "Power set": "Gera todos os subconjuntos de um conjunto — incluir ou não cada elemento.",
  "Power set (bitmask)": "Gera subconjuntos iterando máscaras de bits de 0 até 2^n − 1.",
  "Prefix sum": "Pré-calcula somas acumuladas do array para responder consultas de intervalo em O(1).",
  "Prim MST": "Algoritmo de grafo que constrói árvore geradora mínima crescendo a partir de um vértice.",
  "Quick sort": "Algoritmo de ordenação que particiona o array em torno de um pivot e ordena recursivamente.",
  "Quickselect": "Encontra o k-ésimo menor elemento usando particionamento estilo quicksort.",
  "Radix sort": "Algoritmo de ordenação que ordena dígito a dígito (ou caractere a caractere) de forma estável.",
  "Rotacionar array": "Desloca os elementos de um array circularmente usando o truque das três reversões.",
  "Selection sort": "Algoritmo de ordenação que a cada passo coloca o menor elemento restante na posição correta.",
  "Seleção de atividades": "Algoritmo guloso que escolhe o máximo de atividades não sobrepostas por horário de término.",
  "Sliding window": "Técnica que mantém uma janela fixa deslizando sobre o array para calcular agregados.",
  "Soma do array": "Acumula todos os elementos do array em uma única variável.",
  "Soma recursiva": "Soma os elementos de um array usando recursão em vez de loop.",
  "Three sum": "Verifica se existem três elementos que somam zero — versão força bruta com três loops.",
  "Timsort": "Algoritmo de ordenação híbrido (merge + insertion) usado em sorts built-in modernos.",
  "Torre de Hanói": "Move n discos entre três pinos seguindo regras de tamanho, com solução recursiva clássica.",
  "Triângulo de números": "Imprime um triângulo de números com loops aninhados — padrão didático O(n²).",
  "Two pointers": "Técnica com dois índices que convergem ou avançam em ritmos diferentes no mesmo array.",
  "Two sum": "Encontra dois números que somam um alvo usando hash map em uma passagem.",
  "Union-Find": "Estrutura de conjuntos disjuntos para saber se dois elementos estão no mesmo grupo e unir grupos.",
  "Encontrar mínimo": "Percorre o array uma vez para encontrar o menor elemento — o oposto de encontrar o máximo.",
  "KMP": "Busca de padrão em texto em O(n) usando prefixo próprio mais longo (LPS).",
  "Rabin-Karp": "Busca de padrão comparando hashes rolling — confirma colisões com comparação direta.",
  "Monotonic stack": "Pilha que mantém elementos em ordem monótona para resolver próximo maior/menor em O(n).",
  "Monotonic queue": "Fila dupla com ordem monótona para máximo/mínimo em janela deslizante.",
  "Trie": "Árvore de prefixos: cada nível representa um caractere para busca/inserção de strings.",
  "LRU cache": "Cache que remove o item menos recentemente usado ao atingir capacidade.",
  "Two pointers (ordenado)": "Dois ponteiros nas extremidades de array ordenado para achar par com soma alvo.",
  "Fisher-Yates": "Embaralha array em O(n) gerando permutação uniformemente aleatória.",
  "Reservoir sampling": "Seleciona k elementos aleatórios de um fluxo de tamanho desconhecido em O(n) e uma passagem.",
  "Kosaraju SCC": "Encontra componentes fortemente conexos com duas passagens DFS e grafo reverso.",
  "Meet in the middle": "Divide problema exponencial ao meio, gera subconjuntos de cada metade e combina.",
  "Ford-Fulkerson": "Calcula fluxo máximo repetindo caminhos aumentantes de fonte ao sumidouro.",
  "Bucket sort": "Ordenação que distribui elementos em baldes por faixa e ordena cada balde.",
  "Shell sort": "Ordenação por inserção com intervalos (gaps) que vão encolhendo até 1.",
  "Pancake sort": "Ordena apenas com operações de reverter prefixo do array (panqueca).",
  "BFS bidirecional": "BFS partindo simultaneamente de origem e destino até as fronteiras se encontrarem.",
  "DFS iterativo aprofundando": "DFS com limite de profundidade crescente — combina memória baixa com completude.",
  "Fenwick tree": "Árvore indexada binária para prefix sums e updates pontuais em O(log n).",
  "Segment tree": "Árvore de segmentos para consultas e updates em intervalos em O(log n).",
  "Manacher": "Encontra palíndromo mais longo em O(n) com expansão centrada e espelhamento.",
  "Z-algorithm": "Constrói array Z de matches de prefixo em O(n) para busca de padrões.",
  "Morris traversal": "Traversal in-order em árvore binária com O(1) espaço extra via links de predecessor.",
  "Tarjan SCC": "Encontra SCCs em uma única DFS usando índices de descoberta e low-link.",
  "A*": "Busca de caminho que usa custo real + heurística para priorizar nós promissores.",
  "Comb sort": "Melhoria do bubble sort comparando elementos separados por gap decrescente.",
  "Top K com heap": "Mantém heap de tamanho k para extrair os k maiores elementos eficientemente.",
  "Dijkstra com heap": "Dijkstra com min-heap: O((V+E) log V) em vez de O(V²) com matriz.",
  "Rope (corda)": "Estrutura de corda (rope) para manipular strings grandes com concatenação eficiente.",
  "Greedy de moedas": "Algoritmo guloso que subtrai a maior moeda possível até zerar o valor.",
  "Verificar duplicata": "Detecta se há elementos repetidos em um array usando um conjunto (set).",
};

const daily = [
  c("daily-as-linear-search", "Busca linear", "function find(arr, target):\n  for i in 0..arr.length:\n    if arr[i] == target:\n      return i\n  return -1", ["Busca linear", "Busca binária", "Busca ternária", "DFS"], "Busca linear", "easy", "busca", "O(n)", "Percorre cada elemento até encontrar o alvo ou esgotar o array.", "Um único loop sobre n elementos.", "https://www.geeksforgeeks.org/dsa/linear-search/"),
  c("daily-as-binary-search", "Busca binária", "function binarySearch(arr, target):\n  left = 0\n  right = arr.length - 1\n  while left <= right:\n    mid = (left + right) / 2\n    if arr[mid] == target:\n      return mid\n    if arr[mid] < target:\n      left = mid + 1\n    else:\n      right = mid - 1\n  return -1", ["Busca binária", "Busca linear", "Busca ternária", "Busca em BST"], "Busca binária", "easy", "busca", "O(log n)", "Divide o intervalo pela metade a cada iteração em array ordenado.", "left e right convergem para o meio.", "https://www.geeksforgeeks.org/dsa/binary-search/"),
  c("daily-as-ternary-search", "Busca ternária", "function ternarySearch(arr, target, left, right):\n  if left > right:\n    return -1\n  third = (right - left) / 3\n  mid1 = left + third\n  mid2 = right - third\n  if target < arr[mid1]:\n    return ternarySearch(arr, target, left, mid1 - 1)\n  if target > arr[mid2]:\n    return ternarySearch(arr, target, mid2 + 1, right)\n  return ternarySearch(arr, target, mid1 + 1, mid2 - 1)", ["Busca ternária", "Busca binária", "Busca linear", "Interpolation search"], "Busca ternária", "medium", "busca", "O(log n)", "Divide o intervalo em três partes a cada passo.", "Dois pontos médios (mid1 e mid2).", "https://www.geeksforgeeks.org/dsa/ternary-search/"),
  c("daily-as-bubble-sort", "Bubble sort", "function bubbleSort(arr):\n  n = arr.length\n  for i in 0..n:\n    for j in 0..n - i - 1:\n      if arr[j] > arr[j + 1]:\n        swap(arr[j], arr[j + 1])", ["Bubble sort", "Selection sort", "Insertion sort", "Merge sort"], "Bubble sort", "medium", "ordenacao", "O(n²)", "Compara pares adjacentes e troca se estiverem fora de ordem.", "O maior 'borbulha' até o fim a cada passagem.", "https://www.geeksforgeeks.org/dsa/bubble-sort/"),
  c("daily-as-selection-sort", "Selection sort", "function selectionSort(arr):\n  n = arr.length\n  for i in 0..n:\n    minIdx = i\n    for j in i + 1..n:\n      if arr[j] < arr[minIdx]:\n        minIdx = j\n    swap(arr[i], arr[minIdx])", ["Selection sort", "Bubble sort", "Insertion sort", "Heap sort"], "Selection sort", "medium", "ordenacao", "O(n²)", "Em cada posição i, encontra o menor do restante e troca.", "Loop interno busca o mínimo.", "https://www.geeksforgeeks.org/dsa/selection-sort/"),
  c("daily-as-insertion-sort", "Insertion sort", "function insertionSort(arr):\n  for i in 1..arr.length:\n    key = arr[i]\n    j = i - 1\n    while j >= 0 and arr[j] > key:\n      arr[j + 1] = arr[j]\n      j = j - 1\n    arr[j + 1] = key", ["Insertion sort", "Bubble sort", "Selection sort", "Counting sort"], "Insertion sort", "medium", "ordenacao", "O(n²)", "Insere cada elemento na posição correta do subarray ordenado à esquerda.", "Desloca elementos maiores que key.", "https://www.geeksforgeeks.org/dsa/insertion-sort/"),
  c("daily-as-merge-sort", "Merge sort", "function sort(arr, left, right):\n  if left >= right:\n    return\n  mid = (left + right) / 2\n  sort(arr, left, mid)\n  sort(arr, mid + 1, right)\n  combine(arr, left, mid, right)", ["Merge sort", "Quick sort", "Heap sort", "Insertion sort"], "Merge sort", "medium", "ordenacao", "O(n log n)", "Divide o array ao meio recursivamente e depois faz merge das metades ordenadas.", "Divide e conquista com merge.", "https://www.geeksforgeeks.org/dsa/merge-sort/"),
  c("daily-as-heap-sort", "Heap sort", "function sort(arr):\n  buildMaxHeap(arr)\n  for i in arr.length - 1 down to 1:\n    swap(arr[0], arr[i])\n    restoreHeap(arr, 0, i)", ["Heap sort", "Merge sort", "Quick sort", "Selection sort"], "Heap sort", "medium", "ordenacao", "O(n log n)", "Constrói max-heap e extrai o máximo repetidamente para o final.", "heapify após cada swap com o root.", "https://www.geeksforgeeks.org/dsa/heap-sort/"),
  c("daily-as-quick-sort", "Quick sort", "function sort(arr, low, high):\n  if low < high:\n    pivot = partition(arr, low, high)\n    sort(arr, low, pivot - 1)\n    sort(arr, pivot + 1, high)\n// pivot sempre o menor elemento", ["Quick sort", "Merge sort", "Heap sort", "Bubble sort"], "Quick sort", "medium", "ordenacao", "O(n²)", "Particiona em torno de um pivot e ordena recursivamente as duas partes.", "partition + duas chamadas recursivas.", "https://www.geeksforgeeks.org/dsa/quick-sort/"),
  c("daily-as-dfs", "DFS", "function traverse(node):\n  if node == null:\n    return\n  visit(node)\n  traverse(node.left)\n  traverse(node.right)", ["DFS", "BFS", "Dijkstra", "Merge sort"], "DFS", "medium", "grafos", "O(n)", "Visita um nó e explora recursivamente os filhos antes de voltar.", "Pré-ordem: visita antes dos filhos.", "https://www.geeksforgeeks.org/dsa/tree-traversals-inorder-preorder-and-postorder/"),
  c("daily-as-bfs", "BFS", "function levelOrder(root):\n  queue = [root]\n  while queue not empty:\n    node = queue.popFront()\n    for child in node.children:\n      queue.push(child)", ["BFS", "DFS", "Dijkstra", "Bellman-Ford"], "BFS", "medium", "grafos", "O(n)", "Explora nível a nível usando uma fila.", "popFront + enfileirar filhos.", "https://www.geeksforgeeks.org/dsa/level-order-tree-traversal/"),
  c("daily-as-fib-recursive", "Fibonacci recursivo", "function calc(n):\n  if n <= 1:\n    return n\n  return calc(n - 1) + calc(n - 2)", ["Fibonacci recursivo", "Torre de Hanói", "Power set", "Permutações"], "Fibonacci recursivo", "hard", "recursao", "O(2^n)", "Cada chamada gera duas subchamadas — árvore exponencial.", "Dois casos base e duas recursões.", "https://www.geeksforgeeks.org/dsa/program-for-nth-fibonacci-number/"),
  c("daily-as-subsets", "Power set", "function subsets(arr, index, current):\n  if index == arr.length:\n    print(current)\n    return\n  subsets(arr, index + 1, current)\n  subsets(arr, index + 1, current + [arr[index]])", ["Power set", "Permutações", "Fibonacci recursivo", "N-Queens"], "Power set", "hard", "recursao", "O(2^n)", "Para cada elemento, decide incluir ou não — gera todos os subconjuntos.", "Duas chamadas recursivas por nível.", "https://www.geeksforgeeks.org/dsa/power-set/"),
  c("daily-as-permutations", "Permutações", "function permute(arr, used, path):\n  if path.length == arr.length:\n    print(path)\n    return\n  for i in 0..arr.length:\n    if not used[i]:\n      used[i] = true\n      permute(arr, used, path + [arr[i]])\n      used[i] = false", ["Permutações", "Power set", "N-Queens", "Fibonacci recursivo"], "Permutações", "hard", "recursao", "O(n!)", "Tenta cada elemento não usado em cada posição da permutação.", "Backtracking com array used.", "https://www.geeksforgeeks.org/dsa/write-a-program-to-print-all-permutations-of-a-given-string/"),
  c("daily-as-hanoi", "Torre de Hanói", "function hanoi(n, from, to, aux):\n  if n == 1:\n    move(from, to)\n    return\n  hanoi(n - 1, from, aux, to)\n  move(from, to)\n  hanoi(n - 1, aux, to, from)", ["Torre de Hanói", "Fibonacci recursivo", "Merge sort", "Power set"], "Torre de Hanói", "hard", "recursao", "O(2^n)", "Move n discos movendo recursivamente n-1 discos para a torre auxiliar.", "Três pinos e duas recursões com n-1.", "https://www.geeksforgeeks.org/dsa/c-program-for-tower-of-hanoi/"),
  c("daily-as-matrix-multiply", "Multiplicação de matrizes", "function multiply(A, B):\n  n = A.length\n  C = matrix(n, n)\n  for i in 0..n:\n    for j in 0..n:\n      for k in 0..n:\n        C[i][j] = C[i][j] + A[i][k] * B[k][j]\n  return C", ["Multiplicação de matrizes", "Floyd-Warshall", "Three sum", "Merge sort"], "Multiplicação de matrizes", "hard", "matriz", "O(n³)", "Três loops i, j, k para combinar linha de A com coluna de B.", "Produto escalar em cada célula C[i][j].", "https://www.geeksforgeeks.org/dsa/matrix-multiplication/"),
  c("daily-as-two-pointers-reverse", "Two pointers", "function reverse(arr):\n  left = 0\n  right = arr.length - 1\n  while left < right:\n    swap(arr[left], arr[right])\n    left = left + 1\n    right = right - 1", ["Two pointers", "Sliding window", "Busca binária", "Busca linear"], "Two pointers", "easy", "padrao", "O(n)", "Dois índices convergem do início e do fim trocando elementos.", "left avança, right recua.", "https://www.geeksforgeeks.org/dsa/write-a-program-to-reverse-an-array-or-string/"),
  c("daily-as-two-pointers-palindrome", "Two pointers (palíndromo)", "function isPalindrome(s):\n  left = 0\n  right = s.length - 1\n  while left < right:\n    if s[left] != s[right]:\n      return false\n    left = left + 1\n    right = right - 1\n  return true", ["Two pointers", "Sliding window", "Busca linear", "Busca binária"], "Two pointers", "easy", "padrao", "O(n)", "Compara caracteres das extremidades movendo para o centro.", "Mesmo padrão de reverse, mas comparando.", "https://www.geeksforgeeks.org/dsa/check-if-a-string-is-palindrome-or-not/"),
  c("daily-as-bst-search", "Busca em BST", "function bstSearch(node, target):\n  if node == null:\n    return false\n  if node.value == target:\n    return true\n  if target < node.value:\n    return bstSearch(node.left, target)\n  return bstSearch(node.right, target)", ["Busca em BST", "Busca binária", "DFS", "Busca linear"], "Busca em BST", "medium", "busca", "O(log n)", "Em árvore binária de busca, desce para esquerda ou direita conforme o valor.", "Recursão com comparação no nó.", "https://www.geeksforgeeks.org/dsa/binary-search-tree-data-structure/"),
  c("daily-as-gcd", "MDC de Euclides", "function gcd(a, b):\n  while b != 0:\n    temp = b\n    b = a % b\n    a = temp\n  return a", ["MDC de Euclides", "Fibonacci recursivo", "Two pointers", "Busca binária"], "MDC de Euclides", "medium", "matematica", "O(log n)", "Substitui (a,b) por (b, a mod b) até b ser zero.", "Algoritmo clássico de Euclides iterativo.", "https://www.geeksforgeeks.org/dsa/euclidean-algorithms-basic-and-extended/"),
  c("daily-as-counting-sort", "Counting sort", "function countingSort(arr, k):\n  count = array(k + 1, 0)\n  for x in arr:\n    count[x] = count[x] + 1\n  idx = 0\n  for v in 0..k:\n    for c in 0..count[v]:\n      arr[idx] = v\n      idx = idx + 1", ["Counting sort", "Radix sort", "Insertion sort", "Merge sort"], "Counting sort", "hard", "ordenacao", "O(n)", "Conta frequências e reconstrói o array ordenado pelo range de valores.", "Array count[v] de frequências.", "https://www.geeksforgeeks.org/dsa/counting-sort/"),
  c("daily-as-recursive-sum", "Soma recursiva", "function sumArray(arr, index):\n  if index == arr.length:\n    return 0\n  return arr[index] + sumArray(arr, index + 1)", ["Soma recursiva", "DFS", "Fibonacci recursivo", "Busca linear"], "Soma recursiva", "easy", "recursao", "O(n)", "Caso base no fim do array; soma o elemento atual com o restante.", "Uma chamada recursiva por índice.", "https://www.geeksforgeeks.org/dsa/analysis-of-algorithms-set-1-asymptotic-analysis/"),
  c("daily-as-timsort", "Timsort", "function sortArray(arr):\n  return arr.sort()", ["Timsort", "Merge sort", "Heap sort", "Quick sort"], "Timsort", "medium", "ordenacao", "O(n log n)", "Ordenação built-in eficiente (Timsort em Python/Java) — híbrido merge + insertion.", "Chamada única a sort() no array.", "https://www.geeksforgeeks.org/dsa/analysis-of-algorithms-set-3-asymptotic-notations/"),
  c("daily-as-radix-sort", "Radix sort", "function radixSort(arr, d):\n  for digit in 0..d:\n    countingSortByDigit(arr, digit)", ["Radix sort", "Counting sort", "Heap sort", "Merge sort"], "Radix sort", "hard", "ordenacao", "O(n)", "Ordena dígito a dígito usando counting sort estável em cada posição.", "Loop externo sobre dígitos.", "https://www.geeksforgeeks.org/dsa/radix-sort/"),
  c("daily-as-moore-voting", "Moore voting", "function majority(arr):\n  candidate = null\n  count = 0\n  for x in arr:\n    if count == 0:\n      candidate = x\n      count = 1\n    else if x == candidate:\n      count = count + 1\n    else:\n      count = count - 1\n  return candidate", ["Moore voting", "Two sum", "Sliding window", "Busca linear"], "Moore voting", "medium", "padrao", "O(n)", "Algoritmo de Boyer-Moore para encontrar candidato a elemento majoritário.", "Cancela votos de pares diferentes.", "https://www.geeksforgeeks.org/dsa/majority-element/"),
  c("daily-as-sliding-window", "Sliding window", "function maxInWindow(arr, k):\n  total = 0\n  for i in 0..k:\n    total = total + arr[i]\n  best = total\n  for i in k..arr.length:\n    total = total + arr[i] - arr[i - k]\n    best = max(best, total)\n  return best", ["Sliding window", "Two pointers", "Prefix sum", "Busca linear"], "Sliding window", "medium", "padrao", "O(n)", "Mantém soma de janela fixa deslizando: adiciona novo, remove o que saiu.", "Segundo loop atualiza total.", "https://www.geeksforgeeks.org/dsa/window-sliding-technique/"),
  c("daily-as-merge-sorted", "Merge de ordenados", "function combine(a, b):\n  i = 0\n  j = 0\n  result = []\n  while i < a.length and j < b.length:\n    if a[i] <= b[j]:\n      result.push(a[i])\n      i = i + 1\n    else:\n      result.push(b[j])\n      j = j + 1\n  // append rest", ["Merge de ordenados", "Merge sort", "Two pointers", "Busca binária"], "Merge de ordenados", "medium", "ordenacao", "O(n)", "Dois ponteiros percorrem arrays já ordenados fundindo em ordem.", "Compara a[i] e b[j] a cada passo.", "https://www.geeksforgeeks.org/dsa/merge-two-sorted-arrays/"),
  c("daily-as-heap-push", "Heap push", "function push(heap, value):\n  heap.data[heap.size] = value\n  heap.size = heap.size + 1\n  siftUp(heap, heap.size - 1)", ["Heap push", "Heap pop", "Heap sort", "Insertion sort"], "Heap push", "medium", "heap", "O(log n)", "Insere no final da heap e sobe o elemento com siftUp.", "siftUp restaura propriedade de min-heap.", "https://www.geeksforgeeks.org/dsa/heap-insert-and-delete-operations/"),
  c("daily-as-topological-sort", "Ordenação topológica", "function topoDFS(node, visited, order):\n  visited.add(node)\n  for next in node.neighbors:\n    if next not in visited:\n      topoDFS(next, visited, order)\n  order.push(node)", ["Ordenação topológica", "DFS", "BFS", "Kruskal"], "Ordenação topológica", "hard", "grafos", "O(n)", "DFS pós-ordem: empilha nó após visitar todos os vizinhos.", "order.push ao final da recursão.", "https://www.geeksforgeeks.org/dsa/topological-sorting/"),
  c("daily-as-activity-selection", "Seleção de atividades", "function activitySelection(activities):\n  sort(activities by end time)\n  count = 1\n  lastEnd = activities[0].end\n  for i in 1..activities.length:\n    if activities[i].start >= lastEnd:\n      count = count + 1\n      lastEnd = activities[i].end\n  return count", ["Seleção de atividades", "Greedy genérico", "Merge sort", "Sliding window"], "Seleção de atividades", "medium", "greedy", "O(n log n)", "Greedy: ordena por fim e escolhe atividades compatíveis não sobrepostas.", "Sempre pega a que termina mais cedo.", "https://www.geeksforgeeks.org/dsa/activity-selection-problem-greedy-algo-1/"),
];

const free = [
  c("free-as-dijkstra", "Dijkstra", "function shortestPaths(adj, n, source):\n  dist = array(n, infinity)\n  dist[source] = 0\n  for count in 0..n:\n    u = minVertex(dist, visited)\n    for v in 0..n:\n      if adj[u][v] and dist[u] + adj[u][v] < dist[v]:\n        dist[v] = dist[u] + adj[u][v]", ["Dijkstra", "Bellman-Ford", "Floyd-Warshall", "BFS"], "Dijkstra", "hard", "grafos", "O(n²)", "Relaxa distâncias a partir do vértice com menor distância conhecida.", "minVertex + relaxação de arestas.", "https://www.geeksforgeeks.org/dsa/dijkstras-shortest-path-algorithm-greedy-algo-7/"),
  c("free-as-floyd-warshall", "Floyd-Warshall", "function floydWarshall(dist):\n  n = dist.length\n  for k in 0..n:\n    for i in 0..n:\n      for j in 0..n:\n        dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])", ["Floyd-Warshall", "Dijkstra", "Bellman-Ford", "Multiplicação de matrizes"], "Floyd-Warshall", "hard", "grafos", "O(n³)", "Todos os pares: tenta melhorar dist[i][j] passando por intermediário k.", "Três loops i, j, k.", "https://www.geeksforgeeks.org/dsa/floyd-warshall-algorithm-dp-16/"),
  c("free-as-bellman-ford", "Bellman-Ford", "function bellmanFord(adj, n, source):\n  dist = array(n, infinity)\n  dist[source] = 0\n  for i in 1..n - 1:\n    for u in 0..n:\n      for v in 0..n:\n        if adj[u][v]:\n          relax(u, v, dist)", ["Bellman-Ford", "Dijkstra", "Floyd-Warshall", "BFS"], "Bellman-Ford", "hard", "grafos", "O(n²)", "Relaxa todas as arestas n-1 vezes — caminhos mínimos com pesos negativos.", "n-1 rodadas de relaxação.", "https://www.geeksforgeeks.org/dsa/bellman-ford-algorithm-dp-23/"),
  c("free-as-kruskal", "Kruskal", "function buildMST(edges, n):\n  sort(edges by weight)\n  parent = initParent(n)\n  mst = []\n  for edge in edges:\n    if root(parent, edge.u) != root(parent, edge.v):\n      link(parent, edge.u, edge.v)\n      mst.push(edge)", ["Kruskal", "Prim", "Dijkstra", "Union-Find"], "Kruskal", "hard", "grafos", "O(n log n)", "Ordena arestas por peso e adiciona à MST se não formar ciclo.", "Union-Find para detectar ciclos.", "https://www.geeksforgeeks.org/dsa/kruskals-minimum-spanning-tree-algorithm-greedy-algo-2/"),
  c("free-as-union-find", "Union-Find", "function root(parent, x):\n  if parent[x] != x:\n    parent[x] = root(parent, parent[x])\n  return parent[x]", ["Union-Find", "Kruskal", "DFS", "BFS"], "Union-Find", "hard", "grafos", "O(log n)", "Estrutura disjunta com path compression — find com compressão de caminho.", "parent[x] aponta para representante.", "https://www.geeksforgeeks.org/dsa/union-find/"),
  c("free-as-two-sum", "Two sum", "function twoSum(arr, target):\n  seen = map()\n  for i in 0..arr.length:\n    need = target - arr[i]\n    if need in seen:\n      return [seen[need], i]\n    seen[arr[i]] = i", ["Two sum", "Sliding window", "Moore voting", "Busca linear"], "Two sum", "medium", "padrao", "O(n)", "Hash map guarda valores vistos; busca complemento target - arr[i].", "Lookup O(1) no map.", "https://www.geeksforgeeks.org/dsa/check-if-pair-with-given-sum-exists-in-array/"),
  c("free-as-cycle-detection", "Detecção de ciclo", "function hasCycle(head):\n  slow = head\n  fast = head\n  while fast != null and fast.next != null:\n    slow = slow.next\n    fast = fast.next.next\n    if slow == fast:\n      return true\n  return false", ["Detecção de ciclo", "Two pointers", "DFS", "BFS"], "Detecção de ciclo", "medium", "padrao", "O(n)", "Algoritmo de Floyd (tortoise and hare) para ciclo em lista ligada.", "fast avança 2x, slow 1x.", "https://www.geeksforgeeks.org/dsa/detect-loop-in-a-linked-list/"),
  c("free-as-dutch-flag", "Dutch national flag", "function sortColors(arr):\n  low = 0\n  mid = 0\n  high = arr.length - 1\n  while mid <= high:\n    if arr[mid] == 0:\n      swap(arr[low], arr[mid]); low++; mid++\n    else if arr[mid] == 2:\n      swap(arr[mid], arr[high]); high--\n    else:\n      mid++", ["Dutch national flag", "Quick sort", "Counting sort", "Selection sort"], "Dutch national flag", "medium", "ordenacao", "O(n)", "Três ponteiros particionam array de 0s, 1s e 2s em uma passagem.", "low, mid, high — bandeira holandesa.", "https://www.geeksforgeeks.org/dsa/sort-an-array-of-0s-1s-and-2s/"),
  c("free-as-n-queens", "N-Queens", "function countSolutions(n, row, cols):\n  if row == n:\n    return 1\n  count = 0\n  for col in 0..n:\n    if isSafe(row, col, cols):\n      cols[row] = col\n      count = count + countSolutions(n, row + 1, cols)\n  return count", ["N-Queens", "Permutações", "Power set", "Torre de Hanói"], "N-Queens", "hard", "backtracking", "O(n!)", "Backtracking coloca rainhas linha a linha verificando segurança.", "Tenta cada coluna por linha.", "https://www.geeksforgeeks.org/dsa/n-queen-problem-backtracking-3/"),
  c("free-as-naive-strstr", "Busca de substring", "function findSubstring(text, pattern):\n  for i in 0..text.length - pattern.length:\n    match = true\n    for j in 0..pattern.length:\n      if text[i + j] != pattern[j]:\n        match = false\n        break\n    if match:\n      return i\n  return -1", ["Busca de substring", "KMP", "Busca linear", "Rabin-Karp"], "Busca de substring", "medium", "busca", "O(n²)", "Força bruta: testa alinhamento em cada posição do texto.", "Dois loops aninhados.", "https://www.geeksforgeeks.org/dsa/naive-algorithm-for-pattern-searching/"),
  c("free-as-power-set-bitmask", "Power set (bitmask)", "function powerSet(arr):\n  n = arr.length\n  for mask in 0..(1 << n):\n    subset = []\n    for i in 0..n:\n      if mask & (1 << i):\n        subset.push(arr[i])\n    print(subset)", ["Power set (bitmask)", "Power set", "Permutações", "Counting sort"], "Power set (bitmask)", "hard", "recursao", "O(2^n)", "Itera máscaras de bits de 0 a 2^n-1 para gerar subconjuntos.", "mask & (1 << i) testa inclusão.", "https://www.geeksforgeeks.org/dsa/power-set/"),
  c("free-as-linear-probing", "Hash linear probing", "function insert(table, key, value):\n  idx = hash(key) % table.capacity\n  while table.slots[idx] is occupied:\n    idx = (idx + 1) % table.capacity\n  table.slots[idx] = (key, value)", ["Hash linear probing", "Two sum", "Union-Find", "Busca linear"], "Hash linear probing", "medium", "hash", "O(n)", "Open addressing: em colisão, avança linearmente até slot vazio.", "idx = (idx + 1) % capacity.", "https://www.geeksforgeeks.org/dsa/hashing-set-3-open-addressing/"),
  c("free-as-heap-pop", "Heap pop", "function pop(heap):\n  min = heap.data[0]\n  heap.data[0] = heap.data[heap.size - 1]\n  heap.size = heap.size - 1\n  siftDown(heap, 0)\n  return min", ["Heap pop", "Heap push", "Heap sort", "Selection sort"], "Heap pop", "medium", "heap", "O(log n)", "Remove raiz, move último para root e desce com siftDown.", "siftDown restaura heap.", "https://www.geeksforgeeks.org/dsa/heap-insert-and-delete-operations/"),
  c("free-as-three-sum", "Three sum", "function threeSum(arr):\n  for i in 0..arr.length:\n    for j in i + 1..arr.length:\n      for k in j + 1..arr.length:\n        if arr[i] + arr[j] + arr[k] == 0:\n          return true\n  return false", ["Three sum", "Two sum", "Multiplicação de matrizes", "Floyd-Warshall"], "Three sum", "hard", "forca-bruta", "O(n³)", "Força bruta: três loops testam todas as triplas.", "Índices i < j < k.", "https://www.geeksforgeeks.org/dsa/find-triplets-with-zero-sum/"),
  c("free-as-rotate-array", "Rotacionar array", "function rotate(arr, k):\n  k = k % arr.length\n  reverse(arr, 0, arr.length - 1)\n  reverse(arr, 0, k - 1)\n  reverse(arr, k, arr.length - 1)", ["Rotacionar array", "Two pointers", "Reverse string", "Merge de ordenados"], "Rotacionar array", "medium", "padrao", "O(n)", "Truque das três reversões para rotacionar array em O(n) e O(1) extra.", "reverse global + duas parciais.", "https://www.geeksforgeeks.org/dsa/array-rotation/"),
  c("free-as-tree-height", "Altura da árvore", "function height(node):\n  if node == null:\n    return 0\n  return 1 + max(height(node.left), height(node.right))", ["Altura da árvore", "DFS", "BFS", "Busca em BST"], "Altura da árvore", "medium", "arvore", "O(n)", "Recursão retorna 1 + máximo das alturas dos filhos.", "Caso base: nó nulo → 0.", "https://www.geeksforgeeks.org/dsa/write-a-c-program-to-find-the-maximum-depth-or-height-of-a-tree/"),
  c("free-as-bst-degenerate", "BST degenerada", "function searchSkewed(node, target):\n  while node != null:\n    if node.value == target:\n      return true\n    node = node.right\n  return false\n// árvore vira lista ligada", ["BST degenerada", "Busca em BST", "Busca linear", "DFS"], "BST degenerada", "medium", "busca", "O(n)", "BST desbalanceada onde todos os nós só têm filho à direita — vira lista.", "Só desce para a direita.", "https://www.geeksforgeeks.org/dsa/binary-search-tree-data-structure/"),
  c("free-as-print-triangle", "Triângulo de números", "function printTriangle(n):\n  for i in 1..n:\n    for j in 1..i:\n      print(j)", ["Triângulo de números", "Bubble sort", "Multiplicação de matrizes", "Three sum"], "Triângulo de números", "medium", "padrao", "O(n²)", "Loop externo controla linhas; interno imprime 1..i.", "Padrão de impressão triangular.", "https://www.geeksforgeeks.org/dsa/analysis-of-algorithms-set-1-asymptotic-analysis/"),
  c("free-as-exponential-doubling", "Dobrar até n", "function doublingSteps(n):\n  steps = 0\n  i = 1\n  while i < n:\n    i = i * 2\n    steps = steps + 1\n  return steps", ["Dobrar até n", "Busca binária", "MDC de Euclides", "Fibonacci recursivo"], "Dobrar até n", "easy", "padrao", "O(log n)", "Dobra i até passar de n — conta quantos passos.", "i = i * 2 em loop.", "https://www.geeksforgeeks.org/dsa/analysis-of-algorithms-set-1-asymptotic-analysis/"),
  c("free-as-halving-loop", "Dividir por 2", "function steps(n):\n  count = 0\n  while n > 1:\n    n = n / 2\n    count = count + 1\n  return count", ["Dividir por 2", "Dobrar até n", "Busca binária", "MDC de Euclides"], "Dividir por 2", "easy", "padrao", "O(log n)", "Divide n por 2 repetidamente até chegar a 1.", "Padrão logarítmico simples.", "https://www.geeksforgeeks.org/dsa/analysis-of-algorithms-set-1-asymptotic-analysis/"),
  c("free-as-binary-search-rec", "Busca binária recursiva", "function search(arr, target, left, right):\n  if left > right:\n    return -1\n  mid = (left + right) / 2\n  if arr[mid] == target:\n    return mid\n  if arr[mid] < target:\n    return search(arr, target, mid + 1, right)\n  return search(arr, target, left, mid - 1)", ["Busca binária recursiva", "Busca binária", "Busca ternária", "Busca em BST"], "Busca binária recursiva", "medium", "busca", "O(log n)", "Versão recursiva da busca binária com left/right.", "Duas chamadas recursivas conforme mid.", "https://www.geeksforgeeks.org/dsa/binary-search/"),
  c("free-as-contains-duplicates", "Verificar duplicata", "function hasDuplicate(arr):\n  seen = set()\n  for x in arr:\n    if x in seen:\n      return true\n    seen.add(x)\n  return false", ["Verificar duplicata", "Two sum", "Moore voting", "Busca linear"], "Verificar duplicata", "medium", "hash", "O(n)", "Set detecta se elemento já foi visto.", "Lookup e insert no set.", "https://www.geeksforgeeks.org/dsa/check-if-array-elements-are-distinct/"),
  c("free-as-copy-array", "Copiar array", "function duplicate(arr):\n  result = newBuffer(arr.length)\n  for i in 0..arr.length:\n    result[i] = arr[i]\n  return result", ["Copiar array", "Busca linear", "Soma recursiva", "Merge de ordenados"], "Copiar array", "easy", "basico", "O(n)", "Loop simples copia cada elemento para novo buffer.", "Um loop linear.", "https://www.geeksforgeeks.org/dsa/arrays/"),
  c("free-as-pair-count", "Contar pares de índices", "function countPairs(arr):\n  count = 0\n  for i in 0..arr.length:\n    for j in i + 1..arr.length:\n      count = count + 1\n  return count", ["Contar pares de índices", "Three sum", "Bubble sort", "Triângulo de números"], "Contar pares de índices", "medium", "forca-bruta", "O(n²)", "Dois loops aninhados contam todos os pares (i,j) com i < j.", "Combinação de índices.", "https://www.geeksforgeeks.org/dsa/analysis-of-algorithms-set-1-asymptotic-analysis/"),
  c("free-as-matrix-traverse", "Percorrer matriz", "function traverse(matrix):\n  rows = matrix.length\n  cols = matrix[0].length\n  for i in 0..rows:\n    for j in 0..cols:\n      print(matrix[i][j])", ["Percorrer matriz", "Multiplicação de matrizes", "Floyd-Warshall", "Triângulo de números"], "Percorrer matriz", "medium", "matriz", "O(n²)", "Dois loops percorrem todas as células da matriz.", "i sobre linhas, j sobre colunas.", "https://www.geeksforgeeks.org/dsa/search-a-2d-matrix/"),
  c("free-as-median-two-sorted", "Mediana dois arrays", "function medianSorted(a, b):\n  i = 0\n  j = 0\n  for step in 0..(a.length + b.length) / 2:\n    if a[i] <= b[j]:\n      median = a[i]\n      i = i + 1\n    else:\n      median = b[j]\n      j = j + 1\n  return median", ["Mediana dois arrays", "Merge de ordenados", "Busca binária", "Two pointers"], "Mediana dois arrays", "medium", "ordenacao", "O(n)", "Merge ingênuo até a posição da mediana.", "Dois ponteiros como merge.", "https://www.geeksforgeeks.org/dsa/median-of-two-sorted-arrays-of-different-sizes/"),
  c("free-as-karatsuba-naive", "Multiplicação ingênua", "function multiply(a, b):\n  result = 0\n  for i in 0..a.length:\n    for j in 0..b.length:\n      result = result + digit(a, i) * digit(b, j)\n  return result", ["Multiplicação ingênua", "Multiplicação de matrizes", "Karatsuba", "Three sum"], "Multiplicação ingênua", "hard", "matematica", "O(n²)", "Multiplicação escolar: produto dígito a dígito com loops duplos.", "Dois loops sobre dígitos.", "https://www.geeksforgeeks.org/dsa/analysis-of-algorithms-set-1-asymptotic-analysis/"),
  c("free-as-sum-array", "Soma do array", "function sum(arr):\n  total = 0\n  for i in 0..arr.length:\n    total = total + arr[i]\n  return total", ["Soma do array", "Busca linear", "Copiar array", "Soma recursiva"], "Soma do array", "easy", "basico", "O(n)", "Acumula cada elemento em total com um loop.", "Padrão reduce linear.", "https://www.geeksforgeeks.org/dsa/arrays/"),
  c("free-as-find-max", "Encontrar máximo", "function maxValue(arr):\n  best = arr[0]\n  for i in 1..arr.length:\n    if arr[i] > best:\n      best = arr[i]\n  return best", ["Encontrar máximo", "Busca linear", "Moore voting", "Soma do array"], "Encontrar máximo", "easy", "basico", "O(n)", "Uma passagem mantendo o maior valor visto.", "Compara cada arr[i] com best.", "https://www.geeksforgeeks.org/dsa/maximum-element-in-an-array/"),
  c("free-as-count-evens", "Contar números pares", "function countEvens(arr):\n  count = 0\n  for x in arr:\n    if x % 2 == 0:\n      count = count + 1\n  return count", ["Contar números pares", "Soma do array", "Busca linear", "Moore voting"], "Contar números pares", "easy", "basico", "O(n)", "Itera e incrementa contador quando elemento é par.", "Condição x % 2 == 0.", "https://www.geeksforgeeks.org/dsa/arrays/"),
  c("free-as-reverse-recursive", "Inverter recursivo", "function reverseList(node, prev):\n  if node == null:\n    return prev\n  next = node.next\n  node.next = prev\n  return reverseList(next, node)", ["Inverter recursivo", "Detecção de ciclo", "DFS", "Soma recursiva"], "Inverter recursivo", "medium", "lista", "O(n)", "Inverte lista ligada recursivamente trocando ponteiros next.", "node.next = prev a cada chamada.", "https://www.geeksforgeeks.org/dsa/reverse-a-linked-list/"),
  c("free-as-prefix-sum", "Prefix sum", "function buildSums(arr):\n  sums = newBuffer(arr.length + 1, 0)\n  for i in 0..arr.length:\n    sums[i + 1] = sums[i] + arr[i]\n  return sums", ["Prefix sum", "Sliding window", "Soma do array", "Two sum"], "Prefix sum", "medium", "padrao", "O(n)", "Constrói somas acumuladas para consultas O(1).", "sums[i+1] = sums[i] + arr[i].", "https://www.geeksforgeeks.org/dsa/prefix-sum-array-implementation/"),
  c("free-as-bfs-shortest", "BFS caminho mínimo", "function shortestPath(grid, start, goal):\n  queue = [start]\n  dist = map(start -> 0)\n  while queue not empty:\n    cell = queue.popFront()\n    if cell == goal:\n      return dist[cell]\n    for neighbor in neighbors(cell):\n      if neighbor not in dist:\n        dist[neighbor] = dist[cell] + 1\n        queue.push(neighbor)", ["BFS caminho mínimo", "Dijkstra", "DFS", "Bellman-Ford"], "BFS caminho mínimo", "medium", "grafos", "O(n)", "BFS em grid não ponderado encontra menor número de passos.", "dist incrementa por camada.", "https://www.geeksforgeeks.org/dsa/shortest-path-unweighted-graph/"),
  c("free-as-prim-mst", "Prim MST", "function growMST(adj, n):\n  key = array(n, infinity)\n  key[0] = 0\n  for count in 0..n:\n    u = minKey(key, inMST)\n    inMST[u] = true\n    for v in 0..n:\n      if adj[u][v] and not inMST[v]:\n        key[v] = min(key[v], adj[u][v])", ["Prim MST", "Kruskal", "Dijkstra", "Bellman-Ford"], "Prim MST", "hard", "grafos", "O(n²)", "Cresce MST escolhendo aresta mínima a partir do conjunto já incluído.", "minKey + atualiza key[v].", "https://www.geeksforgeeks.org/dsa/prims-minimum-spanning-tree-mst-greedy-algo-5/"),
  c("free-as-quickselect", "Quickselect", "function kth(arr, k, low, high):\n  if low == high:\n    return arr[low]\n  pivot = partition(arr, low, high)\n  if k == pivot:\n    return arr[k]\n  if k < pivot:\n    return kth(arr, k, low, pivot - 1)\n  return kth(arr, k, pivot + 1, high)", ["Quickselect", "Quick sort", "Busca binária", "Heap sort"], "Quickselect", "hard", "ordenacao", "O(n)", "Como quicksort, mas só recursa no lado que contém o k-ésimo.", "partition + uma recursão.", "https://www.geeksforgeeks.org/dsa/quickselect-algorithm/"),
  c("free-as-sieve", "Crivo de Eratóstenes", "function sieve(n):\n  isPrime = array(n + 1, true)\n  isPrime[0] = false\n  isPrime[1] = false\n  for p in 2..sqrt(n):\n    if isPrime[p]:\n      for multiple in p*p..n step p:\n        isPrime[multiple] = false", ["Crivo de Eratóstenes", "MDC de Euclides", "Counting sort", "Soma do array"], "Crivo de Eratóstenes", "medium", "matematica", "O(n log log n)", "Marca múltiplos de cada primo a partir de p².", "Loop interno com step p.", "https://www.geeksforgeeks.org/dsa/sieve-of-eratosthenes/"),
  c("free-as-kadane", "Kadane", "function maxSubarray(arr):\n  best = arr[0]\n  current = arr[0]\n  for i in 1..arr.length:\n    current = max(arr[i], current + arr[i])\n    best = max(best, current)\n  return best", ["Kadane", "Sliding window", "Moore voting", "Prefix sum"], "Kadane", "medium", "dp", "O(n)", "Algoritmo de Kadane para subarray de soma máxima.", "current = max(arr[i], current + arr[i]).", "https://www.geeksforgeeks.org/dsa/largest-sum-contiguous-subarray/"),
  c("free-as-lis", "LIS", "function longestIncreasing(arr):\n  dp = newBuffer(arr.length, 1)\n  for i in 1..arr.length:\n    for j in 0..i - 1:\n      if arr[j] < arr[i]:\n        dp[i] = max(dp[i], dp[j] + 1)\n  return max(dp)", ["LIS", "LCS", "Kadane", "Three sum"], "LIS", "hard", "dp", "O(n²)", "DP clássico: maior subsequência crescente.", "dp[i] = max(dp[j]+1) se arr[j] < arr[i].", "https://www.geeksforgeeks.org/dsa/longest-increasing-subsequence-dp-3/"),
  c("free-as-lcs", "LCS", "function commonSubseq(a, b):\n  m = a.length\n  n = b.length\n  dp = matrix(m + 1, n + 1, 0)\n  for i in 1..m:\n    for j in 1..n:\n      if a[i-1] == b[j-1]:\n        dp[i][j] = dp[i-1][j-1] + 1\n      else:\n        dp[i][j] = max(dp[i-1][j], dp[i][j-1])\n  return dp[m][n]", ["LCS", "LIS", "Edit distance", "Floyd-Warshall"], "LCS", "hard", "dp", "O(mn)", "Maior subsequência comum: DP em duas strings.", "dp[i][j] com match ou max dos vizinhos.", "https://www.geeksforgeeks.org/dsa/longest-common-subsequence-dp-4/"),
  c("free-as-edit-distance", "Edit distance", "function editDistance(a, b):\n  m = a.length\n  n = b.length\n  dp = matrix(m + 1, n + 1, 0)\n  for i in 0..m:\n    dp[i][0] = i\n  for j in 0..n:\n    dp[0][j] = j\n  for i in 1..m:\n    for j in 1..n:\n      cost = a[i-1] == b[j-1] ? 0 : 1\n      dp[i][j] = min(dp[i-1][j] + 1, dp[i][j-1] + 1, dp[i-1][j-1] + cost)\n  return dp[m][n]", ["Edit distance", "LCS", "LIS", "Busca de substring"], "Edit distance", "hard", "dp", "O(mn)", "Levenshtein: inserção, deleção ou substituição para transformar a em b.", "Três operações no min().", "https://www.geeksforgeeks.org/dsa/edit-distance-dp-5/"),
];

function c(id, title, snippet, options, answer, difficulty, category, complexity, explanation, hint, reference, whatItIsOverride) {
  const whatItIs = whatItIsOverride ?? WHAT_IT_IS[answer];
  if (!whatItIs) {
    throw new Error(`Missing whatItIs for answer "${answer}" in ${id}`);
  }
  return {
    id,
    title,
    snippet,
    options,
    answer,
    difficulty,
    category,
    caseNote: complexity,
    whatItIs,
    explanation,
    hint,
    reference,
    learnMoreURL: "https://www.geeksforgeeks.org/dsa/algorithms/",
  };
}

function sharedAlgoSpotChallenge() {
  const { snippet, algoSpot } = sharedSnippetExtra;
  return c(
    algoSpot.id,
    algoSpot.title,
    snippet,
    algoSpot.options,
    algoSpot.answer,
    algoSpot.difficulty,
    algoSpot.category,
    algoSpot.complexity,
    algoSpot.explanation,
    algoSpot.hint,
    algoSpot.reference,
    algoSpot.whatItIs
  );
}

const DAILY_IDS = new Set([
  ...daily.map((item) => item.id),
  "shared-as-find-min",
  "free-as-two-sum",
  "free-as-kadane",
  "free-as-sieve",
  "free-as-cycle-detection",
]);

const allChallenges = dedupeById([
  ...daily,
  ...free,
  sharedAlgoSpotChallenge(),
  ...algoSpotExclusiveExtra,
]);

const dailyChallenges = allChallenges.filter((item) => DAILY_IDS.has(item.id));
const freeChallenges = allChallenges.filter((item) => !DAILY_IDS.has(item.id));

if (dailyChallenges.length !== DAILY_COUNT) {
  throw new Error(`Expected ${DAILY_COUNT} daily challenges, got ${dailyChallenges.length}`);
}
if (allChallenges.length !== 100) {
  throw new Error(`Expected 100 total AlgoSpot challenges, got ${allChallenges.length}`);
}
if (dailyChallenges.length + freeChallenges.length !== 100) {
  throw new Error("Daily/free split does not cover all challenges");
}

function dedupeById(challenges) {
  const seen = new Set();
  return challenges.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
}

writeFileSync(join(OUT_DIR, "algo_spot_daily.json"), JSON.stringify({ challenges: dailyChallenges }, null, 2) + "\n");
writeFileSync(join(OUT_DIR, "algo_spot_free.json"), JSON.stringify({ challenges: freeChallenges }, null, 2) + "\n");
console.log(`Wrote ${dailyChallenges.length} daily and ${freeChallenges.length} free challenges (${allChallenges.length} total)`);
