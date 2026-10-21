# TabNews Reader: notas da atualização 4.3

Junta tudo o que foi feito desde a 4.2.4 (última versão na App Store): as mudanças preparadas como 4.4, 4.5 e 4.6 nunca foram publicadas.

## Texto para a App Store ("O que há de novo")

Leitura renovada, feed sem Pitch e uma Newsletter mais fácil de ler!

• Posts mais completos: tabelas, listas numeradas e aninhadas, checklists e blocos de código com rolagem e botão de copiar. Links, imagens e trechos de código aparecem do jeito certo, e o texto acompanha o tamanho de letra do seu iPhone.
• Comentários com a mesma formatação dos posts.
• Ocultar Pitch: ative no Perfil para tirar do feed as divulgações de projetos. Uma linha no topo da Home mostra quantos posts foram ocultados e deixa você mostrá-los de novo com um toque.
• Newsletter renovada: notícias agrupadas por dia, com a fonte e o horário de cada uma. O selo "Novo" aparece só no que você ainda não viu.
• Cards da Home mostram mais do texto de cada post, sem espaço vazio no fim.
• Dicas no lugar certo: cada dica aparece uma vez, onde a funcionalidade está, em vez de uma sequência de telas depois do onboarding.
• Nova animação de abertura e ícones do onboarding animados de novo.
• Destaques mais confiáveis: em posts com imagens, eles aparecem sempre no trecho certo.
• Busca mais rápida: as sugestões abrem na hora, e a Surpresa do dia aparece todos os dias.
• Carregamento do feed mais estável quando a conexão oscila.

---

## Changelog completo

### Novidades
- **Leitura de posts** (novo renderizador com swift-markdown, CommonMark + GFM):
  - Tabelas com rolagem horizontal, listas numeradas (respeitando o número inicial), listas aninhadas, checklists (`- [ ]`), `~~riscado~~` e citações aninhadas.
  - Blocos de código em view própria: rolagem horizontal, linguagem no topo e botão "Copiar".
  - Imagens no meio do parágrafo, badges com link (`[![](...)](...)`), `<img>`, `<details>`/`<summary>`, `<br>` e entidades HTML (`&amp;`, `&rarr;` etc.).
  - URLs soltas viram link sem levar a pontuação do fim; links com parênteses (Wikipedia) funcionam.
  - Fontes com Dynamic Type.
- **Comentários** usam o mesmo renderizador dos posts, com seleção de texto para copiar.
- **Ocultar posts de Pitch**:
  - Opção "Ocultar posts de Pitch" no Perfil, em Preferências (desligada por padrão).
  - Reconhece "Pitch:", "PITCH -", "[Pitch]", "(pitch)", "【PITCH】" e "#pitch", com ou sem acento. "Pitch deck: …" não conta.
  - O filtro age antes de baixar o texto dos posts, então os Pitches não geram requisições.
  - Se uma página fica curta depois do filtro, o app busca as próximas sozinho (até 3), e a rolagem infinita não trava.
  - Aviso na Home ("N posts de Pitch ocultos · Mostrar") enquanto o filtro está ligado.
  - Dica na Home, mostrada uma vez quando o feed tem Pitch, com o botão "Ocultar Pitch".
- **Newsletter**:
  - Agrupada por dia ("Hoje", "Ontem", "Sex., 9 de out.").
  - Cada notícia mostra a fonte (ex.: tecnoblog.net) e o horário.
  - Lista sem cards, mais leve, com título grande no topo igual ao da Home.
  - O selo "Novo" aparece só nas notícias que chegaram desde a última visita.
  - Puxar para atualizar não esconde mais a lista enquanto carrega.
- **Cards da Home**: a prévia ocupa até 8 linhas e o título tem prioridade; antes a prévia era cortada em 200 caracteres e sobrava espaço vazio.
- **Dicas no contexto**: a sequência de 6 telas de dicas virou cards que aparecem uma única vez:
  - Home: "Segure um post" e "Muitos posts de Pitch?".
  - Post: "Destaque e anote" e "Conheça quem escreve".
  - O aviso de app não oficial foi para a primeira página do onboarding.
  - Perfil > "Ver Dicas Novamente" faz todas voltarem.
- **Busca (Descobrir)**:
  - Abre na hora com as seções salvas; na virada do dia mostra as de ontem enquanto busca as novas, sem skeleton.
  - 7 requisições de 100 posts no lugar de 13 de 30: bem menos tempo de carregamento na primeira abertura do dia.
  - Se uma página falha, as seções são montadas com o que chegou, em vez de mostrar a tela de erro.
  - Respeita "Ocultar posts de Pitch".
- **Splash**: o contorno do logo é desenhado, o título entra letra por letra e o logo avança e se dissolve revelando o app. Ficou mais curta.
- **Onboarding**: os ícones voltaram a entrar girando com zoom.

### Correções
- `snake_case` virava itálico e `**`/`__` dentro de código eram interpretados como negrito.
- Destaques em posts com imagens apareciam também em outros trechos do post.
- Negrito dentro de título perdia o tamanho do título.
- A Surpresa do dia sumia na maioria dos dias: a página sorteada da estratégia "relevantes" passava das ~140 que existem e vinha vazia.
- O cache da busca criava uma chave nova por dia no `UserDefaults` e nunca apagava as antigas.
- Retentativas e timeouts do carregamento do feed ajustados para o skeleton não ficar preso.

### Melhorias técnicas
- Renderização em blocos (`MarkdownRenderer`) com cache; o `UITextView` só troca o texto quando ele muda.
- Destaques localizados pelo texto marcado (`highlightedText`), na ocorrência mais próxima da posição salva.
- Prévia do feed (`plainTextFromMarkdown`) gerada pelo parser, também com cache.
- Nova dependência: [swift-markdown](https://github.com/swiftlang/swift-markdown).
- A tela de dicas em tela cheia (`OnboardingTipsView`) foi removida; o componente `InlineTip` é reaproveitado nas dicas.
- App, Widget e Watch agora com a mesma versão (4.3, build 1).
