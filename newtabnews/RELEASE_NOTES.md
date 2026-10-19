# TabNews Reader: notas da atualização 4.5

## Texto para a App Store ("O que há de novo")

Agora dá para tirar os posts de Pitch do feed, e a Newsletter ficou mais fácil de ler!

• Ocultar Pitch: ative no Perfil para tirar do feed as divulgações de projetos. Uma linha no topo da Home mostra quantos posts foram ocultados e deixa você mostrá-los de novo com um toque.
• Newsletter renovada: notícias agrupadas por dia, com a fonte e o horário de cada uma, num visual mais limpo. O selo "Novo" aparece só no que você ainda não viu.
• Dicas no lugar certo: em vez de uma sequência de telas depois do onboarding, cada dica aparece uma vez, onde a funcionalidade está.
• Nova animação de abertura e ícones do onboarding animados de novo.

---

## Changelog completo

### Novidades
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
  - O selo "Novo" aparece só nas notícias que chegaram desde a última visita (antes aparecia em tudo que era do dia).
  - Puxar para atualizar não esconde mais a lista enquanto carrega.
- **Dicas no contexto**: a sequência de 6 telas de dicas virou cards que aparecem uma única vez:
  - Home: "Segure um post" e "Muitos posts de Pitch?".
  - Post: "Destaque e anote" e "Conheça quem escreve".
  - O aviso de app não oficial foi para a primeira página do onboarding.
  - Perfil > "Ver Dicas Novamente" faz todas voltarem.
- **Splash**: o contorno do logo é desenhado, o título entra letra por letra e o logo avança e se dissolve revelando o app. Ficou mais curta.
- **Onboarding**: os ícones voltaram a entrar girando com zoom.

### Melhorias técnicas
- A tela de dicas em tela cheia (`OnboardingTipsView`) e a ilustração do menu de post foram removidas; o novo componente `InlineTip` é reaproveitado nas dicas.
- `NewsletterView` lê o ViewModel via `@Environment`, como ele é injetado.
- Parsing de datas da newsletter reaproveita um único `ISO8601DateFormatter`.

### Pendências antes de publicar
- Os targets do Widget e do Watch continuam em `MARKETING_VERSION = 4.2`, como nas últimas versões.
